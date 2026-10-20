import SwiftUI
import simd

struct ContentView: View {
    @State private var sceneState = SceneState()
    @State private var cameraController = OrbitCameraController()
    @State private var showControls = true
    @State private var showLink = false
    @State private var showEditor = false
    @State private var showCamera = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Keep one renderer and one tracking session alive across mode changes.
                ARCameraView(sceneState: sceneState, cameraController: cameraController).ignoresSafeArea()
                VStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Menu {
                                Button("Objects & scene") { showEditor = true }.disabled(sceneState.isRecording)
                                Button("Camera axis locks & reset") { showCamera = true }
                                Button("Desktop link") { showLink = true }.disabled(sceneState.isRecording)
                                Button("Save scene") { sceneState.saveScene() }
                            } label: { Label("Menu", systemImage: "line.3.horizontal") }
                            ForEach(AppMode.allCases, id: \.self) { mode in
                                Button(mode.rawValue) {
                                    guard sceneState.mode != mode else { return }
                                    cameraController.movementInput = .zero
                                    sceneState.mode = mode
                                }.tint(sceneState.mode == mode ? .blue : .gray)
                                 .disabled(sceneState.isRecording)
                                 .accessibilityIdentifier("mode" + mode.rawValue)
                            }
                            Button(showControls ? "Hide controls" : "Controls") { showControls.toggle() }
                            if sceneState.mode == .camera {
                                Button(sceneState.isRecording ? "■ Stop" : "● Record") { sceneState.isRecording.toggle() }
                                    .tint(.red).accessibilityIdentifier("recordVideo")
                            }
                        }.buttonStyle(.borderedProminent).font(.caption)
                    }.frame(height: 52).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Spacer()
                    if !sceneState.isRecording && sceneState.mode == .camera {
                        Text(sceneState.trackingStatus).font(.caption).padding(6).background(.ultraThinMaterial, in: Capsule()).allowsHitTesting(false)
                    }
                }.padding(8)
                if showControls {
                    ScrollView {
                        CameraSideControls(state: sceneState, camera: cameraController, openAxes: { showCamera = true })
                        if sceneState.mode == .edit {
                            Button("Add / edit objects") { showEditor = true }.buttonStyle(.borderedProminent)
                            if let selected = sceneState.selectedHuman {
                                Text(selected.name).font(.caption.bold())
                                HStack {
                                    Button("Smaller") { sceneState.editSelected { $0.scale = simd_max($0.scale * 0.8, SIMD3<Float>(repeating: 0.05)) } }
                                    Button("Bigger") { sceneState.editSelected { $0.scale = simd_min($0.scale * 1.25, SIMD3<Float>(repeating: 20)) } }
                                }
                                HStack {
                                    Button("Lower") { sceneState.editSelected { $0.position.y -= 0.1 } }
                                    Button("Lift") { sceneState.editSelected { $0.position.y += 0.1 } }
                                }
                                Button("Delete selected", role: .destructive) { sceneState.deleteSelectedHuman() }
                            }
                        }
                    }.font(.caption).buttonStyle(.bordered)
                     .padding(10).frame(width: 182)
                     .frame(maxHeight: max(100, geometry.size.height - 88))
                     .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                     .padding(.trailing, 8).padding(.top, 64)
                }
            }
        }
        .onChange(of: sceneState.isRecording) { _, recording in if recording { showControls = false } }
        .onChange(of: phase) { _, phase in
            sceneState.trackingSuspended = phase != .active
            if phase != .active { sceneState.isRecording = false; cameraController.movementInput = .zero }
        }
        .sheet(isPresented: $showLink) { DesktopLinkView(state: sceneState) }
        .sheet(isPresented: $showCamera) {
            NavigationStack {
                Form { CameraAxisPanel(sceneState: sceneState, cameraController: cameraController) }
                    .navigationTitle("Camera controls")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCamera = false } } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEditor) { ObjectEditorView(sceneState: sceneState, cameraController: cameraController) }
    }
}
