//
//  SceneEnvironment.swift
//  film space
//

import RealityKit
import UIKit

enum SceneEnvironment {
    static let studioGrey = UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1)
    static let gridLineColor = UIColor(red: 0.32, green: 0.32, blue: 0.32, alpha: 1)
    static let axisXColor = UIColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1)
    static let axisYColor = UIColor(red: 0.35, green: 0.75, blue: 0.35, alpha: 1)
    static let axisZColor = UIColor(red: 0.30, green: 0.45, blue: 0.90, alpha: 1)

    static func makeStudioRoot() -> Entity {
        let root = Entity()
        root.name = "StudioRoot"

        let ground = Entity(); ground.name = "Ground"
        addCheckerboard(to: ground); root.addChild(ground)
        let guides = Entity(); guides.name = "Guides"
        addGrid(to: guides); addAxes(to: guides); root.addChild(guides)
        addLighting(to: root)

        return root
    }

    static func updateFloor(_ root: Entity, size: Float, showGuides: Bool) {
        root.findEntity(named: "Ground")?.scale = [size/20, 1, size/20]
        root.findEntity(named: "Guides")?.scale = [size/20, 1, size/20]
        root.findEntity(named: "Guides")?.isEnabled = showGuides
    }

    private static func addCheckerboard(to root: Entity) {
        let gridSize: Float = 10
        let divisions = 20
        let step = (gridSize * 2) / Float(divisions)

        // One mesh replaces 200 separate checker tile entities/draw submissions.
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for i in 0..<divisions {
            for j in 0..<divisions where (i + j) % 2 == 0 {
                let x = -gridSize + Float(i) * step
                let z = -gridSize + Float(j) * step
                let n = UInt32(positions.count)
                positions += [[x,0,z], [x+step,0,z], [x+step,0,z+step], [x,0,z+step]]
                indices += [n,n+2,n+1,n,n+3,n+2]
            }
        }
        var descriptor = MeshDescriptor(name: "Checkerboard")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(Array(repeating: SIMD3<Float>(0,1,0), count: positions.count))
        descriptor.primitives = .triangles(indices)
        if let mesh = try? MeshResource.generate(from: [descriptor]) {
            let material = SimpleMaterial(color: UIColor(white: 0.34, alpha: 1), roughness: 1, isMetallic: false)
            root.addChild(ModelEntity(mesh: mesh, materials: [material]))
        }
    }

    private static func addGrid(to root: Entity) {
        let gridSize: Float = 10
        let divisions = 20
        let step = (gridSize * 2) / Float(divisions)
        let lineMaterial = UnlitMaterial(color: gridLineColor)

        for i in 0...divisions {
            let offset = -gridSize + Float(i) * step
            addLine(to: root, from: [offset, 0.001, -gridSize], to: [offset, 0.001, gridSize], material: lineMaterial)
            addLine(to: root, from: [-gridSize, 0.001, offset], to: [gridSize, 0.001, offset], material: lineMaterial)
        }
    }

    private static func addAxes(to root: Entity) {
        let length: Float = 1.2
        let thickness: Float = 0.012

        addLine(to: root, from: .zero, to: [length, 0, 0], material: UnlitMaterial(color: axisXColor), thickness: thickness)
        addLine(to: root, from: .zero, to: [0, length, 0], material: UnlitMaterial(color: axisYColor), thickness: thickness)
        addLine(to: root, from: .zero, to: [0, 0, length], material: UnlitMaterial(color: axisZColor), thickness: thickness)
    }

    private static func addLighting(to root: Entity) {
        let keyLight = Entity()
        keyLight.components.set(DirectionalLightComponent(color: .white, intensity: 1200, isRealWorldProxy: false))
        keyLight.look(at: .zero, from: [4, 6, 4], relativeTo: nil)
        root.addChild(keyLight)

        let fillLight = Entity()
        fillLight.components.set(DirectionalLightComponent(color: .white, intensity: 400, isRealWorldProxy: false))
        fillLight.look(at: .zero, from: [-3, 2, -2], relativeTo: nil)
        root.addChild(fillLight)
    }

    private static func addLine(
        to parent: Entity,
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        material: Material,
        thickness: Float = 0.004
    ) {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.0001 else { return }

        let line = ModelEntity(mesh: .generateBox(size: [thickness, thickness, length]), materials: [material])
        line.position = (start + end) / 2
        line.look(at: end, from: start, relativeTo: parent)
        parent.addChild(line)
    }
}
