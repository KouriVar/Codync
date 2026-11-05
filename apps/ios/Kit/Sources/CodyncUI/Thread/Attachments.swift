import CodyncKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Files in messages: preparing picked, pasted and dropped files, and showing sent ones.

extension OutgoingFile {
    /// Images the agents can't all read (HEIC, TIFF, BMP…) become JPEG, upright.
    static func prepared(name: String, data: Data) -> OutgoingFile {
        let ext = (name as NSString).pathExtension.lowercased()
        guard ["heic", "heif", "tif", "tiff", "bmp"].contains(ext) || (ext.isEmpty && ImageData.isImage(data)),
              let jpeg = ImageData.jpeg(data) else { return OutgoingFile(name: name, data: data) }
        let base = (name as NSString).deletingPathExtension
        return OutgoingFile(name: (base.isEmpty ? "image" : base) + ".jpg", data: jpeg)
    }

    /// A name for a file that came without one (pasted or dragged image data).
    static func unnamed(_ ext: String) -> String {
        "pasted-\(Int(Date.now.timeIntervalSince1970)).\(ext)"
    }
}

/// Anything dropped or pasted: a file, or bare image data.
struct PickedFile: Transferable {
    let file: OutgoingFile

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            PickedFile(file: .prepared(name: received.file.lastPathComponent, data: try Data(contentsOf: received.file)))
        }
        DataRepresentation(importedContentType: .image) { data in
            PickedFile(file: .prepared(name: OutgoingFile.unnamed(ImageData.isPNG(data) ? "png" : "jpg"), data: data))
        }
    }

    /// Loads what item providers (pasteboard, drops) carry.
    @MainActor static func load(_ providers: [NSItemProvider]) async -> [OutgoingFile] {
        var files: [OutgoingFile] = []
        for provider in providers {
            let file: OutgoingFile? = await withCheckedContinuation { done in
                _ = provider.loadTransferable(type: PickedFile.self) { done.resume(returning: try? $0.get().file) }
            }
            if let file { files.append(file) }
        }
        return files
    }
}

enum ImageData {
    static func isImage(_ data: Data) -> Bool {
        CGImageSourceCreateWithData(data as CFData, nil).map { CGImageSourceGetCount($0) > 0 } ?? false
    }

    static func isPNG(_ data: Data) -> Bool { data.starts(with: [0x89, 0x50, 0x4E, 0x47]) }

    /// A downscaled, upright image (`maxPixels` on the long side).
    static func thumbnail(_ data: Data, maxPixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func jpeg(_ data: Data) -> Data? {
        guard let image = thumbnail(data, maxPixels: 4096) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}

/// The symbol for a file by its extension.
enum AttachmentIcon {
    static func symbol(_ name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "bmp": "photo"
        case "pdf": "doc.richtext"
        case "zip", "gz", "tar", "7z": "doc.zipper"
        case "mov", "mp4", "m4v": "film"
        case "mp3", "m4a", "wav", "aac": "waveform"
        default: "doc"
        }
    }
}

/// Files sent with a message, on the sender's side: images as pictures (tap for full size),
/// other files as cards.
struct AttachmentList: View {
    let attachments: [Attachment]
    let botId: String
    @State private var viewing: Attachment?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(attachments) { file in
                if file.isImage {
                    AttachmentImage(file: file, botId: botId, maxPixels: 720)
                        .frame(maxWidth: 220, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { viewing = file }
                        .accessibilityLabel(file.name)
                        .accessibilityAddTraits(.isButton)
                } else {
                    card(file)
                }
            }
        }
        .codyncSheet(item: $viewing) { AttachmentViewer(file: $0, botId: botId) }
    }

    private func card(_ file: Attachment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: AttachmentIcon.symbol(file.name))
                .font(.system(size: 16))
                .foregroundStyle(Palette.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(Palette.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.bubbleUser, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A picture full size: a sent image or one a bot shared.
struct AttachmentViewer: View {
    let name: String
    let image: AttachmentImage
    @Environment(\.dismissModal) private var dismiss

    init(file: Attachment, botId: String) {
        name = file.name
        image = AttachmentImage(file: file, botId: botId, maxPixels: 4096)
    }

    init(shared file: SharedFile, entryId: String) {
        name = file.name
        image = AttachmentImage(shared: file, entryId: entryId, maxPixels: 4096)
    }

    var body: some View {
        NavigationStack {
            image
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .navigationTitle(name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button(L10n.tr("Close")) { dismiss() } }
                }
        }
        .tint(.primary)
    }
}

/// A picture from the computer (a sent image or one a bot shared), fetched once and then read from the cache.
struct AttachmentImage: View {
    let id: String
    let maxPixels: Int
    var contentMode: ContentMode = .fit
    let load: @MainActor (BotStore) async -> Data?
    @Environment(BotStore.self) private var model

    init(file: Attachment, botId: String, maxPixels: Int, contentMode: ContentMode = .fit) {
        id = file.id
        self.maxPixels = maxPixels
        self.contentMode = contentMode
        load = { await $0.attachmentData(file, bot: botId) }
    }

    init(shared file: SharedFile, entryId: String, maxPixels: Int) {
        id = file.id
        self.maxPixels = maxPixels
        load = { await $0.sharedFileData(file, entryId: entryId) }
    }

    var body: some View {
        // Asked again when the computer comes online: a chat shown from the cache before it connects
        // gets its pictures once it does.
        LoadedImage(id: id, maxPixels: maxPixels, contentMode: contentMode,
                    reloadKey: model.connection == .online ? "online" : "waiting") {
            await load(model)
        }
    }
}

// MARK: - Pictures whose bytes come from the caller

/// One picture in a row: what it is called and how big it claims to be, never the bytes.
///
/// A transcript that keeps its own picture cache (DSH) only hands out stable ids and a loader;
/// the drawing is the same as Coe's. `id` is that cache's key, and also what `ForEach` and the
/// full-size sheet identify a picture by.
public struct TranscriptImageRef: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String?
    public let pixelWidth: Int?
    public let pixelHeight: Int?

    public init(id: String, name: String? = nil, pixelWidth: Int? = nil, pixelHeight: Int? = nil) {
        self.id = id
        self.name = name
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// A picture fetched by a closure: nothing here knows about bots, entries or a cache.
struct LoadedImage: View {
    let id: String
    let maxPixels: Int
    var contentMode: ContentMode = .fit
    /// Changing it asks for another attempt (say, a connection went from down to up).
    let reloadKey: String
    let load: @MainActor () async -> Data?
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.bubbleUser)
                    .frame(width: 160, height: 120)
                    .overlay { RemixIcon("image-line").foregroundStyle(Palette.tertiary) }
            }
        }
        // Asked again when the caller says so; a loaded picture is never fetched again.
        .task(id: [id, reloadKey]) {
            guard image == nil, let data = await load() else { return }
            let size = maxPixels
            image = await Task.detached { ImageData.thumbnail(data, maxPixels: size) }.value
        }
    }
}

/// A caller-loaded picture full size, laid out like `AttachmentViewer`.
struct LoadedImageViewer: View {
    let name: String
    let imageId: String
    let reloadKey: String
    let load: @MainActor () async -> Data?
    @Environment(\.dismissModal) private var dismiss

    var body: some View {
        NavigationStack {
            LoadedImage(id: imageId, maxPixels: 4096, reloadKey: reloadKey, load: load)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .navigationTitle(name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button(L10n.tr("Close")) { dismiss() } }
                }
        }
        .tint(.primary)
    }
}

/// The pictures of one row, tap one for full size: `AttachmentList`'s picture branch, with the
/// loading left to the caller.
struct TranscriptImageList: View {
    let images: [TranscriptImageRef]
    let reloadKey: String
    let load: @MainActor (String) async -> Data?
    @State private var viewing: TranscriptImageRef?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(images) { ref in
                LoadedImage(id: ref.id, maxPixels: 720, reloadKey: reloadKey, load: { await load(ref.id) })
                    .frame(maxWidth: 220, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { viewing = ref }
                    .accessibilityLabel(ref.name ?? "")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .codyncSheet(item: $viewing) { ref in
            LoadedImageViewer(name: ref.name ?? "", imageId: ref.id, reloadKey: reloadKey,
                              load: { await load(ref.id) })
        }
    }
}
