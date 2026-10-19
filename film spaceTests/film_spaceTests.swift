import Testing
import Foundation
import RealityKit
@testable import film_space

struct film_spaceTests {
    @Test @MainActor func editorRoundTripAndGeometry() throws {
        let state = SceneState()
        for kind in ObjectKind.allCases { state.addObject(kind) }
        #expect(state.humans.count == 12)
        state.editSelected { object in
            object.name = "Yellow reference"; object.colorHex = "FACC15"
            object.position = [2,3,-4]; object.scale = [2,0.5,3]
            object.rotationX = 0.2; object.rotationY = 0.5; object.rotationZ = -0.3
        }
        let expected = state.humans
        state.floorSize = 50; state.movementScale = 0.3
        state.saveScene(); state.humans = []; state.loadScene()
        #expect(state.humans == expected)
        #expect(state.floorSize == 50)
        #expect(state.movementScale == 0.3)
        state.selectedHumanID = state.humans.last?.id
        state.duplicateSelected()
        #expect(state.humans.count == 13)
        #expect(state.humans.last?.colorHex == "FACC15")
        state.deleteSelectedHuman(); #expect(state.humans.count == 12)
        state.selectedHumanID = state.humans.last?.id
        let originalScale = state.selectedHuman!.scale
        state.toggleObjectLock("scale", axis: 1)
        state.editSelected { $0.scale *= 2 }
        #expect(state.selectedHuman!.scale.y == originalScale.y)
        #expect(state.selectedHuman!.scale.x == originalScale.x * 2)
        state.resetObject("scale"); #expect(state.selectedHuman!.scale == SIMD3<Float>(1,1,1))
        let root = Entity()
        SceneContentBuilder.syncHumans(placements: state.humans, selectedID: nil, into: root)
        #expect(root.children.count == 12)
        SceneContentBuilder.syncHumans(placements: [], selectedID: nil, into: root)
        #expect(root.children.isEmpty)
        let camera = OrbitCameraController()
        let start = camera.distance
        camera.isViewLocked = true; camera.zoom(scale: 2)
        #expect(camera.distance == start)
        camera.isViewLocked = false; camera.zoom(scale: 2)
        #expect(camera.distance < start)
        camera.lockedPosition = [2,3,4]; camera.positionLocks = [true,false,true]
        camera.lockedRotation = [0,Float.pi/4,0]; camera.rotationLocks = [false,true,false]
        let constrained = camera.constrained(OrbitCameraController.pose(position: [9,8,7], angles: [0.1,0.2,0.3]))
        #expect(abs(constrained.columns.3.x - 2) < 0.001)
        #expect(abs(constrained.columns.3.y - 8) < 0.001)
        #expect(abs(constrained.columns.3.z - 4) < 0.001)
        #expect(abs(OrbitCameraController.angles(constrained).y - Float.pi/4) < 0.001)
    }
}
