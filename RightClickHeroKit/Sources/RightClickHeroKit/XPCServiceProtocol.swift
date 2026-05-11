import Foundation

/// The XPC protocol shared between the Finder Sync Extension and the Helper.
/// Must be @objc so NSXPCInterface can introspect it at runtime.
@objc public protocol RightClickHeroXPCProtocol {
    func performAction(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func ping(withReply reply: @escaping (Bool) -> Void)
}

/// Build-time identifiers, populated from each bundle's Info.plist.
/// The plist keys are filled by Xcode's `$(BUNDLE_PREFIX)` variable defined in Config.xcconfig,
/// so there is no hard-coded reverse-domain anywhere in the source tree.
public enum BundleConfig {

    private static func infoString(_ key: String, fallback: String) -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
            return value
        }
        return fallback
    }

    /// Mach service name the Helper registers and the Extension/App connect to.
    public static var helperMachServiceName: String {
        infoString("HelperMachServiceName", fallback: "com.smopig.RightClickHero.Helper")
    }

    /// Bundle identifier of the Helper login-item .app.
    public static var helperBundleIdentifier: String {
        infoString("HelperBundleIdentifier", fallback: "com.smopig.RightClickHero.Helper")
    }

    /// App Group identifier used for shared UserDefaults across all three processes.
    public static var appGroupIdentifier: String {
        infoString("AppGroupIdentifier", fallback: "group.com.smopig.rightclickhero")
    }

    /// Darwin notification name used by the Helper to ask the main App to present the AirDrop picker.
    public static var airDropNotificationName: String {
        infoString("AirDropNotificationName", fallback: "com.smopig.rightclickhero.showAirDrop")
    }
}

// MARK: - Back-compat aliases

public var kHelperMachServiceName: String { BundleConfig.helperMachServiceName }
public var kAppGroupIdentifier: String { BundleConfig.appGroupIdentifier }
