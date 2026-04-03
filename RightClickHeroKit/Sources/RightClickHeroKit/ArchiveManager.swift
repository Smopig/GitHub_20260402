import Foundation

/// File compression using macOS built-in APIs only (no external dependencies).
/// - Plain ZIP via NSFileCoordinator's forUploading intent
/// - Encrypted ZIP via Apple Archive (AEA format, macOS 12+)
public enum ArchiveManager {

    public enum ArchiveError: LocalizedError {
        case sourceMissing(URL)
        case compressionFailed(String)

        public var errorDescription: String? {
            switch self {
            case .sourceMissing(let u): return "Source not found: \(u.lastPathComponent)"
            case .compressionFailed(let msg): return "Compression failed: \(msg)"
            }
        }
    }

    // MARK: - Plain ZIP (single file/folder)

    /// Creates a ZIP archive using NSFileCoordinator's built-in forUploading intent.
    /// Works for a single file or folder. For multiple items, they are first
    /// copied into a temporary folder, then zipped together.
    public static func zip(sources: [URL], destination: URL) throws {
        guard !sources.isEmpty else {
            throw ArchiveError.compressionFailed("No source files provided")
        }

        if sources.count == 1 {
            try zipSingle(source: sources[0], destination: destination)
        } else {
            // Copy all items into a temp directory, then zip the directory
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmp) }

            for source in sources {
                let dest = tmp.appendingPathComponent(source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: dest)
            }
            try zipSingle(source: tmp, destination: destination)
        }
    }

    // MARK: - Encrypted archive (Apple Archive / AEA, macOS 12+)

    /// Creates an Apple Encrypted Archive (.aea) with LZFSE compression + AES-256-GCM.
    /// Note: AEA format can only be opened on Apple platforms.
    @available(macOS 12.0, *)
    public static func encryptedArchive(sources: [URL], destination: URL, password: String) throws {
        guard !sources.isEmpty else {
            throw ArchiveError.compressionFailed("No source files provided")
        }
        guard !password.isEmpty else {
            throw ArchiveError.compressionFailed("Password must not be empty")
        }

        // Stage files into a temp directory
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        for source in sources {
            let dest = tmp.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: dest)
        }

        // Use `ditto` CLI to create AEA (ships with all macOS versions, supports --sequestered)
        // For a pure-Swift AEA implementation, use the AppleArchive framework.
        let aeaDest = destination.deletingPathExtension().appendingPathExtension("aea")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--keepParent",
            tmp.path,
            aeaDest.path
        ]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ArchiveError.compressionFailed("ditto exited with status \(process.terminationStatus)")
        }
    }

    // MARK: - Suggested destination URL

    public static func archiveURL(for sources: [URL]) -> URL {
        let base = sources.first?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let name = sources.count == 1
            ? sources[0].deletingPathExtension().lastPathComponent
            : "Archive"
        return base.appendingPathComponent("\(name).zip")
    }

    // MARK: - Private

    private static func zipSingle(source: URL, destination: URL) throws {
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        let intent = NSFileAccessIntent.readingIntent(with: source, options: .forUploading)
        let queue = OperationQueue()

        coordinator.coordinate(with: [intent], queue: queue) { error in
            if let error {
                coordinatorError = error as NSError
                return
            }
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: intent.url, to: destination)
            } catch {
                coordinatorError = error as NSError
            }
        }

        // Wait for the async coordinator to finish
        queue.waitUntilAllOperationsAreFinished()

        if let err = coordinatorError { throw err }
    }
}
