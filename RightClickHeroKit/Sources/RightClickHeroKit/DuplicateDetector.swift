import Foundation
import CryptoKit

/// Two-phase duplicate file detector.
/// Phase 1: group by file size (cheap).
/// Phase 2: SHA-256 hash candidates (accurate).
public actor DuplicateDetector {

    public struct DuplicateGroup: Identifiable {
        public let id: UUID
        public let hash: String
        public let files: [URL]
        public var wastedBytes: Int64 {
            guard files.count > 1 else { return 0 }
            let size = (try? files[0].resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
            return size * Int64(files.count - 1)
        }

        public init(hash: String, files: [URL]) {
            self.id = UUID()
            self.hash = hash
            self.files = files
        }
    }

    public init() {}

    public func findDuplicates(in directory: URL, progressHandler: ((Int, Int) -> Void)? = nil) async throws -> [DuplicateGroup] {
        let allFiles = try collectFiles(in: directory)
        let sizeGroups = groupBySize(allFiles)
        let candidates = sizeGroups.filter { $0.value.count > 1 }.values.flatMap { $0 }

        var hashMap: [String: [URL]] = [:]
        let total = candidates.count
        var processed = 0

        try await withThrowingTaskGroup(of: (String, URL).self) { group in
            for url in candidates {
                group.addTask {
                    let hash = try sha256(of: url)
                    return (hash, url)
                }
            }
            for try await (hash, url) in group {
                hashMap[hash, default: []].append(url)
                processed += 1
                progressHandler?(processed, total)
            }
        }

        return hashMap
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(hash: $0.key, files: $0.value) }
            .sorted { $0.wastedBytes > $1.wastedBytes }
    }

    // MARK: - Private

    private func collectFiles(in directory: URL) throws -> [URL] {
        var results: [URL] = []
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        while let url = enumerator?.nextObject() as? URL {
            let vals = try url.resourceValues(forKeys: [.isRegularFileKey])
            if vals.isRegularFile == true {
                results.append(url)
            }
        }
        return results
    }

    private func groupBySize(_ files: [URL]) -> [Int64: [URL]] {
        var groups: [Int64: [URL]] = [:]
        for url in files {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? -1
            if size > 0 {
                groups[size, default: []].append(url)
            }
        }
        return groups
    }
}

// MARK: - SHA-256 (free function for TaskGroup usage)

private func sha256(of url: URL) throws -> String {
    let bufferSize = 1024 * 1024  // 1 MB chunks
    guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
        throw CocoaError(.fileReadNoSuchFile)
    }
    defer { try? fileHandle.close() }

    var hasher = SHA256()
    while true {
        let data = fileHandle.readData(ofLength: bufferSize)
        if data.isEmpty { break }
        hasher.update(data: data)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}
