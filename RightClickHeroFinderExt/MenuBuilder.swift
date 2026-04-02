import Cocoa
import FinderSync
import RightClickHeroKit

/// Builds the NSMenu hierarchy from the list of enabled features.
/// Reads feature toggles from the shared App Group UserDefaults (no XPC needed).
enum MenuBuilder {

    // MARK: - Per-file context menu

    static func build(for urls: [URL], into menu: NSMenu, target: AnyObject) {
        let enabled = SharedDefaults.enabledFeatures
        let isMulti = urls.count > 1
        let isImageOnly = urls.allSatisfy { isImage($0) }

        if enabled.contains(.copyPath) {
            menu.addItem(item("Copy Path", action: #selector(FinderSyncExtension.copyPath(_:)), target: target))
        }

        if enabled.contains(.cutMark) {
            menu.addItem(item("Cut", action: #selector(FinderSyncExtension.cutFiles(_:)), target: target))
        }

        menu.addItem(.separator())

        if enabled.contains(.hideFile) || enabled.contains(.showFile) {
            let isHidden = (try? urls[0].resourceValues(forKeys: [.isHiddenKey]).isHidden) ?? false
            let title = isHidden ? "Show File" : "Hide File"
            menu.addItem(item(title, action: #selector(FinderSyncExtension.hideShowFile(_:)), target: target))
        }

        if enabled.contains(.permanentDelete) {
            let deleteItem = item("Delete Permanently", action: #selector(FinderSyncExtension.permanentDelete(_:)), target: target)
            deleteItem.image = NSImage(systemSymbolName: "trash.slash", accessibilityDescription: nil)
            menu.addItem(deleteItem)
        }

        menu.addItem(.separator())

        if enabled.contains(.convertImage) && isImageOnly {
            let submenu = NSMenu()
            for format in ["jpg", "png", "webp", "heic"] {
                let sub = NSMenuItem(title: "Convert to \(format.uppercased())", action: #selector(FinderSyncExtension.convertImage(_:)), keyEquivalent: "")
                sub.target = target
                sub.representedObject = format
                submenu.addItem(sub)
            }
            let convertItem = NSMenuItem(title: "Convert Image", action: nil, keyEquivalent: "")
            convertItem.submenu = submenu
            menu.addItem(convertItem)
        }

        if enabled.contains(.compress) {
            menu.addItem(item("Compress…", action: #selector(FinderSyncExtension.compressFiles(_:)), target: target))
        }

        if enabled.contains(.moveToFolder) && !isMulti {
            menu.addItem(item("Move to Folder…", action: #selector(FinderSyncExtension.moveToFolder(_:)), target: target))
        }

        if enabled.contains(.copyToFolder) {
            menu.addItem(item("Copy to Folder…", action: #selector(FinderSyncExtension.copyToFolder(_:)), target: target))
        }

        if enabled.contains(.airDrop) {
            menu.addItem(item("AirDrop", action: #selector(FinderSyncExtension.airDrop(_:)), target: target))
        }

        if enabled.contains(.openWith) && !isMulti {
            let openWithSubmenu = buildOpenWithSubmenu(for: urls[0], target: target)
            if openWithSubmenu.numberOfItems > 0 {
                let owItem = NSMenuItem(title: "Open With", action: nil, keyEquivalent: "")
                owItem.submenu = openWithSubmenu
                menu.addItem(owItem)
            }
        }
    }

    // MARK: - Folder background menu

    static func buildContainerMenu(in directory: URL?, into menu: NSMenu, target: AnyObject) {
        guard let dir = directory else { return }
        let enabled = SharedDefaults.enabledFeatures

        if enabled.contains(.newFile) {
            let newFileSubmenu = NSMenu()
            for template in FileTemplateManager.allTemplates {
                let sub = NSMenuItem(
                    title: template.displayName,
                    action: #selector(FinderSyncExtension.newFile(_:)),
                    keyEquivalent: ""
                )
                sub.target = target
                sub.representedObject = template.id
                if let img = NSImage(systemSymbolName: template.icon, accessibilityDescription: nil) {
                    sub.image = img
                }
                newFileSubmenu.addItem(sub)
            }
            let newItem = NSMenuItem(title: "New File", action: nil, keyEquivalent: "")
            newItem.submenu = newFileSubmenu
            menu.addItem(newItem)
        }

        if enabled.contains(.paste) && SharedDefaults.hasCutItems {
            menu.addItem(item("Paste Item", action: #selector(FinderSyncExtension.pasteFiles(_:)), target: target))
        }
    }

    // MARK: - Private helpers

    private static func item(_ title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = target
        return i
    }

    private static func buildOpenWithSubmenu(for url: URL, target: AnyObject) -> NSMenu {
        let submenu = NSMenu()
        let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
        for appURL in apps.prefix(15) {
            let name = Bundle(url: appURL)?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? appURL.deletingPathExtension().lastPathComponent
            let sub = NSMenuItem(title: name, action: #selector(FinderSyncExtension.openWith(_:)), keyEquivalent: "")
            sub.target = target
            sub.representedObject = appURL.path
            if let icon = NSWorkspace.shared.icon(forFile: appURL.path) as NSImage? {
                icon.size = NSSize(width: 16, height: 16)
                sub.image = icon
            }
            submenu.addItem(sub)
        }
        return submenu
    }

    private static func isImage(_ url: URL) -> Bool {
        let imageExtensions = Set(["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"])
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}
