import AVFoundation
import CodyncKit
import CodyncUI
import SwiftUI
import UIKit

/// AVCapture-backed still camera for the home pull-to-capture gesture. Lives in the app target;
/// the captured still becomes a normal attachment on a bot, with no host protocol changes.
final class QuickCamera: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "com.suiyikou.codync.quickcamera")
    private let output = AVCapturePhotoOutput()
    private var configured = false
    private var delegate: PhotoDelegate?

    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run { authorized = true }
            return true
        case .notDetermined:
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { authorized = ok }
            return ok
        default:
            await MainActor.run { authorized = false }
            return false
        }
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            guard self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        configured = true
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let settings = AVCapturePhotoSettings()
                let delegate = PhotoDelegate { image in continuation.resume(returning: image) }
                self.delegate = delegate
                self.output.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        let finish: (UIImage?) -> Void
        init(_ finish: @escaping (UIImage?) -> Void) { self.finish = finish }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) { finish(image) }
            else { finish(nil) }
        }
    }
}

/// Live back-camera feed for the pull-down capture card.
struct QuickCameraPreview: UIViewRepresentable {
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

/// State of the home pull-to-capture gesture.
@MainActor
@Observable
final class QuickCaptureModel {
    static let openThreshold: CGFloat = 64

    var pullDistance: CGFloat = 0
    var isOpen = false
    var busy = false
    let camera = QuickCamera()

    var showsOverlay: Bool { pullDistance > 0 || isOpen }
    var expand: CGFloat { min(max(pullDistance / Self.openThreshold, 0), 1) }

    func pull(_ distance: CGFloat) {
        guard !busy else { return }
        pullDistance = max(distance, 0)
        if pullDistance >= Self.openThreshold, !isOpen {
            isOpen = true
            Task { await camera.requestAccess(); camera.start() }
        }
    }

    func open() {
        isOpen = true
        Task { await camera.requestAccess(); camera.start() }
    }

    func close() {
        camera.stop()
        isOpen = false
        pullDistance = 0
    }

    func capture() async -> UIImage? {
        guard !busy else { return nil }
        busy = true
        defer { busy = false }
        if !camera.authorized { _ = await camera.requestAccess() }
        guard camera.authorized else { return nil }
        return await camera.capturePhoto()
    }
}

/// Native bottom-sheet camera: a live preview with a system-style round shutter. Capturing hands
/// the still to `onCapture` (which attaches it to the main agent and closes the sheet).
struct QuickCaptureSheet: View {
    var onCapture: (UIImage) -> Void
    @StateObject private var camera = QuickCamera()
    @State private var busy = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.authorized {
                QuickCameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    RemixIcon("camera-fill").font(.largeTitle).foregroundStyle(.white)
                    Text("需要相机权限").foregroundStyle(.white)
                    Button("打开设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .buttonStyle(.bordered).tint(.white)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Button { dismiss() } label: {
                        RemixIcon("arrow-left-s-line", size: 24)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回")

                    Spacer(minLength: 24)
                    shutter
                    Spacer(minLength: 24)

                    Menu {
                        // Placeholder for now; nothing in it yet.
                    } label: {
                        RemixIcon("more-line", size: 24)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }
                    .accessibilityLabel("更多")
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 36)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .task { _ = await camera.requestAccess(); camera.start() }
        .onDisappear { camera.stop() }
    }

    private var shutter: some View {
        Button {
            Task {
                busy = true
                let image = await camera.capturePhoto()
                busy = false
                if let image { onCapture(image) }
            }
        } label: {
            ZStack {
                Circle().glassEffect(.regular.interactive(), in: Circle()).frame(width: 64, height: 64)
                Circle().fill(.white).frame(width: 54, height: 54)
            }
            .frame(width: 64, height: 64)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel("拍摄")
    }
}
