//
//  PersistenceService.swift
//  RoofScan
//
//  Loads/saves the RoofProject as JSON in the app's Documents directory.
//  Atomic writes; decode failures fall back to an empty project (never crash).
//

import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let fileName = "roof_project.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var fileURL: URL { documentsURL.appendingPathComponent(fileName) }

    func load() -> RoofProject {
        guard let data = try? Data(contentsOf: fileURL),
              let project = try? decoder.decode(RoofProject.self, from: data) else {
            return .empty
        }
        return project
    }

    func save(_ project: RoofProject) {
        guard let data = try? encoder.encode(project) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// A share-ready copy of the raw JSON (for "Export Data").
    func exportDataURL(_ project: RoofProject) -> URL? {
        guard let data = try? encoder.encode(project) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoofScan-Export.json")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    /// Timestamped backup snapshot in Documents/Backups.
    @discardableResult
    func backup(_ project: RoofProject, stamp: String) -> URL? {
        guard let data = try? encoder.encode(project) else { return nil }
        let dir = documentsURL.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("backup-\(stamp).json")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }
}
