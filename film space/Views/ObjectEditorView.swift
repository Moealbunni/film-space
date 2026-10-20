import SwiftUI
import simd
import RealityKit

struct ObjectEditorView: View {
    @Bindable var sceneState: SceneState
    @Bindable var cameraController: OrbitCameraController
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Add an object") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 10) {
                        ForEach(ObjectKind.allCases, id: \.self) { kind in
                            Button(kind.label) { sceneState.addObject(kind) }.buttonStyle(.bordered)
                        }
                    }
                }
                Section("Objects — tap to select") {
                    ForEach(sceneState.humans) { object in
                        Button { sceneState.selectedHumanID = object.id } label: {
                            HStack {
                                Circle().fill(Color(uiColor: SceneContentBuilder.color(object.colorHex))).frame(width: 14, height: 14)
                                Text(object.name); Spacer()
                                if object.id == sceneState.selectedHumanID { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                if sceneState.selectedHuman != nil {
                    Section("Selected object") {
                        TextField("Name", text: Binding(get: { sceneState.selectedHuman?.name ?? "" }, set: { value in sceneState.editSelected { $0.name = value } }))
                        ColorPicker("Color", selection: Binding(get: { Color(uiColor: SceneContentBuilder.color(sceneState.selectedHuman?.colorHex ?? "596173")) }, set: { value in
                            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            UIColor(value).getRed(&r, green: &g, blue: &b, alpha: &a)
                            let hex = String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
                            sceneState.editSelected { $0.colorHex = hex }
                        }), supportsOpacity: false)
                        HStack {
                            ForEach(["EF4444", "3B82F6", "22C55E", "FACC15"], id: \.self) { hex in
                                Button { sceneState.editSelected { $0.colorHex = hex } } label: {
                                    Circle().fill(Color(uiColor: SceneContentBuilder.color(hex))).frame(width: 32, height: 32)
                                }.buttonStyle(.plain).accessibilityLabel(hex == "EF4444" ? "Red" : hex == "3B82F6" ? "Blue" : hex == "22C55E" ? "Green" : "Yellow")
                            }
                        }
                        HStack {
                            Button("Smaller") { sceneState.editSelected { $0.scale = simd_max($0.scale * 0.8, SIMD3<Float>(repeating: 0.05)) } }
                            Button("Bigger") { sceneState.editSelected { $0.scale = simd_min($0.scale * 1.25, SIMD3<Float>(repeating: 20)) } }
                        }.buttonStyle(.bordered)
                        Button("Duplicate") { sceneState.duplicateSelected() }
                        Button("Delete object", role: .destructive) { sceneState.deleteSelectedHuman() }
                    }
                    Section("Position in meters — Y is height") {
                        Button("Reset position") { sceneState.resetObject("position") }
                        vectorControl("X", vector: \.position, axis: 0, range: -50...50)
                        vectorControl("Y", vector: \.position, axis: 1, range: -10...50)
                        vectorControl("Z", vector: \.position, axis: 2, range: -50...50)
                    }
                    Section("Size — 1 is original size") {
                        Button("Reset size") { sceneState.resetObject("scale") }
                        vectorControl("Width", vector: \.scale, axis: 0, range: 0.05...20)
                        vectorControl("Height", vector: \.scale, axis: 1, range: 0.05...20)
                        vectorControl("Depth", vector: \.scale, axis: 2, range: 0.05...20)
                    }
                    Section("Rotation in degrees") {
                        Button("Reset rotation") { sceneState.resetObject("rotation") }
                        rotationControl("X", key: \.rotationX)
                        rotationControl("Y", key: \.rotationY)
                        rotationControl("Z", key: \.rotationZ)
                    }
                }
                Section("Camera axis locks") {
                    CameraAxisPanel(sceneState: sceneState, cameraController: cameraController)
                }
                Section("Floor & camera") {
                    Slider(value: $sceneState.floorSize, in: 2...200, step: 1) { Text("Floor size") }
                    Text("Floor: \(Int(sceneState.floorSize)) meters")
                    Slider(value: $sceneState.movementScale, in: 0.1...10, step: 0.1) { Text("Camera movement scale") }
                    Text("Phone movement: \(sceneState.movementScale, specifier: "%.1f")× — use 0.1–0.5× for slow moves")
                    Slider(value: $sceneState.touchSensitivity, in: 0.1...3, step: 0.1) { Text("Touch sensitivity") }
                    Text("Touch sensitivity: \(sceneState.touchSensitivity, specifier: "%.1f")×")
                    Picker("Lens", selection: $sceneState.focalLength) { ForEach(FocalLength.allCases, id: \.self) { Text($0.label).tag($0) } }.disabled(cameraController.lensLocked)
                }
                Section("Save on this iPhone") {
                    Button("Save scene") { sceneState.saveScene() }
                    Button("Load saved scene") { sceneState.loadScene() }
                    if !sceneState.saveMessage.isEmpty { Text(sceneState.saveMessage) }
                    Text("Save replaces the previous local save. Objects stay in place when switching to Camera. Windows scene-file transfer is not included.").font(.caption)
                }
            }
            .navigationTitle("Scene editor")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func vectorControl(_ label: String, vector: WritableKeyPath<HumanPlacement, SIMD3<Float>>, axis: Int, range: ClosedRange<Float>) -> some View {
        let binding = Binding<Float>(get: { sceneState.selectedHuman?[keyPath: vector][axis] ?? 1 }, set: { value in sceneState.editSelected { $0[keyPath: vector][axis] = min(max(value, range.lowerBound), range.upperBound) } })
        let group = vector == \HumanPlacement.position ? "position" : "scale"
        let locks = group == "position" ? sceneState.selectedHuman?.positionLocks : sceneState.selectedHuman?.scaleLocks
        let locked = locks?[axis] ?? false
        return HStack {
            Button { sceneState.toggleObjectLock(group, axis: axis) } label: { Image(systemName: locked ? "lock.fill" : "lock.open") }.buttonStyle(.borderless).accessibilityLabel("Lock " + group + " " + label)
            Text(label); Spacer(); TextField(label, value: binding, format: .number.precision(.fractionLength(2))).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(width: 90).disabled(locked)
            Stepper(label, value: binding, in: range, step: 0.1).labelsHidden().disabled(locked)
        }
    }
    private func rotationControl(_ label: String, key: WritableKeyPath<HumanPlacement, Float>) -> some View {
        let binding = Binding<Float>(get: { (sceneState.selectedHuman?[keyPath: key] ?? 0) * 180 / .pi }, set: { value in sceneState.editSelected { $0[keyPath: key] = value * .pi / 180 } })
        let axis = label == "X" ? 0 : label == "Y" ? 1 : 2
        let locked = sceneState.selectedHuman?.rotationLocks[axis] ?? false
        return HStack {
            Button { sceneState.toggleObjectLock("rotation", axis: axis) } label: { Image(systemName: locked ? "lock.fill" : "lock.open") }.buttonStyle(.borderless)
            Text(label); Slider(value: binding, in: -180...180, step: 5).disabled(locked); Text("\(Int(binding.wrappedValue))°").frame(width: 50) }
    }
}

struct CameraAxisPanel: View {
    @Bindable var sceneState: SceneState
    @Bindable var cameraController: OrbitCameraController
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["position", "rotation"], id: \.self) { group in
                HStack {
                    Text(group.capitalized)
                    Spacer()
                    Button("Reset") { cameraController.resetAxes(group, cameraMode: sceneState.mode == .camera) }.buttonStyle(.borderless)
                }
                HStack {
                    ForEach(0..<3, id: \.self) { axis in
                        let locked = group == "position" ? cameraController.positionLocks[axis] : cameraController.rotationLocks[axis]
                        VStack {
                            Button {
                                cameraController.toggleAxis(group, axis: axis, cameraMode: sceneState.mode == .camera)
                            } label: {
                                Label(["X", "Y", "Z"][axis], systemImage: locked ? "lock.fill" : "lock.open")
                            }.buttonStyle(.bordered).tint(locked ? .orange : .blue)
                            TextField(group, value: cameraValue(group, axis: axis), format: .number.precision(.fractionLength(1)))
                                .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.center).disabled(locked || cameraController.isViewLocked)
                        }
                    }
                }
            }
            Toggle("Lock lens / zoom", isOn: $cameraController.lensLocked)
            Button("Reset camera") { cameraController.resetAxes("all", cameraMode: sceneState.mode == .camera) }
            Text("Locks hold the current world-axis values. Reset clears that group's locks. Camera size does not change perspective; use lens/zoom instead.").font(.caption)
        }
    }
    private func cameraValue(_ group: String, axis: Int) -> Binding<Float> {
        Binding(get: {
            let pose = sceneState.mode == .camera ? (cameraController.liveCameraTransform ?? cameraController.worldTransform) : cameraController.worldTransform
            return group == "position" ? pose.columns.3[axis] : OrbitCameraController.angles(pose)[axis] * 180 / .pi
        }, set: { value in
            guard value.isFinite else { return }
            let pose = sceneState.mode == .camera ? (cameraController.liveCameraTransform ?? cameraController.worldTransform) : cameraController.worldTransform
            var position = SIMD3<Float>(pose.columns.3.x,pose.columns.3.y,pose.columns.3.z)
            var angles = OrbitCameraController.angles(pose)
            if group == "position" { position[axis] = value } else { angles[axis] = value * .pi / 180 }
            cameraController.setManualPose(OrbitCameraController.pose(position: position, angles: angles))
        })
    }

}
