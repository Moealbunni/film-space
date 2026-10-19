//
//  ContentView.swift
//  film space
//

import SwiftUI
import simd

struct ContentView: View {
    @State private var sceneState = SceneState()
    @State private var cameraController = OrbitCameraController()

    @State private var showRecordingControls = false
    @State private var showLink = false
    @State private var showEditor = false
    @State private var showCamera = false

    var body: some View {
        ZStack {
            Group {
                switch sceneState.mode {
                case .edit:
                    VirtualStudioView(sceneState: sceneState, cameraController: cameraController)
                case .camera:
                    ARCameraView(sceneState: sceneState, cameraController: cameraController)
                }
            }
            .ignoresSafeArea()

            if !sceneState.isRecording || showRecordingControls {
            VStack {
                HStack {
                    if sceneState.mode == .edit {
                        Button("Objects & scene") { showEditor = true }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Text(sceneState.trackingStatus).font(.caption).padding(8).background(.ultraThinMaterial, in: Capsule())
                    }
                    Button("Camera controls") { showCamera = true }.buttonStyle(.borderedProminent)
                    if sceneState.isRecording { Button("Hide controls") { showRecordingControls = false } }
                    Button("Desktop link") { showLink = true }.buttonStyle(.bordered).disabled(sceneState.isRecording)
                    Spacer()
                    if cameraController.isViewLocked {
                        Button("Unlock viewpoint") { cameraController.isViewLocked = false }.buttonStyle(.borderedProminent)
                    }
                }.padding()
                if sceneState.mode == .edit, let selected = sceneState.selectedHuman {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text(selected.name).font(.caption.bold())
                            Button("Bigger") { sceneState.editSelected { $0.scale = simd_min($0.scale * 1.25, SIMD3<Float>(repeating: 20)) } }
                            Button("Smaller") { sceneState.editSelected { $0.scale = simd_max($0.scale * 0.8, SIMD3<Float>(repeating: 0.05)) } }
                            Button("Lift ↑") { sceneState.editSelected { $0.position.y += 0.1 } }
                            Button("Lower ↓") { sceneState.editSelected { $0.position.y -= 0.1 } }
                            Button("Edit details") { showEditor = true }
                        }.buttonStyle(.bordered).padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }.padding(.horizontal)
                }
                Spacer()
                StudioToolbar(sceneState: sceneState, cameraController: cameraController)
                    .padding(.bottom, 16)
            }
            } else {
                VStack { Spacer(); HStack {
                    Button("Controls") { showRecordingControls = true }.buttonStyle(.bordered)
                    Spacer()
                    Button("■ Stop recording") { sceneState.isRecording = false }.buttonStyle(.borderedProminent).tint(.red)
                }.padding() }
            }
        }
        .onChange(of: sceneState.isRecording) { _, _ in showRecordingControls = false }
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

#Preview {
    ContentView()
}
