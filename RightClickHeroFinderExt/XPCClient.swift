import Foundation
import RightClickHeroKit

/// Sends ActionRequests from the Finder Sync Extension to the XPC Helper.
/// Handles connection lifecycle, reconnection on interruption, and error logging.
final class XPCClient {

    private var connection: NSXPCConnection?
    private let lock = NSLock()

    func send(_ request: ActionRequest, completion: ((ActionResult?) -> Void)? = nil) {
        guard let data = try? request.encoded() else {
            completion?(nil)
            return
        }

        let proxy = remoteProxy()
        proxy?.performAction(data) { resultData, error in
            if let error {
                NSLog("[RCH] XPC error: \(error)")
                completion?(nil)
                return
            }
            let result = resultData.flatMap { try? ActionResult.decoded(from: $0) }
            completion?(result)
        }
    }

    // MARK: - Private

    private func remoteProxy() -> RightClickHeroXPCProtocol? {
        lock.lock()
        defer { lock.unlock() }

        if connection == nil {
            connection = makeConnection()
        }
        return connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            NSLog("[RCH] XPC proxy error: \(error)")
            self?.invalidateConnection()
        } as? RightClickHeroXPCProtocol
    }

    private func makeConnection() -> NSXPCConnection {
        let conn = NSXPCConnection(machServiceName: kHelperMachServiceName, options: [])
        conn.remoteObjectInterface = NSXPCInterface(with: RightClickHeroXPCProtocol.self)
        conn.invalidationHandler = { [weak self] in
            self?.invalidateConnection()
        }
        conn.interruptionHandler = { [weak self] in
            self?.invalidateConnection()
        }
        conn.resume()
        return conn
    }

    private func invalidateConnection() {
        lock.lock()
        defer { lock.unlock() }
        connection?.invalidate()
        connection = nil
    }
}
