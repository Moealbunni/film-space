import SwiftUI
import AVFoundation

struct DesktopLinkView: View {
    @Bindable var state: SceneState
    @State private var text = ""
    @State private var scanning = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Pair on the same Wi-Fi") {
                    Text("On Windows, open Connect iPhone and press Start pairing. Scan its QR here. Allow Local Network access when iOS asks.")
                    Button("Scan desktop QR") { state.mode = .edit; state.trackingSuspended = true; scanning = true }.disabled(state.isRecording)
                    TextField("Or paste the pairing address", text: $text).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Connect") { Task { await state.desktopLink.connect(text) } }
                    Text(state.desktopLink.message)
                    Button("Disconnect") { state.desktopLink.disconnect() }
                }
                Section("Transfer your scene") {
                    Button("Load desktop scene — replaces current scene") { Task { await state.desktopLink.loadScene(into: state) } }.disabled(!state.desktopLink.isConnected || state.isRecording)
                    Button("Send scene to desktop") { Task { await state.desktopLink.sendScene(state) } }.disabled(!state.desktopLink.isConnected)
                    Text("Save your current scene first if you need it. Transfers include object types, colors, names, transforms, floor size and lens. Axis locks and saved camera viewpoints stay local.").font(.caption)
                }
                Section("Live monitor") {
                    Button("Show live view on Windows") {
                        state.trackingSuspended = false
                        state.trackingRestartID = UUID()
                        state.mode = .camera
                        Task { await state.desktopLink.showMonitor() }
                        dismiss()
                    }.disabled(!state.desktopLink.isConnected)
                    Text(state.desktopLink.previewStatus)

                    Text("Tap Show live view on Windows, or tap Done and press Live Monitor on Windows. Preview works in both Edit and Camera. The desktop displays the actual iPhone scene, with a recording indicator. The preview is lower resolution and has no audio; your full MP4 is recorded on the iPhone.")
                    Text("Keep both apps open. No cloud service or AI credits are used. Use a trusted private Wi-Fi network.").font(.caption)
                }
            }.navigationTitle("Desktop link")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { state.trackingSuspended = false; dismiss() } } }
                .sheet(isPresented: $scanning, onDismiss: { state.trackingSuspended = false; state.trackingRestartID = UUID() }) { QRScanner { result in text = result; scanning = false; Task { await state.desktopLink.connect(result) } } }
        }
    }
}
struct QRScanner: UIViewRepresentable {
    var onCode: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }
    func makeUIView(context: Context) -> Preview {
        let view = Preview(); context.coordinator.authorize(view); return view
    }
    func updateUIView(_ uiView: Preview, context: Context) {}
    static func dismantleUIView(_ uiView: Preview, coordinator: Coordinator) { coordinator.stop() }
    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    }
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        let onCode: (String) -> Void
        var delivered = false
        var stopped = false
        private let captureQueue = DispatchQueue(label: "film-space.qr-camera")
        func stop() {
            stopped = true
            let capture = session
            captureQueue.async { capture.stopRunning() }
        }
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
        func authorize(_ view: Preview) {
            AVCaptureDevice.requestAccess(for: .video) { [weak self, weak view] allowed in
                Task { @MainActor in
                    guard let self, let view else { return }
                    if allowed, !self.stopped { self.setup(view) } else {
                        let label = UILabel(); label.text = "Allow Camera in iPhone Settings, or swipe down and paste the pairing address."; label.numberOfLines = 0; label.textColor = .white; label.frame = CGRect(x: 24, y: 50, width: 280, height: 160); view.addSubview(label)
                    }
                }
            }
        }
        func setup(_ view: Preview) {
            guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output); output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]
            let layer = view.layer as! AVCaptureVideoPreviewLayer; layer.session = session; layer.videoGravity = .resizeAspectFill
            let capture = session
            captureQueue.async { capture.startRunning() }
        }
        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let text = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
            Task { @MainActor in
                guard !self.delivered, !self.stopped else { return }
                self.delivered = true
                let capture = self.session
                self.captureQueue.async {
                    capture.stopRunning()
                    Task { @MainActor in
                        guard !self.stopped else { return }
                        self.onCode(text)
                    }
                }
            }
        }
    }
}
