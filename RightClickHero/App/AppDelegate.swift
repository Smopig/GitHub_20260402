import Cocoa
import ServiceManagement
import RightClickHeroKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var airDropCoordinator: AirDropCoordinator?
    private var screenCapture: ScreenCaptureCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHelperLoginItem()
        listenForAirDropRequests()
        airDropCoordinator = AirDropCoordinator()
        screenCapture = ScreenCaptureCoordinator()
    }

    // MARK: - Helper registration

    private func registerHelperLoginItem() {
        let helperID = BundleConfig.helperBundleIdentifier
        if #available(macOS 13.0, *) {
            let service = SMAppService.loginItem(identifier: helperID)
            do {
                if service.status == .notRegistered {
                    try service.register()
                }
            } catch {
                NSLog("[RCH] Failed to register helper: \(error)")
            }
        } else {
            SMLoginItemSetEnabled(helperID as CFString, true)
        }
    }

    // MARK: - AirDrop listener

    private func listenForAirDropRequests() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showAirDrop),
            name: NSNotification.Name(BundleConfig.airDropNotificationName),
            object: nil
        )
    }

    @objc private func showAirDrop() {
        let paths = SharedDefaults.pendingAirDropPaths
        guard !paths.isEmpty else { return }
        SharedDefaults.pendingAirDropPaths = []
        let urls = paths.map { URL(fileURLWithPath: $0) }
        DispatchQueue.main.async {
            self.airDropCoordinator?.present(files: urls)
        }
    }
}
