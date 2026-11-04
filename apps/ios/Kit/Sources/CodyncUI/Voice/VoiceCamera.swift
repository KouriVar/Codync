import AVFoundation
import CodyncKit
import SwiftUI
import UIKit

/// The camera inside the voice sheet: live preview, shutter, flip and album. It is its own session
/// because the sheet lives in the shared package, away from the app's quick-capture camera.
@MainActor
@Observable
public final class VoiceCamera {
    public enum Access { case unknown, granted, denied }

    public private(set) var access: Access = .unknown
    public private(set) var capturing = false
    @ObservationIgnored public let session = AVCaptureSession()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.pokai.codync.voicecam")
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var position: AVCaptureDevice.Position = .back
    @ObservationIgnored private var pending: CheckedContinuation<UIImage?, Never>?
    @ObservationIgnored private var delegate: VoiceCameraDelegate?

    public init() {}

    /// The camera permission, asked the first time the page opens.
    public func requestAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .granted
        case .notDetermined:
            access = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default:
            access = .denied
        }
    }

    public func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            guard self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    /// Front and back, swapped in place: the session keeps running.
    public func flip() {
        position = position == .back ? .front : .back
        queue.async { [weak self] in
            guard let self, let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.position),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            for old in self.session.inputs { self.session.removeInput(old) }
            if self.session.canAddInput(input) { self.session.addInput(input) }
            self.session.commitConfiguration()
            self.configured = true
        }
    }

    public func capture() async -> UIImage? {
        guard !capturing else { return nil }
        capturing = true
        defer { capturing = false }
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                self.pending = continuation
                let captureDelegate = VoiceCameraDelegate { image in
                    Task { @MainActor in self.finished(image) }
                }
                self.delegate = captureDelegate
                self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: captureDelegate)
            }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        configured = true
    }

    fileprivate func finished(_ image: UIImage?) {
        pending?.resume(returning: image)
        pending = nil
    }
}

/// The capture callback: AVCapture wants an NSObject delegate, so it gets this small proxy that hands
/// the photo back to the model.
private final class VoiceCameraDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let finish: @Sendable (UIImage?) -> Void

    init(_ finish: @escaping @Sendable (UIImage?) -> Void) {
        self.finish = finish
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        finish(photo.fileDataRepresentation().flatMap(UIImage.init(data:)))
    }
}

/// The preview layer, full bleed.
struct VoiceCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// The camera page of the voice sheet: the viewfinder edge to edge, and three controls along the
/// bottom — back, shutter, more. Nothing at the top but the sheet's own grabber.
public struct VoiceCameraPage: View {
    let camera: VoiceCamera
    let onBack: () -> Void
    let onCapture: (UIImage) -> Void

    public init(camera: VoiceCamera, onBack: @escaping () -> Void, onCapture: @escaping (UIImage) -> Void) {
        self.camera = camera
        self.onBack = onBack
        self.onCapture = onCapture
    }

    public var body: some View {
        // The buttons sit in the safe area; everything under them is the viewfinder, all the way to
        // the sheet's bottom corners, so no sheet background shows through.
        ZStack {
            controls
            if camera.access != .granted { status }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.black
                if camera.access == .granted {
                    VoiceCameraPreview(session: camera.session)
                }
            }
            .ignoresSafeArea()
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .task {
            await camera.requestAccess()
            if camera.access == .granted { camera.start() }
        }
        .onDisappear { camera.stop() }
    }

    @ViewBuilder private var status: some View {
        switch camera.access {
        case .denied:
            Text(L10n.tr("The camera needs permission in Settings"))
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(32)
        case .unknown:
            ProgressView().tint(.white)
        case .granted:
            EmptyView()
        }
    }

    /// Back on the left, the shutter in the middle, more on the right: 44pt circles 16pt from the
    /// edges, sitting 16pt above the bottom, all three centred on one line.
    private var controls: some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                glassCircle("arrow-left-s-line", label: "Back") { onBack() }
                Spacer(minLength: 0)
                shutter
                Spacer(minLength: 0)
                // A placeholder for later: the album and the camera flip move in here.
                glassCircle("more-line", label: "More") {}
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    /// A glass ring with a white disc inside it; pressing squeezes the whole thing.
    private var shutter: some View {
        Button {
            Haptics.impact()
            Task {
                if let image = await camera.capture() { onCapture(image) }
            }
        } label: {
            ZStack {
                Circle().fill(.clear)
                Circle().fill(.white).frame(width: 60, height: 60)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
        }
        .buttonStyle(ShutterPress())
        .glass(in: Circle(), interactive: true, tint: .white.opacity(0.18))
        .disabled(camera.capturing)
        .accessibilityLabel(Text(L10n.tr("Take a photo")))
    }

    /// A 44pt circle of dark glass with one white glyph in it.
    private func glassCircle(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RemixIcon(icon, size: 24, weight: .medium)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(CameraPress())
        .glass(in: Circle(), interactive: true, tint: .black.opacity(0.35))
        .accessibilityLabel(Text(L10n.tr(label)))
    }

    private struct CameraPress: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(Motion.press, value: configuration.isPressed)
        }
    }

    private struct ShutterPress: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .animation(Motion.press, value: configuration.isPressed)
        }
    }
}
