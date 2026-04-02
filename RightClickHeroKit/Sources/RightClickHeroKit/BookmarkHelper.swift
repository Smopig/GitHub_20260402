import Foundation

/// Utilities for creating and resolving security-scoped bookmarks.
/// Used to safely transport file references across sandbox process boundaries over XPC.
public enum BookmarkHelper {

    public enum BookmarkError: LocalizedError {
        case creationFailed(URL)
        case resolutionFailed
        case stale(URL)

        public var errorDescription: String? {
            switch self {
            case .creationFailed(let url): return "Could not create bookmark for \(url.path)"
            case .resolutionFailed: return "Could not resolve bookmark data"
            case .stale(let url): return "Bookmark is stale for \(url.path)"
            }
        }
    }

    /// Creates a security-scoped bookmark for a URL received from the Finder extension.
    public static func bookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.creationFailed(url)
        }
    }

    /// Creates a read-write security-scoped bookmark.
    public static func writableBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.creationFailed(url)
        }
    }

    /// Resolves bookmark data back to a URL and starts security-scoped access.
    /// Caller is responsible for calling `url.stopAccessingSecurityScopedResource()`.
    public static func resolve(_ data: Data) throws -> URL {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw BookmarkError.resolutionFailed
        }
        if isStale { throw BookmarkError.stale(url) }
        return url
    }

    /// Convenience: resolve + access + run closure + stop access.
    public static func withResolvedURL<T>(
        _ data: Data,
        perform block: (URL) throws -> T
    ) throws -> T {
        let url = try resolve(data)
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.resolutionFailed
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try block(url)
    }
}
