import Foundation

/// Keys and accessors for the shared App Group UserDefaults.
/// All three targets (main app, extension, helper) read/write through this.
public enum SharedDefaults {

    public static var suite: UserDefaults {
        UserDefaults(suiteName: kAppGroupIdentifier) ?? .standard
    }

    // MARK: - Enabled features

    public static var enabledFeatures: Set<ActionType> {
        get {
            let raw = suite.stringArray(forKey: Keys.enabledFeatures) ?? ActionType.defaultRawValues
            return Set(raw.compactMap { ActionType(rawValue: $0) })
        }
        set {
            suite.set(newValue.map(\.rawValue), forKey: Keys.enabledFeatures)
        }
    }

    // MARK: - Cut clipboard state

    public static var cutBookmarks: [Data] {
        get { (suite.array(forKey: Keys.cutBookmarks) as? [Data]) ?? [] }
        set { suite.set(newValue, forKey: Keys.cutBookmarks) }
    }

    public static var hasCutItems: Bool { !cutBookmarks.isEmpty }

    public static func clearCutItems() {
        suite.removeObject(forKey: Keys.cutBookmarks)
    }

    // MARK: - Pending AirDrop (extension → main app)

    public static var pendingAirDropPaths: [String] {
        get { suite.stringArray(forKey: Keys.pendingAirDropPaths) ?? [] }
        set { suite.set(newValue, forKey: Keys.pendingAirDropPaths) }
    }

    // MARK: - Recent destinations (move/copy)

    public static var recentDestinations: [String] {
        get { suite.stringArray(forKey: Keys.recentDestinations) ?? [] }
        set {
            var list = newValue
            if list.count > 10 { list = Array(list.prefix(10)) }
            suite.set(list, forKey: Keys.recentDestinations)
        }
    }

    public static func addRecentDestination(_ path: String) {
        var list = recentDestinations.filter { $0 != path }
        list.insert(path, at: 0)
        recentDestinations = list
    }

    // MARK: - Keys

    private enum Keys {
        static let enabledFeatures = "enabledFeatures"
        static let cutBookmarks = "cutBookmarks"
        static let pendingAirDropPaths = "pendingAirDropPaths"
        static let recentDestinations = "recentDestinations"
    }
}

public extension ActionType {
    /// The default set of enabled features (on first launch).
    static var defaultRawValues: [String] {
        [
            ActionType.newFile,
            ActionType.cutMark,
            ActionType.paste,
            ActionType.copyPath,
            ActionType.convertImage,
            ActionType.hideFile,
            ActionType.showFile,
            ActionType.permanentDelete,
            ActionType.compress,
            ActionType.moveToFolder,
            ActionType.copyToFolder,
            ActionType.openWith,
            ActionType.airDrop,
        ].map(\.rawValue)
    }
}
