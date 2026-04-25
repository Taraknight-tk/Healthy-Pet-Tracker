//
//  PhotoStorage.swift
//  Healthy Pet Tracker
//
//  Centralized read/write of user-saved photos (pet profile photos, weight
//  entry photos, note photos).
//
//  Why this exists: iOS app sandboxes are addressed by a UUID-based container
//  path (e.g. /var/mobile/Containers/Data/Application/<UUID>/Documents/...).
//  That UUID can change between installs/updates, so storing absolute paths
//  on a model object eventually leaves dead pointers — the JPEG is still on
//  disk under the *new* container, but the saved path points at the old one.
//  Apple explicitly warns against persisting absolute paths for this reason.
//
//  Fix: persist only the path *relative* to Documents/ (e.g. "pet_photos/
//  pet_<id>.jpg") and resolve it against the current Documents directory at
//  read time. Legacy absolute paths from older app versions are migrated
//  on the fly by `relativize`, so users keep their existing photos.
//

import Foundation
import UIKit

enum PhotoStorage {

    // MARK: - Subdirectories

    static let petPhotosDir   = "pet_photos"
    static let entryPhotosDir = "entry_photos"

    // MARK: - Resolution

    /// The app's Documents directory, resolved fresh each call (its absolute
    /// path can change between launches; subpaths under it are stable).
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Convert any stored path — legacy absolute or new relative — into a
    /// relative path rooted at Documents/. Returns nil only if the input is
    /// unparseable.
    ///
    /// - Legacy: `/var/.../Documents/pet_photos/foo.jpg` → `pet_photos/foo.jpg`
    /// - New:    `pet_photos/foo.jpg` → unchanged
    static func relativize(_ stored: String) -> String? {
        guard !stored.isEmpty else { return nil }
        if stored.hasPrefix("/") {
            if let range = stored.range(of: "/Documents/") {
                return String(stored[range.upperBound...])
            }
            // Fallback: take the trailing "<subdir>/<filename>" if shape matches.
            let parts = (stored as NSString).pathComponents
            if parts.count >= 2 {
                return parts.suffix(2).joined(separator: "/")
            }
            return nil
        }
        return stored
    }

    /// Resolve a stored path to an on-disk URL under the *current* Documents
    /// directory.
    static func absoluteURL(for storedPath: String) -> URL? {
        guard let rel = relativize(storedPath) else { return nil }
        return documentsURL.appendingPathComponent(rel)
    }

    // MARK: - Read

    static func loadImage(at storedPath: String) -> UIImage? {
        guard let url = absoluteURL(for: storedPath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func fileExists(at storedPath: String) -> Bool {
        guard let url = absoluteURL(for: storedPath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Write

    /// Write JPEG data to `Documents/<subdirectory>/<filename>` and return the
    /// **relative** path to persist on the model. Returns nil on write failure.
    @discardableResult
    static func saveJPEG(_ data: Data, subdirectory: String, filename: String) -> String? {
        let dir = documentsURL.appendingPathComponent(subdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return "\(subdirectory)/\(filename)"
        } catch {
            return nil
        }
    }

    // MARK: - Delete

    /// Delete the file referenced by a stored path. No-ops if the file is
    /// already gone or the path is unresolvable.
    static func delete(_ storedPath: String) {
        guard let url = absoluteURL(for: storedPath) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
