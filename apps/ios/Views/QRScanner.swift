import AVFoundation
import CodyncKit
import SwiftUI
import VisionKit

/// Starts the camera only while its UIKit controller is visible and releases it on removal.
struct QRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void
    /// Payload prefixes to accept. nil accepts any barcode, which is what the DSH pairing QR
    /// needs: it carries a base64url payload, not a codync:// link.
    var acceptedPrefixes: [String]? = [AppEnvironment.current.urlScheme + "://"]
    /// `.accurate` reads dense codes better than `.fast`; it costs a little power.
    var qualityLevel: DataScannerViewController.QualityLevel = .accurate

    func makeUIViewController(context: Context) -> Controller {
        Controller(onCode: onCode, onError: onError, acceptedPrefixes: acceptedPrefixes, qualityLevel: qualityLevel)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onCode = onCode
        controller.onError = onError
        controller.acceptedPrefixes = acceptedPrefixes
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.stop()
    }

    final class Controller: UIViewController, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        var onError: (String) -> Void
        var acceptedPrefixes: [String]?
        private let scanner: DataScannerViewController
        private var startTask: Task<Void, Never>?
        private var visible = false
        private var done = false

        init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void,
             acceptedPrefixes: [String]?, qualityLevel: DataScannerViewController.QualityLevel) {
            self.onCode = onCode
            self.onError = onError
            self.acceptedPrefixes = acceptedPrefixes
            scanner = DataScannerViewController(
                recognizedDataTypes: [.barcode(symbologies: [.qr])],
                qualityLevel: qualityLevel,
                isGuidanceEnabled: true,
                isHighlightingEnabled: true
            )
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidLoad() {
            super.viewDidLoad()
            scanner.delegate = self
            addChild(scanner)
            view.addSubview(scanner.view)
            scanner.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
                scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            scanner.didMove(toParent: self)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            visible = true
            startTask?.cancel()
            startTask = Task { [weak self] in
                let allowed = await AVCaptureDevice.requestAccess(for: .video)
                guard let self, !Task.isCancelled, visible, !done else { return }
                guard allowed else {
                    onError("相机权限未开启，请在 iPhone 设置中允许此 App 使用相机。")
                    return
                }
                guard DataScannerViewController.isAvailable else {
                    onError("相机暂时不可用，请关闭其他相机页面后重试。")
                    return
                }
                do { try scanner.startScanning() }
                catch { onError("无法启动扫码相机：\(error.localizedDescription)") }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            stop()
        }

        func stop() {
            visible = false
            startTask?.cancel()
            startTask = nil
            scanner.stopScanning()
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard visible, !done else { return }
            for case let .barcode(code) in items {
                guard let raw = code.payloadStringValue else { continue }
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { continue }
                if let acceptedPrefixes, !acceptedPrefixes.contains(where: { value.hasPrefix($0) }) { continue }
                done = true
                scanner.stopScanning()
                onCode(value)
                return
            }
        }

        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            guard visible, !done else { return }
            onError("扫码相机已中断，请点击重试相机。\(error.localizedDescription)")
        }
    }
}
