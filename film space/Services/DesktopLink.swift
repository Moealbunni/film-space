import SwiftUI
import RealityKit
import UIKit

struct LinkedObject: Codable {
    var type: ObjectKind
    var name: String
    var color: String
    var position: [Float]
    var rotation: [Float]
    var scale: [Float]
}
struct LinkedScene: Codable {
    var format = "film-space-link-v1"
    var objects: [LinkedObject]
    var floorSize: Float
    var lens: Float
    init(state: SceneState) {
        objects = state.humans.map { LinkedObject(type: $0.kind, name: $0.name, color: "#" + $0.colorHex, position: [$0.position.x,$0.position.y,$0.position.z], rotation: [$0.rotationX,$0.rotationY,$0.rotationZ], scale: [$0.scale.x,$0.scale.y,$0.scale.z]) }
        floorSize = state.floorSize; lens = state.focalLength.rawValue
    }
    func apply(to state: SceneState) throws {
        func vector(_ v: [Float]) -> Bool { v.count == 3 && v.allSatisfy { $0.isFinite && abs($0) <= 1000 } }
        guard format == "film-space-link-v1", objects.count <= 200, floorSize.isFinite, (2...200).contains(floorSize), [Float(18),24,35,50,75,200].contains(lens), objects.allSatisfy({ o in
            vector(o.position) && vector(o.rotation) && vector(o.scale) && o.scale.allSatisfy { (0.01...100).contains($0) } && o.name.count <= 200 && o.color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
        }) else { throw LinkError.invalidScene }
        state.humans = objects.map { o in
            var p = HumanPlacement(position: [o.position[0],o.position[1],o.position[2]], rotationY: o.rotation[1])
            p.kind = o.type; p.name = o.name; p.colorHex = String(o.color.dropFirst())
            p.rotationX = o.rotation[0]; p.rotationZ = o.rotation[2]; p.scale = [o.scale[0],o.scale[1],o.scale[2]]
            return p
        }
        state.floorSize = floorSize; state.focalLength = FocalLength(rawValue: lens) ?? .mm35
        state.selectedHumanID = state.humans.first?.id
    }
}
enum LinkError: LocalizedError {
    case invalidPair, invalidScene, response(Int)
    var errorDescription: String? {
        switch self {
        case .invalidPair: return "Scan the QR shown by Film Space on your Windows PC."
        case .invalidScene: return "This scene contains unsupported or invalid values."
        case .response(let code): return code == 404 ? "Prepare a scene on Windows first." : code == 401 ? "Pairing expired. Scan a new desktop QR." : "Desktop returned error \(code)."
        }
    }
}
private final class LocalRedirectGuard: NSObject, URLSessionTaskDelegate {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
@Observable @MainActor
final class DesktopLink {
    var isConnected = false
    var message = "Not connected"
    var previewStatus = "No preview sent yet"
    private var base: URL?
    private var token = ""
    private var generation = UUID()
    private var heartbeat: Task<Void, Never>?
    private var sending = false
    private var lastFrame: TimeInterval = 0
    private let redirectGuard = LocalRedirectGuard()
    @ObservationIgnored private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config, delegate: redirectGuard, delegateQueue: nil)
    }()
    static func parsePair(_ text: String) throws -> (URL, String) {
        guard let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), parts.scheme == "filmspace", parts.host == "pair" else { throw LinkError.invalidPair }
        let items = parts.queryItems ?? []
        guard let host = items.first(where: {$0.name == "host"})?.value,
              let portText = items.first(where: {$0.name == "port"})?.value, let port = Int(portText), (1024...65535).contains(port),
              let token = items.first(where: {$0.name == "token"})?.value, token.range(of: "^[0-9a-f]{48}$", options: .regularExpression) != nil else { throw LinkError.invalidPair }
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        let octets = components.compactMap { Int($0) }
        guard components.count == 4, octets.count == 4, components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }), octets.allSatisfy({(0...255).contains($0)}),
              octets[0] == 10 || (octets[0] == 192 && octets[1] == 168) || (octets[0] == 172 && (16...31).contains(octets[1])) || (octets[0] == 169 && octets[1] == 254) else { throw LinkError.invalidPair }
        guard let url = URL(string: "http://\(host):\(port)") else { throw LinkError.invalidPair }
        return (url, token)
    }
    func connect(_ text: String) async {
        disconnect()
        let attempt = generation
        do {
            let pair = try Self.parsePair(text); base = pair.0; token = pair.1
            _ = try await request("status")
            guard generation == attempt else { return }
            isConnected = true; message = "Connected to desktop"
            heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    do { _ = try await self.request("status"); if !Task.isCancelled { if !self.isConnected { self.message = "Connected to desktop" }; self.isConnected = true } }
                    catch { guard !Task.isCancelled else { return }; self.isConnected = false; self.message = "Connection lost. Check Wi-Fi or scan a new QR. Connection retries automatically." }
                }
            }
        } catch { if generation == attempt { message = error.localizedDescription; base = nil; token = "" } }
    }
    func disconnect() { generation = UUID(); heartbeat?.cancel(); heartbeat = nil; base = nil; token = ""; isConnected = false; message = "Disconnected"; previewStatus = "No preview sent yet" }
    private func request(_ path: String, data: Data? = nil, type: String = "application/json", recording: Bool = false) async throws -> Data {
        guard let base else { throw LinkError.invalidPair }
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let data { req.httpMethod = "POST"; req.httpBody = data; req.setValue(type, forHTTPHeaderField: "Content-Type") }
        req.setValue(recording ? "1" : "0", forHTTPHeaderField: "X-Film-Recording")
        let (result, response) = try await session.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw LinkError.response(code) }
        return result
    }
    func loadScene(into state: SceneState) async {
        guard !state.isRecording else { message = "Stop recording before loading a scene."; return }
        do {
            let data = try await request("scene")
            let linked = try JSONDecoder().decode(LinkedScene.self, from: data)
            try linked.apply(to: state); state.mode = .edit
            message = "Desktop scene loaded. Save it locally if you want to keep it."
        } catch { message = error.localizedDescription }
    }
    func sendScene(_ state: SceneState) async {
        do { let data = try JSONEncoder().encode(LinkedScene(state: state)); _ = try await request("phone-scene", data: data); message = "Sent. On Windows tap Load received phone scene." }
        catch { message = error.localizedDescription }
    }
    func showMonitor() async {
        do { _ = try await request("monitor", data: Data()); message = "Windows live monitor opened" }
        catch { message = "On Windows press Live Monitor (update Windows to 0.4.2 for remote opening)." }
    }
    func sendPreview(_ image: UIImage, recording: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        guard isConnected, !sending, now-lastFrame >= 0.12 else { return }
        lastFrame = now; sending = true
        let ratio = min(1, 640 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let reduced = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = reduced.jpegData(compressionQuality: 0.6) else { sending = false; return }
        let attempt = generation
        Task {
            defer { sending = false }
            do {
                _ = try await request("frame", data: jpeg, type: "image/jpeg", recording: recording)
                if generation == attempt, previewStatus != "Preview is reaching Windows" { previewStatus = "Preview is reaching Windows" }
            }
            catch { if generation == attempt { previewStatus = "Preview upload failed: " + error.localizedDescription } }
        }
    }
}
