//
//  ContentView.swift
//  film space
//

import SwiftUI

struct ContentView: View {
    @State private var sceneState = SceneState()
    @State private var cameraController = OrbitCameraController()

    @State private var showEditor = false

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

            VStack {
                HStack {
                    if sceneState.mode == .edit {
                        Button("Objects & scene") { showEditor = true }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Text(sceneState.trackingStatus).font(.caption).padding(8).background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    if cameraController.isViewLocked {
                        Button("Unlock viewpoint") { cameraController.isViewLocked = false }.buttonStyle(.borderedProminent)
                    }
                }.padding()
                Spacer()
                StudioToolbar(sceneState: sceneState, cameraController: cameraController)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showEditor) { ObjectEditorView(sceneState: sceneState) }
    }
}

#Preview {
    ContentView()
}
