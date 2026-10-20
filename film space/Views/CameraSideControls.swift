import SwiftUI
import Combine

struct CameraSideControls: View {
    @Bindable var state: SceneState
    @Bindable var camera: OrbitCameraController
    var openAxes: () -> Void
    @State private var joystick: CGSize = .zero
    @State private var vertical: Float = 0
    @State private var zoomDirection: Float = 0
    private let tick = Timer.publish(every: 1.0/30, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 8) {
            Text("Zoom \(state.zoomMultiplier, specifier: "%.2f")×").font(.caption.bold())
            Slider(value: $state.zoomMultiplier, in: 0.5...4).disabled(camera.lensLocked).accessibilityLabel("Smooth zoom")
            HStack {
                zoomButton("− Zoom", direction: -1)
                zoomButton("+ Zoom", direction: 1)
            }.disabled(camera.lensLocked)
            HStack { ForEach([Float(0.5), 1, 2, 4], id: \.self) { value in
                Button("\(value, specifier: "%g")×") { state.zoomMultiplier = value }.buttonStyle(.borderless).disabled(camera.lensLocked)
            } }
            Joystick(value: $joystick, size: 82).accessibilityLabel("Camera movement joystick")
            HStack {
                hold("↓ Down", active: { vertical = $0 ? -1 : 0 })
                hold("↑ Up", active: { vertical = $0 ? 1 : 0 })
            }
            Text("Movement \(state.movementScale, specifier: "%.1f")×")
            Slider(value: $state.movementScale, in: 0.1...10, step: 0.1).accessibilityLabel("Movement multiplier")
            HStack { ForEach([Float(1), 2.5, 5, 10], id: \.self) { value in
                Button("\(value, specifier: "%g")×") { state.movementScale = value }.buttonStyle(.borderless)
            } }
            Text("1 m walked = \(state.movementScale, specifier: "%.1f") m in scene").font(.caption2)
            Text("Camera smoothing")
            Slider(value: $state.cameraSmoothing, in: 0...1).accessibilityLabel("Camera smoothing")
            Button(camera.isViewLocked ? "Unlock viewpoint" : "Lock viewpoint") {
                if camera.isViewLocked { camera.isViewLocked = false }
                else { camera.lockedTransform = state.mode == .camera ? (camera.liveCameraTransform ?? camera.worldTransform) : camera.worldTransform; camera.isViewLocked = true }
            }
            Button("Axis locks / Reset", action: openAxes)
            Menu("Lens / saved view") {
                Picker("Lens", selection: $state.focalLength) {
                    ForEach(FocalLength.allCases, id: \.self) { Text($0.label).tag($0) }
                }.disabled(camera.lensLocked)
                Button("Return to saved view") {
                    if state.mode == .camera { camera.pendingRecenter = true }
                    else { camera.returnToLockedTransform() }
                }.disabled(camera.lockedTransform == nil)
                if state.mode == .camera {
                    Button("Shoulder position") { camera.pendingShoulderPlacement = true }
                }
            }
        }
        .onReceive(tick) { _ in
            if !camera.lensLocked && zoomDirection != 0 {
                state.zoomMultiplier = min(max(state.zoomMultiplier * exp(zoomDirection * 0.6 / 30), 0.5), 4)
            }
            let input = SIMD3<Float>(Float(joystick.width), vertical, Float(-joystick.height))
            if state.mode == .camera { camera.movementInput = input }
            else if input != .zero {
                camera.moveHorizontally(by: input.x * state.movementScale / 30)
                camera.moveVertically(by: input.y * state.movementScale / 30)
                camera.moveForward(by: input.z * state.movementScale / 30)
            }
        }
        .onDisappear { camera.movementInput = .zero; joystick = .zero; vertical = 0; zoomDirection = 0 }
        .onChange(of: state.mode) { _, _ in joystick = .zero; vertical = 0; camera.movementInput = .zero }
    }
    private func zoomButton(_ label: String, direction: Float) -> some View {
        Button(label) {
            state.zoomMultiplier = min(max(state.zoomMultiplier * exp(direction * 0.15), 0.5), 4)
        }.accessibilityLabel(direction > 0 ? "Zoom in" : "Zoom out")
         .onLongPressGesture(minimumDuration: 0.25, pressing: { pressing in
             if !pressing { zoomDirection = 0 }
         }) { zoomDirection = direction }
    }
    private func hold(_ label: String, active: @escaping (Bool) -> Void) -> some View {
        Text(label).padding(8).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in active(true) }.onEnded { _ in active(false) })
    }
}
