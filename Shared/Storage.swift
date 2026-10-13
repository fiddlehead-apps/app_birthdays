import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// The data file and contact photos in the App Group container, shared with the widgets.
nonisolated enum Storage {
    static let appGroup = "group.org.christophschneider.birthdays"

    static var folder: URL {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.applicationSupportDirectory  // unsigned simulator builds have no App Group
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var dataURL: URL { folder.appending(path: "birthdays.json") }

    static var photosFolder: URL {
        let url = folder.appending(path: "Photos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func load() -> AppData {
        guard let raw = try? Data(contentsOf: dataURL) else { return AppData() }
        return (try? decoder.decode(AppData.self, from: raw)) ?? AppData()
    }

    static func save(_ data: AppData) throws {
        try encoder.encode(data).write(to: dataURL, options: .atomic)
    }

    // MARK: Photos

    static func photoURL(_ id: UUID) -> URL { photosFolder.appending(path: "\(id.uuidString).jpg") }

    /// Stores a contact photo as a small JPEG. Returns whether there is a photo now.
    @discardableResult
    static func savePhoto(_ data: Data?, for id: UUID) -> Bool {
        guard let data, let jpeg = thumbnail(data, maxPixels: 300) else {
            removePhoto(id)
            return false
        }
        return (try? jpeg.write(to: photoURL(id), options: .atomic)) != nil
    }

    static func removePhoto(_ id: UUID) {
        try? FileManager.default.removeItem(at: photoURL(id))
    }

    static func photo(_ id: UUID) -> UIImage? {
        UIImage(contentsOfFile: photoURL(id).path(percentEncoded: false))
    }

    private static func thumbnail(_ data: Data, maxPixels: Int) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

/// Opens a birthday from a widget or notification: klarbirthdays://birthday/<id>
nonisolated enum DeepLink {
    static let scheme = "klarbirthdays"

    static func url(_ id: UUID) -> URL { URL(string: "\(scheme)://birthday/\(id.uuidString)")! }

    static func id(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host() == "birthday" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
