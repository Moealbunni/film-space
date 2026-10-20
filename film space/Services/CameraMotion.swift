import Foundation

enum CameraMotion {
    static func response(dt: Float, smoothing: Float) -> Float {
        if smoothing <= 0 { return 1 }
        return 1 - exp(-max(0, dt) / (0.02 + min(smoothing, 1) * 0.3))
    }
    static func smoothLens(current: Float, target: Float, dt: Float) -> Float {
        // Interpolate logarithmically for an even-feeling zoom across lens ranges.
        let a = 1 - exp(-max(0, dt) / 0.16)
        return exp(log(max(current, 1)) + (log(max(target, 1)) - log(max(current, 1))) * a)
    }
}
