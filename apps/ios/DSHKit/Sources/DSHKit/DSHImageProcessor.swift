import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A picture handed to the processor: the bytes exactly as they were picked, and the name to keep.
public struct DSHImageInput: Sendable, Hashable {
    public let data: Data
    public let name: String?

    public init(data: Data, name: String? = nil) {
        self.data = data
        self.name = name
    }
}

/// A picture ready to send: the exact bytes, the media type they really are, and their pixel size.
/// Nothing here depends on the UI.
public struct DSHPreparedImage: Sendable, Hashable {
    public let mediaType: String
    public let name: String
    public let data: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(mediaType: String, name: String, data: Data, pixelWidth: Int, pixelHeight: Int) {
        self.mediaType = mediaType
        self.name = name
        self.data = data
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// Why a picture cannot be sent. Every case carries what the reader needs to act on.
public enum DSHImageError: LocalizedError, Sendable, Equatable {
    /// The bytes are not an image the system can decode at all.
    case notAnImage(String)
    case tooManyImages(Int)
    /// Even at the lowest quality and the smallest edge the picture stayed over the byte limit.
    case cannotCompress(String)
    /// The whole message would be over the local frame budget. Never split into several messages.
    case messageTooLarge(Int)
    /// The gateway never announced the `images` capability.
    case unsupportedByGateway

    public var errorDescription: String? {
        switch self {
        case .notAnImage(let name): return "「\(name)」不是能识别的图片"
        case .tooManyImages(let count): return "一次最多 20 张图片，现在选了 \(count) 张"
        case .cannotCompress(let name): return "「\(name)」压缩后仍然太大，换一张或先裁小"
        case .messageTooLarge(let bytes):
            return "这条消息约 \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))，超过 16 MiB，请减少图片"
        case .unsupportedByGateway: return "这个网关不支持发图片"
        }
    }
}

/// Turns picked pictures into what the gateway accepts. Pure logic: it never touches the UI, the
/// gateway or a view model, so the composer that lands later can call it directly.
///
/// Policy (the App's own memory budget, not a guarantee the gateway publishes):
/// - the format is read from the data with ImageIO, never from the file name;
/// - a JPEG/PNG/GIF/WebP that already fits is sent byte for byte, with no re-encode;
/// - anything else — HEIC, TIFF, BMP, a rotated photo, or a picture over a limit — becomes an
///   upright JPEG on a white background;
/// - JPEG quality walks 0.9 → 0.3, then the long edge shrinks by 0.8 and quality starts over, for a
///   bounded number of rounds; if it still does not fit the picture is refused, never sent oversized.
public enum DSHImageProcessor {
    /// The long edge a sent picture may have.
    public static let maxEdge = 2000
    /// The pixel count a sent picture may have (width × height).
    public static let maxPixels = 40_000_000
    /// The bytes a single picture may have.
    public static let maxImageBytes = 3_670_016
    /// The bytes one whole message may have, Base64 expansion included. Over this the send is refused
    /// rather than split into several messages.
    public static let maxMessageBytes = 16 * 1024 * 1024
    /// How many pictures one message may carry.
    public static let maxImages = 20
    /// How many pictures are decoded at once. Ten photos must not all expand together.
    public static let maxConcurrent = 2

    /// Quality steps from 0.9 down to 0.3.
    private static let topQualityStep = 9
    private static let floorQualityStep = 3
    /// Rounds before a picture is declared impossible.
    private static let maxRounds = 12
    /// The long edge never shrinks below this while retrying.
    private static let minEdge = 256
    /// Room for the frame's keys, the session and request ids, and the JSON punctuation.
    private static let envelopeBytes = 512

    // MARK: - Public interface

    /// Prepares one picture. The composer calls this as soon as a picture is picked.
    public static func prepare(_ input: DSHImageInput) async throws -> DSHPreparedImage {
        guard let image = try await prepare([input]).first else {
            throw DSHImageError.notAnImage(input.name ?? "image")
        }
        return image
    }

    /// Prepares a batch: at most two decode at once, the result keeps the input order, and the whole
    /// message is refused when it would be over the frame budget.
    public static func prepare(_ inputs: [DSHImageInput]) async throws -> [DSHPreparedImage] {
        guard !inputs.isEmpty else { return [] }
        guard inputs.count <= maxImages else { throw DSHImageError.tooManyImages(inputs.count) }
        var prepared = [Int: DSHPreparedImage]()
        try await withThrowingTaskGroup(of: (Int, DSHPreparedImage).self) { group in
            var next = 0
            while next < min(maxConcurrent, inputs.count) {
                let index = next
                group.addTask { (index, try prepareOne(inputs[index])) }
                next += 1
            }
            while let (index, image) = try await group.next() {
                prepared[index] = image
                if next < inputs.count {
                    let index = next
                    group.addTask { (index, try prepareOne(inputs[index])) }
                    next += 1
                }
            }
        }
        let images = (0..<inputs.count).compactMap { prepared[$0] }
        let bytes = messageByteCount(text: "", images: images)
        guard bytes <= maxMessageBytes else { throw DSHImageError.messageTooLarge(bytes) }
        return images
    }

    /// What the frame will weigh on the wire. Base64 is four bytes for every three, plus the JSON
    /// envelope. The gateway calls this with the real text before sending.
    public static func messageByteCount(text: String, images: [DSHPreparedImage]) -> Int {
        var total = envelopeBytes + text.utf8.count
        for image in images {
            total += 4 * ((image.data.count + 2) / 3)
            total += image.name.utf8.count + image.mediaType.utf8.count
        }
        return total
    }

    /// The same weight for pictures that are already in their final form (what the send path holds).
    public static func messageByteCount(text: String, images: [DSHOutgoingImage]) -> Int {
        var total = envelopeBytes + text.utf8.count
        for image in images {
            total += 4 * ((image.data.count + 2) / 3)
            total += image.name.utf8.count + image.mediaType.utf8.count
        }
        return total
    }

    // MARK: - One picture

    /// Runs off the main actor: the task group's child tasks are the decode work.
    private static func prepareOne(_ input: DSHImageInput) throws -> DSHPreparedImage {
        let name = input.name ?? "image"
        guard let source = CGImageSourceCreateWithData(input.data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw DSHImageError.notAnImage(name)
        }
        let format = ImageFormat(uti: CGImageSourceGetType(source) as String? ?? "")
        let size = pixelSize(source)
        let longEdge = max(size.width, size.height)
        // A picture that already fits every limit is sent exactly as it is: no re-encode, no quality
        // loss, and its original bytes are what the gateway stores.
        if format.isPassThrough, input.data.count <= maxImageBytes,
           longEdge <= maxEdge, size.width * size.height <= maxPixels,
           orientation(source) == 1 {
            return DSHPreparedImage(mediaType: format.mediaType, name: renamed(name, format.pathExtension),
                                    data: input.data, pixelWidth: size.width, pixelHeight: size.height)
        }
        let encoded = try encodeJPEG(source, name: name,
                                     startEdge: longEdge > 0 ? min(longEdge, maxEdge) : maxEdge)
        return DSHPreparedImage(mediaType: "image/jpeg", name: renamed(name, "jpg"),
                                data: encoded.data, pixelWidth: encoded.width, pixelHeight: encoded.height)
    }

    /// JPEG quality 0.9 → 0.3; still too big, shrink the long edge by 0.8 and start over. Bounded, and
    /// a picture that cannot fit is refused rather than sent over the limit.
    private static func encodeJPEG(_ source: CGImageSource, name: String,
                                   startEdge: Int) throws -> (data: Data, width: Int, height: Int) {
        var edge = max(startEdge, minEdge)
        var qualityStep = topQualityStep
        for _ in 0..<maxRounds {
            guard let image = thumbnail(source, maxPixels: edge) else { throw DSHImageError.cannotCompress(name) }
            guard let data = jpegData(image, quality: Double(qualityStep) / 10) else {
                throw DSHImageError.cannotCompress(name)
            }
            if data.count <= maxImageBytes, image.width <= maxEdge, image.height <= maxEdge,
               image.width * image.height <= maxPixels {
                return (data, image.width, image.height)
            }
            if qualityStep > floorQualityStep {
                qualityStep -= 1
            } else {
                // The quality floor is reached: trade pixels instead, and start at the top quality again.
                qualityStep = topQualityStep
                edge = Int(Double(edge) * 0.8)
                guard edge >= minEdge else { break }
            }
        }
        throw DSHImageError.cannotCompress(name)
    }

    /// A downscaled, upright image. `CreateThumbnailWithTransform` applies the EXIF orientation, and
    /// the thumbnail API never enlarges.
    private static func thumbnail(_ source: CGImageSource, maxPixels: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func jpegData(_ image: CGImage, quality: Double) -> Data? {
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        // JPEG has no alpha: draw onto white so a transparent PNG does not come out black.
        CGImageDestinationAddImage(destination, flattenedOnWhite(image),
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? out as Data : nil
    }

    private static func flattenedOnWhite(_ image: CGImage) -> CGImage {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: break
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }

    private static func pixelSize(_ source: CGImageSource) -> (width: Int, height: Int) {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (0, 0)
        }
        return ((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0,
                (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0)
    }

    /// 1 is upright. Anything else is rotated or mirrored and has to be re-encoded to keep the picture
    /// the right way up.
    private static func orientation(_ source: CGImageSource) -> Int {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return 1
        }
        return (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    }

    /// The name keeps its stem; the extension follows what the bytes really became.
    private static func renamed(_ name: String, _ pathExtension: String) -> String {
        let base = (name as NSString).deletingPathExtension
        return (base.isEmpty ? "image" : base) + "." + pathExtension
    }

    // MARK: - Format

    /// The real format, read from the data. The file name never decides this.
    private struct ImageFormat {
        enum Kind { case png, jpeg, gif, webp, other }
        let kind: Kind

        init(uti: String) {
            switch uti {
            case "public.png": kind = .png
            // JPEG 2000 is not baseline JPEG: it must be re-encoded, never sent as `image/jpeg`.
            case "public.jpeg": kind = .jpeg
            case "com.compuserve.gif": kind = .gif
            case "org.webmproject.webp", "public.webp": kind = .webp
            default: kind = .other
            }
        }

        /// Formats the gateway takes as they are. An animated GIF/WebP is sent untouched; the chat
        /// shows its first frame and offers no player.
        var isPassThrough: Bool {
            switch kind {
            case .png, .jpeg, .gif, .webp: return true
            case .other: return false
            }
        }

        var mediaType: String {
            switch kind {
            case .png: return "image/png"
            case .jpeg: return "image/jpeg"
            case .gif: return "image/gif"
            case .webp: return "image/webp"
            case .other: return "image/jpeg"
            }
        }

        var pathExtension: String {
            switch kind {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .gif: return "gif"
            case .webp: return "webp"
            case .other: return "jpg"
            }
        }
    }
}
