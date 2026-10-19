//
//  SceneState.swift
//  film space
//

import Foundation
import RealityKit

enum AppMode: String, CaseIterable {
    case edit = "Edit"
    case camera = "Camera"
}

enum FocalLength: Float, CaseIterable {
    case mm35 = 35
    case mm50 = 50
    case mm75 = 75
    case mm200 = 200

    var label: String { "\(Int(rawValue))mm" }

    var next: FocalLength {
        let all = FocalLength.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// Horizontal field of view for a full-frame (36mm wide) sensor.
    var horizontalFOVDegrees: Float {
        let sensorWidth: Float = 36
        return 2 * atan(sensorWidth / (2 * rawValue)) * 180 / .pi
    }
}

enum ObjectKind: String, CaseIterable, Codable {
    case person, child, car, bike, box, sphere, wall, cylinder, cone, circle, plane, torus
    var label: String { rawValue.capitalized }
}

struct HumanPlacement: Identifiable, Equatable, Codable {
    let id: UUID
    var position: SIMD3<Float>
    var rotationY: Float
    var kind: ObjectKind = .person
    var name: String = "Person"
    var colorHex: String = "596173"
    var scale: SIMD3<Float> = [1, 1, 1]
    var rotationX: Float = 0
    var rotationZ: Float = 0

    init(id: UUID = UUID(), position: SIMD3<Float> = [0, 0, 0], rotationY: Float = 0) {
        self.id = id
        self.position = position
        self.rotationY = rotationY
    }
}

@Observable
final class SceneState {
    var mode: AppMode = .edit
    var humans: [HumanPlacement] = []
    var selectedHumanID: UUID?
    var focalLength: FocalLength = .mm35
    var isRecording = false
    var floorSize: Float = 20
    var movementScale: Float = 1
    var touchSensitivity: Float = 1
    var trackingStatus = "Move the phone slowly to initialize tracking"
    var saveMessage = ""

    struct SavedScene: Codable {
        var objects: [HumanPlacement]
        var floorSize: Float
        var lens: Float
        var movementScale: Float
        var touchSensitivity: Float
    }
    func saveScene() {
        do {
            let data = try JSONEncoder().encode(SavedScene(objects: humans, floorSize: floorSize, lens: focalLength.rawValue, movementScale: movementScale, touchSensitivity: touchSensitivity))
            UserDefaults.standard.set(data, forKey: "film-space-editor-v2")
            saveMessage = "Scene saved on this iPhone"
        } catch { saveMessage = "Could not save: \(error.localizedDescription)" }
    }
    func loadScene() {
        guard let data = UserDefaults.standard.data(forKey: "film-space-editor-v2") else { saveMessage = "No saved scene yet"; return }
        do {
            let saved = try JSONDecoder().decode(SavedScene.self, from: data)
            humans = saved.objects; floorSize = saved.floorSize
            focalLength = FocalLength(rawValue: saved.lens) ?? .mm35
            movementScale = saved.movementScale; touchSensitivity = saved.touchSensitivity
            selectedHumanID = humans.first?.id
            saveMessage = "Scene loaded"
        } catch { saveMessage = "Could not load: \(error.localizedDescription)" }
    }
    func addObject(_ kind: ObjectKind) {
        var object = HumanPlacement(position: [Float(humans.count % 5) * 0.6, 0, 0])
        object.kind = kind; object.name = kind.label + " \(humans.count + 1)"
        if kind == .child { object.scale = [0.65, 0.65, 0.65] }
        humans.append(object); selectedHumanID = object.id
    }
    func editSelected(_ change: (inout HumanPlacement) -> Void) {
        guard let index = humans.firstIndex(where: { $0.id == selectedHumanID }) else { return }
        change(&humans[index])
    }
    func duplicateSelected() {
        guard let old = selectedHuman else { return }
        var copy = HumanPlacement(position: old.position + SIMD3<Float>(0.5, 0, 0), rotationY: old.rotationY)
        copy.kind = old.kind; copy.name = old.name + " copy"; copy.colorHex = old.colorHex
        copy.scale = old.scale; copy.rotationX = old.rotationX; copy.rotationZ = old.rotationZ
        humans.append(copy); selectedHumanID = copy.id
    }

    func cycleFocalLength() {
        focalLength = focalLength.next
    }

    var selectedHuman: HumanPlacement? {
        guard let id = selectedHumanID else { return nil }
        return humans.first { $0.id == id }
    }

    func addHuman() {
        let offset = Float(humans.count) * 0.6
        let placement = HumanPlacement(position: [offset, 0, 0])
        humans.append(placement)
        selectedHumanID = placement.id
    }

    func deleteSelectedHuman() {
        guard let id = selectedHumanID else { return }
        humans.removeAll { $0.id == id }
        selectedHumanID = humans.last?.id
    }

    func selectHuman(id: UUID?) {
        selectedHumanID = id
    }

    func updateHumanPosition(id: UUID, position: SIMD3<Float>) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].position = position
    }

    func updateHumanRotation(id: UUID, rotationY: Float) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].rotationY = rotationY
    }

    func rotateSelectedHuman(by delta: Float) {
        guard let id = selectedHumanID,
              let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].rotationY += delta
    }
}
