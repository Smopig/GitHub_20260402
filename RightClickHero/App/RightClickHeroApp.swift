import SwiftUI
import ServiceManagement
import RightClickHeroKit

@main
struct RightClickHeroApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 680, height: 520)

        Settings {
            SettingsView()
        }
    }
}
