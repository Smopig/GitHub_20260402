import Foundation

/// A disk usage entry returned by DiskScanner.
public struct DiskEntry: Identifiable, Sendable {
    public let id = UUID()
    public let url: URL
    public let size: Int64
    public let isDirectory: Bool
    public let childCount: Int

    public init(url: URL, size: Int64, isDirectory: Bool, childCount: Int = 0) {
        self.url = url
        self.size = size
        self.isDirectory = isDirectory
        self.childCount = childCount
    }
}

/// Disk scanner using FileManager enumeration.
/// For production, replace with BSD fts_open/fts_read for 5–10× faster traversal.
public actor DiskScanner {

    public init() {}

    /// Returns all entries in the given root directory sorted by size descending.
    public func scan(root: URL) async throws -> [DiskEntry] {
        var entries: [DiskEntry] = []
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        var dirSizes: [URL: Int64] = [root: 0]

        for case let url as URL in enumerator {
            let vals = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
            guard vals.isSymbolicLink != true else { continue }

            let isDir = vals.isDirectory ?? false
            let size = vals.fileSize.flatMap(Int64.init) ?? 0

            if !isDir {
                // Accumulate size in all ancestor directories
                var parent = url.deletingLastPathComponent()
                while parent.path.hasPrefix(root.path) {
                    dirSizes[parent, default: 0] += size
                    parent = parent.deletingLastPathComponent()
                }
                entries.append(DiskEntry(url: url, size: size, isDirectory: false))
            } else {
                dirSizes[url] = 0
            }
        }

        // Add directory entries with accumulated sizes
        for (url, size) in dirSizes where url != root {
            entries.append(DiskEntry(url: url, size: size, isDirectory: true))
        }

        return entries.sorted { $0.size > $1.size }
    }

    /// Top-level children of `root` with their total sizes (for treemap).
    public func topLevel(root: URL, limit: Int = 20) async throws -> [DiskEntry] {
        let fm = FileManager.default
        let children = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var results: [DiskEntry] = []
        for child in children {
            let vals = try child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDir = vals.isDirectory ?? false
            let size: Int64
            if isDir {
                size = try await directorySize(child)
            } else {
                size = vals.fileSize.flatMap(Int64.init) ?? 0
            }
            results.append(DiskEntry(url: child, size: size, isDirectory: isDir))
        }

        return results.sorted { $0.size > $1.size }.prefix(limit).map { $0 }
    }

    private func directorySize(_ url: URL) async throws -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey]
        ) else { return 0 }
        for case let file as URL in enumerator {
            let vals = try? file.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
            if vals?.isSymbolicLink != true {
                total += vals?.fileSize.flatMap(Int64.init) ?? 0
            }
        }
        return total
    }
}
