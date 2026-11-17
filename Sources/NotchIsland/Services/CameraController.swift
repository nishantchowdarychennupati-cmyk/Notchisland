import AppKit
import AVFoundation
import SwiftUI

/// Front camera for the Mirror tab. Runs only while the Mirror tab is visible, at a low-power preset.
final class CameraController: ObservableObject {
    @Published private(set) var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning = false
    @Published private(set) var hasCamera = true

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "notchisland.camera")
    private var configured = false
    private var wanted = false

    func start() {
        wanted = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.status = AVCaptureDevice.authorizationStatus(for: .video)
                    if self.wanted && self.status == .authorized { self.run() }
                }
            }
        case .authorized:
            status = .authorized
            run()
        default:
            status = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    func stop() {
        wanted = false
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func run() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .medium
                if let device = AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    DispatchQueue.main.async { self.hasCamera = false }
                }
                self.session.commitConfiguration()
                self.configured = true
            }
            guard self.wanted, !self.session.isRunning, !self.session.inputs.isEmpty else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }
}

/// Hosts an AVCaptureVideoPreviewLayer.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: NSView {
        let previewLayer: AVCaptureVideoPreviewLayer

        init(session: AVCaptureSession) {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            super.init(frame: .zero)
            layer = previewLayer
            wantsLayer = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }

    func makeNSView(context: Context) -> PreviewView { PreviewView(session: session) }
    func updateNSView(_ view: PreviewView, context: Context) {}
}
