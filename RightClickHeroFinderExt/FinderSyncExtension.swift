import Cocoa
import FinderSync
import RightClickHeroKit

/// The principal class of the Finder Sync Extension.
/// Registers the monitored directory and injects the right-click context menu.
class FinderSyncExtension: FIFinderSync {

    private let xpcClient = XPCClient()

    override init() {
        super.init()
        // Monitor the user's home directory.
        // This covers Documents, Desktop, Downloads, etc.
        let home = URL(fileURLWithPath: NSHomeDirectory())
        FIFinderSyncController.default().directoryURLs = [home]
    }

    // MARK: - Menu Construction

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")

        switch menuKind {

        case .contextualMenuForItems:
            // Right-click on one or more selected files/folders
            let urls = FIFinderSyncController.default().selectedItemURLs() ?? []
            guard !urls.isEmpty else { return menu }
            MenuBuilder.build(for: urls, into: menu, target: self)

        case .contextualMenuForContainer:
            // Right-click on the folder background (empty space)
            let containerURL = FIFinderSyncController.default().targetedURL()
            MenuBuilder.buildContainerMenu(in: containerURL, into: menu, target: self)

        default:
            break
        }

        return menu
    }

    // MARK: - Menu Actions (called by MenuBuilder-configured menu items)

    @objc func copyPath(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let paths = urls.map(\.path).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
    }

    @objc func cutFiles(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        do {
            let bookmarks = try urls.map { try BookmarkHelper.writableBookmark(for: $0) }
            SharedDefaults.cutBookmarks = bookmarks

            // Optionally tint the cut items with an orange Finder label as visual feedback
            for url in urls {
                var values = URLResourceValues()
                values.labelNumber = 2  // 2 = orange in Finder
                var mutableURL = url
                try? mutableURL.setResourceValues(values)
            }
        } catch {
            NSLog("[RCH] Cut failed: \(error)")
        }
    }

    @objc func pasteFiles(_ sender: NSMenuItem) {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        let bookmarks = SharedDefaults.cutBookmarks
        guard !bookmarks.isEmpty else { return }

        do {
            let destBookmark = try BookmarkHelper.writableBookmark(for: target)
            let request = ActionRequest(
                type: .paste,
                bookmarks: bookmarks,
                destinationBookmark: destBookmark
            )
            xpcClient.send(request)
            SharedDefaults.clearCutItems()
        } catch {
            NSLog("[RCH] Paste failed: \(error)")
        }
    }

    @objc func newFile(_ sender: NSMenuItem) {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        let templateID = (sender.representedObject as? String) ?? "txt"
        do {
            let destBookmark = try BookmarkHelper.writableBookmark(for: target)
            let request = ActionRequest(
                type: .newFile,
                destinationBookmark: destBookmark,
                parameters: ["template": templateID]
            )
            xpcClient.send(request)
        } catch {
            NSLog("[RCH] New file failed: \(error)")
        }
    }

    @objc func hideShowFile(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        do {
            // Determine toggle direction from the first selected file
            let isCurrentlyHidden = (try? urls[0].resourceValues(forKeys: [.isHiddenKey]).isHidden) ?? false
            let bookmarks = try urls.map { try BookmarkHelper.writableBookmark(for: $0) }
            let request = ActionRequest(
                type: isCurrentlyHidden ? .showFile : .hideFile,
                bookmarks: bookmarks
            )
            xpcClient.send(request)
        } catch {
            NSLog("[RCH] Hide/Show failed: \(error)")
        }
    }

    @objc func permanentDelete(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }

        // Show inline confirmation alert
        let alert = NSAlert()
        alert.messageText = "Permanently delete \(urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) items")?"
        alert.informativeText = "This action cannot be undone. The files will not be moved to Trash."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let bookmarks = try urls.map { try BookmarkHelper.writableBookmark(for: $0) }
            let request = ActionRequest(type: .permanentDelete, bookmarks: bookmarks)
            xpcClient.send(request)
        } catch {
            NSLog("[RCH] Permanent delete failed: \(error)")
        }
    }

    @objc func convertImage(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let format = (sender.representedObject as? String) ?? "png"
        do {
            let bookmarks = try urls.map { try BookmarkHelper.writableBookmark(for: $0) }
            let request = ActionRequest(
                type: .convertImage,
                bookmarks: bookmarks,
                parameters: ["format": format]
            )
            xpcClient.send(request)
        } catch {
            NSLog("[RCH] Image conversion failed: \(error)")
        }
    }

    @objc func compressFiles(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        do {
            let bookmarks = try urls.map { try BookmarkHelper.writableBookmark(for: $0) }
            let request = ActionRequest(type: .compress, bookmarks: bookmarks)
            xpcClient.send(request)
        } catch {
            NSLog("[RCH] Compress failed: \(error)")
        }
    }

    @objc func airDrop(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        // Store paths in App Group, then ask the main app to present the picker
        SharedDefaults.pendingAirDropPaths = urls.map(\.path)
        let request = ActionRequest(type: .airDrop, bookmarks: [])
        xpcClient.send(request)
    }

    @objc func moveToFolder(_ sender: NSMenuItem) {
        sendMoveOrCopy(type: .moveToFolder)
    }

    @objc func copyToFolder(_ sender: NSMenuItem) {
        sendMoveOrCopy(type: .copyToFolder)
    }

    private func sendMoveOrCopy(type: ActionType) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        do {
            let bookmarks = try urls.map { try BookmarkHelper.writableBookmark(for: $0) }
            let request = ActionRequest(type: type, bookmarks: bookmarks)
            xpcClient.send(request)
        } catch {
            NSLog("[RCH] Move/Copy failed: \(error)")
        }
    }

    @objc func openWith(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let appPath = (sender.representedObject as? String) ?? ""
        do {
            let bookmarks = try urls.map { try BookmarkHelper.writableBookmark(for: $0) }
            let request = ActionRequest(
                type: .openWith,
                bookmarks: bookmarks,
                parameters: ["appPath": appPath]
            )
            xpcClient.send(request)
        } catch {
            NSLog("[RCH] Open With failed: \(error)")
        }
    }
}
