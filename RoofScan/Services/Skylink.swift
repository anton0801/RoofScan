import Foundation
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging
import WebKit

protocol Skylink {
    func relay(payload: [String: Any]) async throws -> String
}

struct Backoff: AsyncSequence {
    typealias Element = Double
    let gaps: [Double]

    func makeAsyncIterator() -> Iterator {
        Iterator(gaps: gaps)
    }

    struct Iterator: AsyncIteratorProtocol {
        let gaps: [Double]
        var cursor = 0

        mutating func next() async -> Double? {
            guard cursor < gaps.count else { return nil }
            defer { cursor += 1 }
            return gaps[cursor]
        }
    }
}

final class SatSkylink: Skylink {

    private let session: URLSession
    private let spans: [Double] = [81.0, 162.0, 324.0]
    private let agent: String = WKWebView().value(forKey: "userAgent") as? String ?? ""

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func relay(payload: [String: Any]) async throws -> String {
        let request = try pack(payload)

        var carried: Error = Smear.faded(stage: "skylink")
        var made = 0
        let cap = spans.count
        var beats = Backoff(gaps: spans).makeAsyncIterator()

        while made < cap {
            do {
                return try await tap(request)
            } catch let smear as Smear {
                if smear.isSealed { throw smear }
                carried = smear
                made += 1
                if made >= cap { throw smear }
                if case .clouded(let cool) = smear {
                    try await pause(cool)
                } else if let gap = await beats.next() {
                    try await pause(gap)
                }
            } catch {
                carried = error
                made += 1
                if made >= cap { break }
                if let gap = await beats.next() { try await pause(gap) }
            }
        }

        throw carried
    }

    private func pack(_ payload: [String: Any]) throws -> URLRequest {
        guard let endpoint = URL(string: Roof.skyEndpoint) else {
            throw Smear.skewed(at: "skylink.url")
        }

        var body = payload
        body["os"] = "iOS"
        body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        body["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        body["store_id"] = "id\(Roof.appCode)"
        body["push_token"] = UserDefaults.standard.string(forKey: RoofKey.push)
            ?? Messaging.messaging().fcmToken
        body["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func tap(_ request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw Smear.faded(stage: "tap.response")
        }

        switch http.statusCode {
        case 404:
            throw Smear.gridLocked(httpCode: 404)
        case 429:
            let cool = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw Smear.clouded(cooldown: cool)
        case 200...299:
            break
        default:
            throw Smear.faded(stage: "tap.status")
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cleared = root["ok"] as? Bool else {
            throw Smear.smudged(at: "tap.body")
        }
        guard cleared else {
            throw Smear.surveyDenied(reason: "okFalse")
        }
        guard let tile = root["url"] as? String, !tile.isEmpty else {
            throw Smear.smudged(at: "tap.url")
        }
        return tile
    }

    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
