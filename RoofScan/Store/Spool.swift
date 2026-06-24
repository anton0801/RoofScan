import Foundation

protocol Spool {
    func commit(_ log: SweepLog)
    func markTile(url: String, mode: String)
    func raisePrimedFlag()
    func pull() -> SweepLog
}

final class ReelSpool: Spool {

    private let fm = FileManager.default
    private let vaultDir: URL
    private let homeStore: UserDefaults
    private let suiteStore: UserDefaults

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.vaultDir = docs.appendingPathComponent(Roof.surveyVault, isDirectory: true)
        if !fm.fileExists(atPath: vaultDir.path) {
            try? fm.createDirectory(at: vaultDir, withIntermediateDirectories: true)
        }
        self.homeStore = UserDefaults.standard
        self.suiteStore = UserDefaults(suiteName: Roof.suiteSurvey) ?? .standard
    }

    private var sweepURL: URL {
        vaultDir.appendingPathComponent(Roof.sweepFile)
    }

    func commit(_ log: SweepLog) {
        let blurred = BlurLog(
            capture: blurMap(log.capture),
            pins: blurMap(log.pins),
            tileURL: log.tileURL,
            tileMode: log.tileMode,
            grounded: log.grounded,
            passGranted: log.passGranted,
            passDenied: log.passDenied,
            passAt: log.passAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        do {
            let data = try encoder.encode(blurred)
            try data.write(to: sweepURL, options: .atomic)
        } catch {
            print("\(Roof.logCopter) Spool commit failed: \(error)")
        }

        for store in [suiteStore, homeStore] {
            store.set(log.passGranted, forKey: RoofKey.passGranted)
            store.set(log.passDenied, forKey: RoofKey.passDenied)
            if let date = log.passAt {
                store.set(date.timeIntervalSince1970, forKey: RoofKey.passAt)
            }
        }
    }

    func markTile(url: String, mode: String) {
        suiteStore.set(url, forKey: RoofKey.tileURL)
        homeStore.set(url, forKey: RoofKey.tileURL)
        suiteStore.set(mode, forKey: RoofKey.tileMode)
    }

    func raisePrimedFlag() {
        suiteStore.set(true, forKey: RoofKey.primed)
        homeStore.set(true, forKey: RoofKey.primed)
    }

    func pull() -> SweepLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if fm.fileExists(atPath: sweepURL.path),
           let data = try? Data(contentsOf: sweepURL),
           let blurred = try? decoder.decode(BlurLog.self, from: data) {
            return SweepLog(
                capture: sharpMap(blurred.capture),
                pins: sharpMap(blurred.pins),
                tileURL: blurred.tileURL,
                tileMode: blurred.tileMode,
                grounded: blurred.grounded,
                passGranted: blurred.passGranted,
                passDenied: blurred.passDenied,
                passAt: blurred.passAt
            )
        }

        return pullFromMirror()
    }

    private func pullFromMirror() -> SweepLog {
        let tileURL = homeStore.string(forKey: RoofKey.tileURL)
            ?? suiteStore.string(forKey: RoofKey.tileURL)
        let tileMode = suiteStore.string(forKey: RoofKey.tileMode)
        let primed = suiteStore.bool(forKey: RoofKey.primed)

        let granted = suiteStore.bool(forKey: RoofKey.passGranted)
            || homeStore.bool(forKey: RoofKey.passGranted)
        let denied = suiteStore.bool(forKey: RoofKey.passDenied)
            || homeStore.bool(forKey: RoofKey.passDenied)
        let atTs = suiteStore.double(forKey: RoofKey.passAt)
        let passAt: Date? = atTs > 0 ? Date(timeIntervalSince1970: atTs) : nil

        return SweepLog(
            capture: [:],
            pins: [:],
            tileURL: tileURL,
            tileMode: tileMode,
            grounded: !primed,
            passGranted: granted,
            passDenied: denied,
            passAt: passAt
        )
    }

    private func blurMap(_ dict: [String: String]) -> [String: String] {
        dict.reduce(into: [:]) { acc, pair in acc[pair.key] = blur(pair.value) }
    }

    private func sharpMap(_ dict: [String: String]) -> [String: String] {
        dict.reduce(into: [:]) { acc, pair in acc[pair.key] = sharp(pair.value) ?? pair.value }
    }

    private func blur(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "]")
            .replacingOccurrences(of: "/", with: "[")
    }

    private func sharp(_ input: String) -> String? {
        let restored = input
            .replacingOccurrences(of: "]", with: "+")
            .replacingOccurrences(of: "[", with: "/")
        guard let data = Data(base64Encoded: restored),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}

struct BlurLog: Codable {
    let capture: [String: String]
    let pins: [String: String]
    let tileURL: String?
    let tileMode: String?
    let grounded: Bool
    let passGranted: Bool
    let passDenied: Bool
    let passAt: Date?
}
