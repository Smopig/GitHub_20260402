import Foundation
import SSZipArchive

/// File compression and decompression.
/// - Plain ZIP via NSFileCoordinator (no dependencies)
/// - Encrypted ZIP via ZipArchive (AES-256)
public enum ArchiveManager {

    public enum ArchiveError: LocalizedError {
        case sourceMissing(URL)
        case compressionFailed
        case encryptionFailed

        public var errorDescription: String? {
            switch self {
            case .sourceMissing(let u): return "Source not found: \(u.lastPathComponent)"
            case .compressionFailed: return "Compression failed"
            case .encryptionFailed: return "Encrypted compression failed"
            }
        }
    }

    // MARK: - Plain ZIP

    /// Creates a plain ZIP archive of `sources` at `destination`.
    public static func zip(sources: [URL], destination: URL) throws {
        guard !sources.isEmpty else { throw ArchiveError.compressionFailed }

        // Use NSFileCoordinator + NSFileManager for Finder-safe reading
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()

        if sources.count == 1 {
            // For a single item, use the "for uploading" intent which creates a ZIP automatically
            let intent = NSFileAccessIntent.readingIntent(with: sources[0], options: .forUploading)
            coordinator.coordinate(with: [intent], queue: .global()) { error in
                if let error { coordinatorError = error as NSError; return }
                do {
                    try FileManager.default.copyItem(at: intent.url, to: destination)
                } catch {
                    coordinatorError = error as NSError
                }
            }
        } else {
            // Multiple files: create a temp directory, copy everything, zip with ZipArchive
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmp) }

            for source in sources {
                let dest = tmp.appendingPathComponent(source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: dest)
            }
            let success = SSZipArchive.createZipFile(
                atPath: destination.path,
                withContentsOfDirectory: tmp.path
            )
            if !success { throw ArchiveError.compressionFailed }
        }

        if let err = coordinatorError { throw err }
    }

    // MARK: - Encrypted ZIP (AES-256 via ZipArchive)

    /// Creates an AES-256 encrypted ZIP archive.
    public static func zipEncrypted(sources: [URL], destination: URL, password: String) throws {
        guard !sources.isEmpty else { throw ArchiveError.encryptionFailed }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        for source in sources {
            let dest = tmp.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: dest)
        }

        let success = SSZipArchive.createZipFile(
            atPath: destination.path,
            withContentsOfDirectory: tmp.path,
            keepParentDirectory: false,
            compressionLevel: -1,
            password: password,
            aes: true,
            progressHandler: nil
        )

        guard success else { throw ArchiveError.encryptionFailed }
    }

    // MARK: - Suggested destination URL

    public static func archiveURL(for sources: [URL]) -> URL {
        let base = sources.first?.deletingLastPathComponent() ?? URL(fileURLWithPath: NSHomeDirectory())
        let name = sources.count == 1 ? sources[0].deletingPathExtension().lastPathComponent : "Archive"
        return base.appendingPathComponent("\(name).zip")
    }
}
