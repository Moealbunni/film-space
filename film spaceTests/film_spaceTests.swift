import Testing
import Foundation
import RealityKit
import AVFoundation
import UIKit
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
    @Test @MainActor func localPairingAndSceneTransfer() throws {
        let token = String(repeating: "a", count: 48)
        let pair = try DesktopLink.parsePair("filmspace://pair?host=192.168.1.2&port=54321&token=\(token)")
        #expect(pair.0.absoluteString == "http://192.168.1.2:54321")
        for host in ["8.8.8.8", "localhost", "192.168.x.1.2", "192..168.1.2", "192.168.999.2"] {
            #expect(throws: (any Error).self) { try DesktopLink.parsePair("filmspace://pair?host=\(host)&port=54321&token=\(token)") }
        }
        let source = SceneState()
        for kind in ObjectKind.allCases { source.addObject(kind) }
        source.floorSize = 75; source.focalLength = .mm24
        source.editSelected { $0.position = [2,3,-4]; $0.scale = [2,3,4]; $0.rotationX = 0.2; $0.rotationY = 0.7; $0.colorHex = "FF0000" }
        let encoded = try JSONEncoder().encode(LinkedScene(state: source))
        var scene = try JSONDecoder().decode(LinkedScene.self, from: encoded)
        let target = SceneState(); try scene.apply(to: target)
        #expect(target.humans.count == 12)
        #expect(target.floorSize == 75)
        #expect(target.focalLength == .mm24)
        #expect(target.humans.last?.position == SIMD3<Float>(2,3,-4))
        #expect(target.humans.last?.scale == SIMD3<Float>(2,3,4))
        #expect(target.humans.last?.colorHex == "FF0000")
        #expect(target.humans.last?.rotationY == 0.7)
        let previous = target.humans
        scene.objects[0].scale = [-1,1,1]
        #expect(throws: (any Error).self) { try scene.apply(to: target) }
        #expect(target.humans == previous)
    }
    @Test @MainActor func smoothCameraAndReusableGeometry() throws {
        #expect(CameraMotion.response(dt: 1/60, smoothing: 0) == 1)
        let a = CameraMotion.response(dt: 1/60, smoothing: 0.5)
        #expect(a > 0 && a < 1)
        let one = CameraMotion.smoothLens(current: 35, target: 140, dt: 1/30)
        let half = CameraMotion.smoothLens(current: 35, target: 140, dt: 1/60)
        let two = CameraMotion.smoothLens(current: half, target: 140, dt: 1/60)
        #expect(abs(one - two) < 0.001)
        #expect(one > 35 && one < 140)
        var lens: Float = 35
        for _ in 0..<120 { lens = CameraMotion.smoothLens(current: lens, target: 140, dt: 1/60) }
        #expect(abs(lens - 140) < 0.01)
        let state = SceneState(); state.addObject(.car)
        let root = Entity()
        SceneContentBuilder.syncHumans(placements: state.humans, selectedID: nil, into: root)
        let original = root.children.first!
        state.editSelected { $0.colorHex = "FF0000"; $0.position.x = 4 }
        SceneContentBuilder.syncHumans(placements: state.humans, selectedID: nil, into: root)
        #expect(root.children.first === original)
        #expect(original.position.x == 4)
        state.zoomMultiplier = 2.5; state.movementScale = 10; state.cameraSmoothing = 0.7
        state.saveScene(); state.zoomMultiplier = 1; state.movementScale = 1; state.loadScene()
        #expect(state.zoomMultiplier == 2.5 && state.movementScale == 10)
        #expect(state.cameraSmoothing == 0.7)
    }
    @Test @MainActor func movieEncodesSixtyFramesPerSecond() async throws {
        let writer = MediaWriter()
        writer.prepare(sourceWidth: 320, sourceHeight: 180)
        await writer.drain()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 180)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
        }.cgImage!
        for frame in 0..<60 {
            writer.appendVideo(image, hostTimeSeconds: 10 + Double(frame)/60)
            await writer.drain()
        }
        let result: URL? = await withCheckedContinuation { continuation in
            writer.finish { continuation.resume(returning: $0) }
        }
        let url = try #require(result)
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let fps = try await track.load(.nominalFrameRate)
        #expect(fps >= 59 && fps <= 61)
        let duration = try await asset.load(.duration)
        #expect(duration.seconds > 0.95 && duration.seconds < 1.1)
    }
}
