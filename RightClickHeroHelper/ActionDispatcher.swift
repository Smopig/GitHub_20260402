import Foundation
import AppKit
import RightClickHeroKit

/// Implements RightClickHeroXPCProtocol.
/// Routes each incoming ActionRequest to the appropriate feature implementation.
@objc final class ActionDispatcher: NSObject, RightClickHeroXPCProtocol {

    private let fileOps = FileOperations()

    @objc func performAction(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        do {
            let request = try ActionRequest.decoded(from: data)
            let result = try dispatch(request)
            reply(try result.encoded(), nil)
        } catch {
            let result = ActionResult.failure(error.localizedDescription)
            reply(try? result.encoded(), nil)
        }
    }

    @objc func ping(withReply reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    // MARK: - Routing

    private func dispatch(_ req: ActionRequest) throws -> ActionResult {
        switch req.type {

        case .newFile:
            return try handleNewFile(req)

        case .paste:
            return try handlePaste(req)

        case .hideFile, .showFile:
            return try handleHideShow(req)

        case .permanentDelete:
            return try handlePermanentDelete(req)

        case .convertImage:
            return try handleConvertImage(req)

        case .compress:
            return try handleCompress(req, encrypted: false)

        case .compressEncrypted:
            return try handleCompress(req, encrypted: true)

        case .moveToFolder:
            return try handleMoveOrCopy(req, move: true)

        case .copyToFolder:
            return try handleMoveOrCopy(req, move: false)

        case .openWith:
            return try handleOpenWith(req)

        case .airDrop:
            return handleAirDrop(req)

        case .cutMark:
            // Cut state is managed entirely in the extension via SharedDefaults; no helper action needed.
            return .ok()

        case .analyzeSpace, .findDuplicates:
            // These are handled asynchronously in the main app UI.
            return .ok()

        case .screenshot, .screenRecordStart, .screenRecordStop:
            // Handled by ScreenCaptureCoordinator in the main app.
            return .ok()
        }
    }

    // MARK: - Handlers

    private func handleNewFile(_ req: ActionRequest) throws -> ActionResult {
        guard let destData = req.destinationBookmark else {
            return .failure("No destination provided")
        }
        let templateID = req.parameters["template"] ?? "txt"
        guard let template = FileTemplateManager.allTemplates.first(where: { $0.id == templateID }) else {
            return .failure("Unknown template: \(templateID)")
        }
        return try BookmarkHelper.withResolvedURL(destData) { dirURL in
            let created = try FileTemplateManager.createFile(template: template, in: dirURL)
            let bookmark = try BookmarkHelper.writableBookmark(for: created)
            return .ok("Created \(created.lastPathComponent)", bookmarks: [bookmark])
        }
    }

    private func handlePaste(_ req: ActionRequest) throws -> ActionResult {
        guard let destData = req.destinationBookmark else {
            return .failure("No destination provided")
        }
        return try BookmarkHelper.withResolvedURL(destData) { destURL in
            var moved: [String] = []
            for bookmarkData in req.bookmarks {
                try BookmarkHelper.withResolvedURL(bookmarkData) { srcURL in
                    try fileOps.move(source: srcURL, toDirectory: destURL)
                    moved.append(srcURL.lastPathComponent)
                }
            }
            return .ok("Moved: \(moved.joined(separator: ", "))")
        }
    }

    private func handleHideShow(_ req: ActionRequest) throws -> ActionResult {
        let hidden = req.type == .hideFile
        for bookmarkData in req.bookmarks {
            try BookmarkHelper.withResolvedURL(bookmarkData) { url in
                var values = URLResourceValues()
                values.isHidden = hidden
                var mutableURL = url
                try mutableURL.setResourceValues(values)
            }
        }
        return .ok(hidden ? "Files hidden" : "Files visible")
    }

    private func handlePermanentDelete(_ req: ActionRequest) throws -> ActionResult {
        for bookmarkData in req.bookmarks {
            try BookmarkHelper.withResolvedURL(bookmarkData) { url in
                try FileManager.default.removeItem(at: url)
            }
        }
        return .ok("Deleted \(req.bookmarks.count) item(s)")
    }

    private func handleConvertImage(_ req: ActionRequest) throws -> ActionResult {
        let formatStr = req.parameters["format"] ?? "png"
        guard let format = ImageFormat(rawValue: formatStr) else {
            return .failure("Unknown format: \(formatStr)")
        }
        var resultBookmarks: [Data] = []
        for bookmarkData in req.bookmarks {
            try BookmarkHelper.withResolvedURL(bookmarkData) { url in
                let output = try ImageConverter.convert(source: url, to: format)
                let bm = try BookmarkHelper.writableBookmark(for: output)
                resultBookmarks.append(bm)
            }
        }
        return .ok("Converted \(resultBookmarks.count) image(s)", bookmarks: resultBookmarks)
    }

    private func handleCompress(_ req: ActionRequest, encrypted: Bool) throws -> ActionResult {
        var sources: [URL] = []
        var accessTokens: [URL] = []

        for bookmarkData in req.bookmarks {
            let url = try BookmarkHelper.resolve(bookmarkData)
            guard url.startAccessingSecurityScopedResource() else { continue }
            sources.append(url)
            accessTokens.append(url)
        }
        defer { accessTokens.forEach { $0.stopAccessingSecurityScopedResource() } }

        guard !sources.isEmpty else { return .failure("No accessible sources") }

        let dest = ArchiveManager.archiveURL(for: sources)

        if encrypted {
            let password = req.parameters["password"] ?? ""
            guard !password.isEmpty else { return .failure("Password required for encrypted archive") }
            if #available(macOS 12.0, *) {
                try ArchiveManager.encryptedArchive(sources: sources, destination: dest, password: password)
            } else {
                return .failure("Encrypted archive requires macOS 12 or later")
            }
        } else {
            try ArchiveManager.zip(sources: sources, destination: dest)
        }

        return .ok("Archive created: \(dest.lastPathComponent)")
    }

    private func handleMoveOrCopy(_ req: ActionRequest, move: Bool) throws -> ActionResult {
        guard let destData = req.destinationBookmark else {
            return .failure("No destination provided")
        }
        return try BookmarkHelper.withResolvedURL(destData) { destURL in
            for bookmarkData in req.bookmarks {
                try BookmarkHelper.withResolvedURL(bookmarkData) { src in
                    if move {
                        try fileOps.move(source: src, toDirectory: destURL)
                    } else {
                        try fileOps.copy(source: src, toDirectory: destURL)
                    }
                }
            }
            SharedDefaults.addRecentDestination(destURL.path)
            return .ok()
        }
    }

    private func handleOpenWith(_ req: ActionRequest) throws -> ActionResult {
        guard let appPath = req.parameters["appPath"], !appPath.isEmpty else {
            return .failure("No app path specified")
        }
        let appURL = URL(fileURLWithPath: appPath)
        var fileURLs: [URL] = []
        for bm in req.bookmarks {
            if let url = try? BookmarkHelper.resolve(bm) { fileURLs.append(url) }
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(fileURLs, withApplicationAt: appURL, configuration: config)
        return .ok()
    }

    private func handleAirDrop(_ req: ActionRequest) -> ActionResult {
        // Notify the main app via Darwin notification to present the AirDrop picker.
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(BundleConfig.airDropNotificationName),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return .ok()
    }
}
