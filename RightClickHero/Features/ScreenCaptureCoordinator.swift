import Cocoa
import ScreenCaptureKit

/// Manages screenshot and screen recording using ScreenCaptureKit (macOS 13+).
@MainActor
final class ScreenCaptureCoordinator {

    // MARK: - Screenshot

    @available(macOS 13.0, *)
    func captureScreenshot(completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else {
                    completion(nil); return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                var config = SCStreamConfiguration()
                config.width = display.width * 2   // Retina
                config.height = display.height * 2
                config.scalesToFit = true

                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
                let image = NSImage(cgImage: cgImage, size: NSSize(width: display.width, height: display.height))

                // Save to Desktop with timestamp
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
                let filename = "Screenshot \(formatter.string(from: Date())).png"
                let dest = desktopURL.appendingPathComponent(filename)

                if let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try png.write(to: dest)
                }

                completion(image)
            } catch {
                NSLog("[RCH] Screenshot failed: \(error)")
                completion(nil)
            }
        }
    }

    // MARK: - Authorization check

    @available(macOS 13.0, *)
    func requestPermissionIfNeeded() async -> Bool {
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            NSLog("[RCH] Screen capture not authorized: \(error)")
            // Open System Settings > Privacy > Screen Recording
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            return false
        }
    }
}
