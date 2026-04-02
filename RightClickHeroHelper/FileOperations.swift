import Foundation

/// Thread-safe file system operations wrapped with NSFileCoordinator
/// to play nicely with Finder and other file coordinators.
final class FileOperations {

    enum FileOpError: LocalizedError {
        case destinationExists(URL)
        case moveFailed(String)
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .destinationExists(let u): return "An item named '\(u.lastPathComponent)' already exists at the destination."
            case .moveFailed(let msg): return "Move failed: \(msg)"
            case .copyFailed(let msg): return "Copy failed: \(msg)"
            }
        }
    }

    func move(source: URL, toDirectory directory: URL) throws {
        let dest = uniqueDestination(for: source, in: directory)
        var coordError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: source, options: .forMoving,
            writingItemAt: dest,   options: .forReplacing,
            error: &coordError
        ) { srcURL, destURL in
            do {
                try FileManager.default.moveItem(at: srcURL, to: destURL)
            } catch {
                coordError = error as NSError
            }
        }
        if let err = coordError { throw err }
    }

    func copy(source: URL, toDirectory directory: URL) throws {
        let dest = uniqueDestination(for: source, in: directory)
        var coordError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: source, options: [],
            writingItemAt: dest,   options: .forReplacing,
            error: &coordError
        ) { srcURL, destURL in
            do {
                try FileManager.default.copyItem(at: srcURL, to: destURL)
            } catch {
                coordError = error as NSError
            }
        }
        if let err = coordError { throw err }
    }

    // MARK: - Private

    /// Returns a destination URL that doesn't conflict with existing files.
    private func uniqueDestination(for source: URL, in directory: URL) -> URL {
        let base = directory.appendingPathComponent(source.lastPathComponent)
        if !FileManager.default.fileExists(atPath: base.path) { return base }

        let name = source.deletingPathExtension().lastPathComponent
        let ext  = source.pathExtension
        var counter = 2
        while true {
            let name2 = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
            let candidate = directory.appendingPathComponent(name2)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
    }
}
