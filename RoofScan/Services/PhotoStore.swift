//
//  PhotoStore.swift
//  RoofScan
//
//  Saves photos as JPEG files in Documents/Photos and returns filenames.
//  Only filenames live in the model — keeps the JSON small.
//

import UIKit

final class PhotoStore {
    static let shared = PhotoStore()
    private init() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private var dir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
    }

    func url(for filename: String) -> URL { dir.appendingPathComponent(filename) }

    /// Persist an image; returns its generated filename, or nil on failure.
    @discardableResult
    func save(_ image: UIImage) -> String? {
        let resized = image.rs_resized(maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "photo-\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(for: filename), options: .atomic)
            return filename
        } catch { return nil }
    }

    func load(_ filename: String?) -> UIImage? {
        guard let filename = filename else { return nil }
        return UIImage(contentsOfFile: url(for: filename).path)
    }

    func delete(_ filename: String?) {
        guard let filename = filename else { return }
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    /// Remove orphaned photo files no longer referenced by the model.
    func garbageCollect(referenced: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for file in files where !referenced.contains(file) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }
}

extension UIImage {
    /// Downscale so the longest edge ≤ maxDimension (keeps storage small).
    func rs_resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
