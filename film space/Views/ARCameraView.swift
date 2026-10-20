//
//  ARCameraView.swift
//  film space
//

import SwiftUI
import RealityKit
import ARKit
import UIKit

struct ARCameraView: UIViewRepresentable {
    @Bindable var sceneState: SceneState
    var cameraController: OrbitCameraController

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneState: sceneState, cameraController: cameraController)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(SceneEnvironment.studioGrey)
        context.coordinator.setup(in: arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.sceneState = sceneState
        context.coordinator.rebuildScene()
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.recorder.stop()
        coordinator.sceneState.isRecording = false
        coordinator.shutdown()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        var sceneState: SceneState
        let cameraController: OrbitCameraController
        var editCameraTransform: simd_float4x4
        let trackingSession = ARSession()
        let recorder = SceneRecorder()

        private weak var arView: ARView?
        private var studioRoot: Entity?
        private var cameraEntity: Entity?
        private var referenceTransform: simd_float4x4?
        private var lastHumans: [HumanPlacement]?
        private var lastFloor: Float?
        private var currentMode: AppMode?
        private var latestDevice: simd_float4x4?
        private var displayLink: CADisplayLink?
        private var lastTick: TimeInterval = 0
        private var trackingStarted = false
        private var trackingPaused = false
        private var lastMovementScale: Float = 1
        private var virtualOffset: SIMD3<Float> = .zero
        private var filteredPose: Transform?
        private var displayedLens: Float = 35
        private var dragStart: SIMD3<Float>?
        private var pinchStart: Float = 1
        private var lastFocalLength: FocalLength?
        private var previewBusy = false
        private var lastPreview: TimeInterval = 0

        init(sceneState: SceneState, cameraController: OrbitCameraController) {
            self.sceneState = sceneState
            self.cameraController = cameraController
            self.editCameraTransform = cameraController.worldTransform
        }

        func setup(in arView: ARView) {
            self.arView = arView

            let anchor = AnchorEntity(world: .zero)

            let root = SceneEnvironment.makeStudioRoot()
            anchor.addChild(root)
            studioRoot = root

            let camera = cameraController.makeCameraEntity()
            camera.transform = Transform(matrix: editCameraTransform)
            anchor.addChild(camera)
            cameraEntity = camera

            arView.scene.addAnchor(anchor)

            rebuildScene()
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            arView.addGestureRecognizer(pan)
            arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
            arView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
            recorder.onPreview = { [weak self] image in
                guard let self else { return }
                self.sceneState.desktopLink.sendPreview(image, recording: true)
            }
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.preferredFramesPerSecond = 60
            link.add(to: .main, forMode: .common); displayLink = link
        }

        private func startTracking() {
            guard ARWorldTrackingConfiguration.isSupported, !trackingStarted else { return }
            trackingStarted = true
            trackingSession.delegate = self
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = []
            config.environmentTexturing = .none
            trackingSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        }

        func rebuildScene() {
            guard let root = studioRoot else { return }

            if lastFloor != sceneState.floorSize || currentMode != sceneState.mode {
                SceneEnvironment.updateFloor(root, size: sceneState.floorSize, showGuides: sceneState.mode == .edit)
                lastFloor = sceneState.floorSize
            }
            guard lastHumans != sceneState.humans else { return }
            lastHumans = sceneState.humans

            SceneContentBuilder.syncHumans(
                placements: sceneState.humans,
                selectedID: nil,
                into: root
            )
        }

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let deviceTransform = frame.camera.transform
            let trackingMessage: String
            switch frame.camera.trackingState {
            case .normal: trackingMessage = "Tracking ready"
            case .notAvailable: trackingMessage = "Tracking unavailable"
            case .limited: trackingMessage = "Move slowly in a well-lit room with visible detail"
            }
            Task { @MainActor in
                if self.sceneState.trackingStatus != trackingMessage { self.sceneState.trackingStatus = trackingMessage }
                if self.latestDevice == nil { self.referenceTransform = deviceTransform }
                self.latestDevice = deviceTransform
            }
        }

        @MainActor
        private func applyDeviceMotion(_ deviceTransform: simd_float4x4, dt: Float) {
            if lastMovementScale != sceneState.movementScale {
                editCameraTransform = cameraEntity?.transform.matrix ?? editCameraTransform
                referenceTransform = deviceTransform; virtualOffset = .zero
                lastMovementScale = sceneState.movementScale
            }
            if let manual = cameraController.pendingManualPose {
                editCameraTransform = manual; referenceTransform = deviceTransform; virtualOffset = .zero; filteredPose = nil
                cameraController.pendingManualPose = nil
            }
            // Return-to-lock: rebase onto the locked pose at the current physical
            // position so the camera snaps back to the locked spot.
            if cameraController.pendingRecenter, let locked = cameraController.lockedTransform {
                editCameraTransform = locked; virtualOffset = .zero; filteredPose = nil
                referenceTransform = deviceTransform
                cameraController.pendingRecenter = false
            }

            // Shoulder placement: jump to the center point at ~1.5 m, keeping the
            // phone's current orientation (tilt + heading), then track from there.
            if cameraController.pendingShoulderPlacement {
                var placed = deviceTransform
                placed.columns.3 = SIMD4<Float>(
                    cameraController.target.x,
                    OrbitCameraController.shoulderHeight,
                    cameraController.target.z,
                    1
                )
                editCameraTransform = placed; virtualOffset = .zero; filteredPose = nil
                referenceTransform = deviceTransform
                cameraController.pendingShoulderPlacement = false
            }

            if referenceTransform == nil {
                referenceTransform = deviceTransform
            }
            guard let reference = referenceTransform, let camera = cameraEntity else { return }

            if cameraController.isViewLocked, let locked = cameraController.lockedTransform {
                camera.transform = Transform(matrix: locked)
                editCameraTransform = locked; referenceTransform = deviceTransform
                cameraController.liveCameraTransform = locked
                virtualOffset = .zero; filteredPose = Transform(matrix: locked); return
            }
            let edit = editCameraTransform

            // Orientation: start at the edit-mode look direction, then apply the
            // device's rotation since Camera mode began (free look-around).
            let deltaRotation = simd_quatf(rotation(reference).transpose * rotation(deviceTransform))
            let newRotation = simd_quatf(rotation(edit)) * deltaRotation

            // Position: apply the device's *world-space* displacement so vertical
            // stays vertical and horizontal stays horizontal — height no longer
            // couples with distance. Yaw-align it so physical "forward" still
            // heads toward the scene from the edit-mode viewpoint.
            let worldDelta = translation(deviceTransform) - translation(reference)
            let yawAlign = simd_quatf(angle: yaw(of: edit) - yaw(of: reference), axis: [0, 1, 0])
            let input = cameraController.movementInput
            let heading = OrbitCameraController.angles(camera.transform.matrix).y
            let right = SIMD3<Float>(cos(heading), 0, -sin(heading))
            let forward = SIMD3<Float>(-sin(heading), 0, -cos(heading))
            virtualOffset += (right * input.x + SIMD3<Float>(0,input.y,0) + forward * input.z) * dt * sceneState.movementScale
            let newPosition = translation(edit) + yawAlign.act(worldDelta) * sceneState.movementScale + virtualOffset

            let target = Transform(scale: .one, rotation: newRotation, translation: newPosition)
            let alpha = CameraMotion.response(dt: dt, smoothing: sceneState.cameraSmoothing)
            var filtered = filteredPose ?? target
            filtered.translation += (target.translation - filtered.translation) * alpha
            filtered.rotation = simd_slerp(filtered.rotation, target.rotation, alpha)
            camera.transform = Transform(matrix: cameraController.constrained(filtered.matrix))
            filteredPose = camera.transform
            cameraController.liveCameraTransform = camera.transform.matrix

        }

        private func streamPreview() {
            let now = Date.timeIntervalSinceReferenceDate
            guard !recorder.isRecording, sceneState.mode == .camera, sceneState.desktopLink.isConnected, !previewBusy, now-lastPreview >= 0.15, let arView else { return }
            previewBusy = true; lastPreview = now
            arView.snapshot(saveToHDR: false) { [weak self] image in
                Task { @MainActor in
                    guard let self else { return }; self.previewBusy = false
                    if let image { self.sceneState.desktopLink.sendPreview(image, recording: self.sceneState.isRecording) }
                }
            }
        }
        private func syncRecording() {
            guard let arView else { return }
            if sceneState.isRecording, !recorder.isRecording {
                recorder.start(arView: arView)
            } else if !sceneState.isRecording, recorder.isRecording {
                recorder.stop()
            }
        }

        func shutdown() {
            displayLink?.invalidate(); displayLink = nil
            trackingSession.delegate = nil; trackingSession.pause()
            cameraController.movementInput = .zero
        }

        @objc private func tick(_ link: CADisplayLink) {
            let dt = Float(min(max(link.timestamp - lastTick, 0.001), 0.05)); lastTick = link.timestamp
            if sceneState.trackingSuspended {
                syncRecording()
                if !trackingPaused { trackingSession.pause(); trackingPaused = true }
                return
            }
            if trackingPaused {
                trackingPaused = false
                if trackingStarted { trackingSession.run(ARWorldTrackingConfiguration()) }
                referenceTransform = nil; latestDevice = nil
                editCameraTransform = cameraEntity?.transform.matrix ?? editCameraTransform
                virtualOffset = .zero; filteredPose = nil
            }
            if currentMode != sceneState.mode {
                if sceneState.mode == .camera {
                    editCameraTransform = cameraController.worldTransform
                    referenceTransform = latestDevice; virtualOffset = .zero; filteredPose = nil
                    cameraController.pendingManualPose = nil
                    lastMovementScale = sceneState.movementScale
                    startTracking()
                } else if currentMode == .camera, let live = cameraController.liveCameraTransform {
                    cameraController.setManualPose(live)
                }
                if let root = studioRoot { SceneEnvironment.updateFloor(root, size: sceneState.floorSize, showGuides: sceneState.mode == .edit) }
                currentMode = sceneState.mode
                cameraController.movementInput = .zero
            }
            if sceneState.mode == .camera {
                applyDeviceMotion(latestDevice ?? matrix_identity_float4x4, dt: dt)
            } else {
                cameraController.updateCameraTransform()
            }
            applyLens(dt: dt)
            syncRecording(); streamPreview()
        }

        private func applyLens(dt: Float) {
            guard let camera = cameraEntity else { return }
            let desired = sceneState.focalLength.rawValue * sceneState.zoomMultiplier
            displayedLens = CameraMotion.smoothLens(current: displayedLens, target: desired, dt: dt)
            var component = camera.components[PerspectiveCameraComponent.self] ?? PerspectiveCameraComponent()
            component.fieldOfViewInDegrees = 2 * atan(36 / (2 * displayedLens)) * 180 / .pi
            camera.components.set(component)
        }

        @objc private func tap(_ gesture: UITapGestureRecognizer) {
            guard sceneState.mode == .edit, let arView else { return }
            var entity = arView.entity(at: gesture.location(in: arView))
            while let candidate = entity {
                if let tag = candidate.components[HumanTagComponent.self] { sceneState.selectHuman(id: tag.id); return }
                entity = candidate.parent
            }
            sceneState.selectHuman(id: nil)
        }
        @objc private func pan(_ gesture: UIPanGestureRecognizer) {
            guard sceneState.mode == .edit, let arView else { return }
            let delta = gesture.translation(in: arView)
            if gesture.state == .began { dragStart = sceneState.selectedHuman?.position }
            if let start = dragStart, let id = sceneState.selectedHumanID {
                let a = cameraController.azimuth, scale = cameraController.distance * 0.0012
                let offset = SIMD3<Float>(cos(a),0,-sin(a)) * Float(delta.x) * scale + SIMD3<Float>(sin(a),0,cos(a)) * Float(delta.y) * scale
                sceneState.updateHumanPosition(id: id, position: start + offset)
            } else {
                cameraController.orbit(deltaAzimuth: Float(delta.x)*0.005*sceneState.touchSensitivity, deltaElevation: -Float(delta.y)*0.005*sceneState.touchSensitivity)
                gesture.setTranslation(.zero, in: arView)
            }
            if gesture.state == .ended || gesture.state == .cancelled { dragStart = nil }
        }
        @objc private func pinch(_ gesture: UIPinchGestureRecognizer) {
            guard !cameraController.lensLocked else { return }
            if gesture.state == .began { pinchStart = sceneState.zoomMultiplier }
            sceneState.zoomMultiplier = min(max(pinchStart * Float(gesture.scale), 0.5), 4)
        }

        private func rotation(_ m: simd_float4x4) -> simd_float3x3 {
            simd_float3x3(
                SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
            )
        }

        private func translation(_ m: simd_float4x4) -> SIMD3<Float> {
            SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        }

        /// Heading (rotation about world up) of a camera-to-world transform,
        /// derived from its forward (-Z) axis projected onto the ground plane.
        private func yaw(of m: simd_float4x4) -> Float {
            let forward = SIMD3<Float>(-m.columns.2.x, -m.columns.2.y, -m.columns.2.z)
            return atan2(forward.x, forward.z)
        }
    }
}
