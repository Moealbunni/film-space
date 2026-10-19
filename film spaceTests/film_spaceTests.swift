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
    }
}
