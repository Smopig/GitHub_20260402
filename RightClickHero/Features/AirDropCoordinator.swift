import Cocoa

/// Presents the NSSharingServicePicker for AirDrop.
/// Must run on the main thread from the main app process.
@MainActor
final class AirDropCoordinator {

    func present(files: [URL]) {
        guard !files.isEmpty else { return }

        // Bring the app to front so the picker has a window to anchor to
        NSApp.activate(ignoringOtherApps: true)

        guard let window = NSApp.mainWindow ?? NSApp.windows.first else {
            // Fallback: use the sharing service directly
            let service = NSSharingService(named: .sendViaAirDrop)
            service?.perform(withItems: files)
            return
        }

        let picker = NSSharingServicePicker(items: files)
        // Anchor to the center of the window's content view
        let bounds = window.contentView?.bounds ?? .zero
        picker.show(relativeTo: bounds, of: window.contentView!, preferredEdge: .minY)
    }
}
