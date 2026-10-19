//
//  VirtualStudioView.swift
//  film space
//

import SwiftUI
import RealityKit

struct VirtualStudioView: View {
    @Bindable var sceneState: SceneState
    @Bindable var cameraController: OrbitCameraController

    @State private var studioRoot: Entity?
    @State private var lastMagnification: CGFloat = 1
    @State private var lastDragTranslation: CGSize = .zero
    @State private var dragStartPosition: SIMD3<Float>?

    var body: some View {
        // Read observable state here so SwiftUI tracks these as dependencies of
        // `body`; otherwise the RealityView `update:` closure won't re-run when
        // humans are added/removed/selected.
        let humans = sceneState.humans
        let selectedID = sceneState.selectedHumanID
        let floorSize = sceneState.floorSize
        let focalLength = sceneState.focalLength

        RealityView { content in
            content.add(cameraController.makeCameraEntity())

            let root = SceneEnvironment.makeStudioRoot()
            content.add(root)
            studioRoot = root

            if let camera = cameraController.cameraEntity {
                var lens = camera.components[PerspectiveCameraComponent.self] ?? PerspectiveCameraComponent()
                lens.fieldOfViewInDegrees = focalLength.horizontalFOVDegrees; camera.components.set(lens)
            }
            SceneEnvironment.updateFloor(root, size: floorSize, showGuides: true)
            SceneContentBuilder.syncHumans(
                placements: humans,
                selectedID: selectedID,
                into: root
            )
        } update: { _ in
            guard let root = studioRoot else { return }
            if let camera = cameraController.cameraEntity {
                var lens = camera.components[PerspectiveCameraComponent.self] ?? PerspectiveCameraComponent()
                lens.fieldOfViewInDegrees = focalLength.horizontalFOVDegrees; camera.components.set(lens)
            }
            SceneEnvironment.updateFloor(root, size: floorSize, showGuides: true)
            SceneContentBuilder.syncHumans(
                placements: humans,
                selectedID: selectedID,
                into: root
            )
        }
        .gesture(navigationDragGesture)
        .simultaneousGesture(zoomGesture)
        .highPriorityGesture(selectBodyGesture)
        .gesture(deselectGesture)
        .background(Color(SceneEnvironment.studioGrey))
    }

    private var navigationDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let delta = CGSize(
                    width: value.translation.width - lastDragTranslation.width,
                    height: value.translation.height - lastDragTranslation.height
                )
                lastDragTranslation = value.translation

                if let id = sceneState.selectedHumanID {
                    if dragStartPosition == nil {
                        dragStartPosition = sceneState.humans.first(where: { $0.id == id })?.position
                    }
                    guard let start = dragStartPosition else { return }

                    let moveScale = cameraController.distance * 0.0012
                    let azimuth = cameraController.azimuth
                    let right = SIMD3<Float>(cos(azimuth), 0, -sin(azimuth))
                    let forward = SIMD3<Float>(sin(azimuth), 0, cos(azimuth))

                    var offset = right * Float(value.translation.width) * moveScale
                    offset += forward * Float(value.translation.height) * moveScale

                    var newPosition = start + offset
                    newPosition.y = start.y
                    sceneState.updateHumanPosition(id: id, position: newPosition)
                } else {
                    let deltaAzimuth = Float(delta.width) * 0.005 * sceneState.touchSensitivity
                    let deltaElevation = Float(delta.height) * 0.005 * sceneState.touchSensitivity
                    cameraController.orbit(deltaAzimuth: deltaAzimuth, deltaElevation: -deltaElevation)
                }
            }
            .onEnded { _ in
                lastDragTranslation = .zero
                dragStartPosition = nil
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let delta = Float(scale / lastMagnification)
                cameraController.zoom(scale: delta)
                lastMagnification = scale
            }
            .onEnded { _ in
                lastMagnification = 1
            }
    }

    // Fires only when a body is tapped (entities have InputTargetComponent).
    // High priority so it wins over the deselect tap when an entity is hit.
    private var selectBodyGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if let tag = humanTag(for: value.entity) {
                    sceneState.selectHuman(id: tag.id)
                }
            }
    }

    // Fires when the tap doesn't hit a body (empty space, grid, axes), letting
    // you deselect and return to orbiting the canvas.
    private var deselectGesture: some Gesture {
        TapGesture()
            .onEnded {
                sceneState.selectHuman(id: nil)
            }
    }

    private func humanTag(for entity: Entity) -> HumanTagComponent? {
        var current: Entity? = entity
        while let node = current {
            if let tag = node.components[HumanTagComponent.self] {
                return tag
            }
            current = node.parent
        }
        return nil
    }
}
