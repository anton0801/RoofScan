import Foundation

protocol Lidar {
    func ping(deviceID: String) async throws -> [String: Any]
}

final class PulsedLidar: Lidar {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func ping(deviceID: String) async throws -> [String: Any] {
        let request = try aim(deviceID)

        let blob: Data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let task = session.downloadTask(with: request) { location, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let location = location else {
                    continuation.resume(throwing: Smear.faded(stage: "lidar.http"))
                    return
                }
                do {
                    let data = try Data(contentsOf: location)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }

        guard let json = try JSONSerialization.jsonObject(with: blob) as? [String: Any] else {
            throw Smear.smudged(at: "lidar.json")
        }
        return json
    }

    private func aim(_ deviceID: String) throws -> URLRequest {
        var comps = URLComponents(string: "https://gcdsdk.appsflyer.com/install_data/v4.0/id\(Roof.appCode)")
        comps?.queryItems = [
            URLQueryItem(name: "devkey", value: Roof.lidarKey),
            URLQueryItem(name: "device_id", value: deviceID)
        ]
        guard let url = comps?.url else {
            throw Smear.skewed(at: "lidar.url")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
