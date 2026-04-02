import Foundation

/// The XPC protocol shared between the Finder Sync Extension and the Helper.
/// Must be @objc so NSXPCInterface can introspect it at runtime.
@objc public protocol RightClickHeroXPCProtocol {
    func performAction(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func ping(withReply reply: @escaping (Bool) -> Void)
}

/// Mach service name the Helper registers and the Extension connects to.
public let kHelperMachServiceName = "com.yourco.RightClickHeroHelper"

/// App Group identifier used for shared UserDefaults.
public let kAppGroupIdentifier = "group.com.yourco.rightclickhero"
