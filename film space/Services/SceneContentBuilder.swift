import Foundation
import RealityKit
import UIKit

enum SceneContentBuilder {
    private static var templates: [ObjectKind: Entity] = [:]
    static func syncHumans(placements: [HumanPlacement], selectedID: UUID?, into root: Entity) {
        let existing = Dictionary(uniqueKeysWithValues: root.children.compactMap { child -> (UUID, Entity)? in
            guard let tag = child.components[HumanTagComponent.self] else { return nil }
            return (tag.id, child)
        })
        let ids = Set(placements.map(\.id))
        for (id, entity) in existing where !ids.contains(id) { entity.removeFromParent() }
        for p in placements {
            let signature = p.kind.rawValue
            var entity = existing[p.id]
            if entity?.components[ObjectAppearanceComponent.self]?.signature != signature {
                entity?.removeFromParent()
                entity = makeObject(p)
                entity!.components.set(HumanTagComponent(id: p.id))
                entity!.components.set(ObjectAppearanceComponent(signature: signature))
                root.addChild(entity!)
            }
            if let entity, entity.components[ObjectColorComponent.self]?.hex != p.colorHex {
                paint(entity, hex: p.colorHex)
                entity.components.set(ObjectColorComponent(hex: p.colorHex))
            }
            entity?.position = p.position
            entity?.orientation = simd_quatf(angle: p.rotationY, axis: [0,1,0]) * simd_quatf(angle: p.rotationX, axis: [1,0,0]) * simd_quatf(angle: p.rotationZ, axis: [0,0,1])
            entity?.scale = p.scale
        }
    }
    static func color(_ hex: String) -> UIColor {
        let value = UInt32(hex, radix: 16) ?? 0x596173
        return UIColor(red: CGFloat((value >> 16) & 255)/255, green: CGFloat((value >> 8) & 255)/255, blue: CGFloat(value & 255)/255, alpha: 1)
    }
    private static func paint(_ entity: Entity, hex: String) {
        if entity.name != "Rubber", let model = entity as? ModelEntity {
            model.model?.materials = [SimpleMaterial(color: color(hex), roughness: 0.7, isMetallic: false)]
        }
        for child in entity.children { paint(child, hex: hex) }
    }
    static func makeObject(_ p: HumanPlacement) -> Entity {
        if let template = templates[p.kind] {
            let copy = template.clone(recursive: true); paint(copy, hex: p.colorHex); return copy
        }
        let material = SimpleMaterial(color: color(p.colorHex), roughness: 0.7, isMetallic: false)
        let root: Entity
        if p.kind == .person || p.kind == .child {
            root = HumanFigureFactory.makeHumanFigure(isSelected: false)
            func paint(_ entity: Entity) {
                if let model = entity as? ModelEntity { model.model?.materials = [material] }
                for child in entity.children { paint(child) }
            }
            paint(root)
        } else {
            root = Entity()
            func part(_ mesh: MeshResource, _ position: SIMD3<Float>, _ mat: SimpleMaterial? = nil) -> ModelEntity {
                let e = ModelEntity(mesh: mesh, materials: [mat ?? material]); e.position = position
                root.addChild(e); return e
            }
            func box(_ size: SIMD3<Float>, _ pos: SIMD3<Float>) { _ = part(.generateBox(size: size), pos) }
            switch p.kind {
            case .car:
                box([1.8,0.65,3.6], [0,0.65,0]); box([1.5,0.7,1.8], [0,1.3,-0.15])
                let rubber = SimpleMaterial(color: .darkGray, roughness: 1, isMetallic: false)
                for x in [Float(-0.92), Float(0.92)] { for z in [Float(-1.1), Float(1.1)] {
                    let wheel = part(.generateCylinder(height: 0.22, radius: 0.38), [x,0.38,z], rubber)
                    wheel.orientation = simd_quatf(angle: .pi/2, axis: [0,0,1]); wheel.name = "Rubber"
                }}
            case .bike:
                for z in [Float(-0.7), Float(0.7)] {
                    let wheel = part(.generateCylinder(height: 0.08, radius: 0.38), [0,0.44,z])
                    wheel.orientation = simd_quatf(angle: .pi/2, axis: [0,0,1])
                }
                box([0.12,0.1,1.4],[0,0.65,0]); box([0.12,0.7,0.12],[0,0.9,0.7])
                box([0.7,0.08,0.1],[0,1.25,0.7]); box([0.35,0.08,0.35],[0,1,-0.3]); box([0.08,0.5,0.08],[0,0.75,-0.3])
            case .sphere: _ = part(.generateSphere(radius: 0.5), [0,0.5,0])
            case .wall: box([4,2.5,0.2],[0,1.25,0])
            case .plane: box([3,0.05,3],[0,0.025,0])
            case .circle: _ = part(.generateCylinder(height: 0.04, radius: 0.5), [0,0.02,0])
            case .cylinder: _ = part(.generateCylinder(height: 1, radius: 0.5), [0,0.5,0])
            case .cone: _ = part(.generateCone(height: 1, radius: 0.5), [0,0.5,0])
            case .torus:
                // A ring assembled from small rounded segments; no external model assets.
                let segment = MeshResource.generateSphere(radius: 0.16)
                for i in 0..<24 { let a = Float(i) * 2 * .pi / 24
                    _ = part(segment, [cos(a)*0.5,0.66+sin(a)*0.5,0])
                }
            default: box([1,1,1],[0,0.5,0])
            }
        }
        if p.kind != .person && p.kind != .child {
            let bounds = root.visualBounds(relativeTo: root)
            let shape = ShapeResource.generateBox(size: simd_max(bounds.extents, SIMD3<Float>(repeating: 0.05))).offsetBy(translation: bounds.center)
            root.components.set(CollisionComponent(shapes: [shape]))
            root.components.set(InputTargetComponent())
        }
        root.name = "HumanFigure"
        templates[p.kind] = root.clone(recursive: true)
        return root
    }
}
struct HumanTagComponent: Component { var id: UUID }
struct HumanSelectionComponent: Component { var isSelected: Bool }
struct ObjectAppearanceComponent: Component { var signature: String }

struct ObjectColorComponent: Component { var hex: String }
