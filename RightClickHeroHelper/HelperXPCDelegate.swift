import Foundation
import RightClickHeroKit

/// NSXPCListenerDelegate — accepts incoming connections and vends the ActionDispatcher.
final class HelperXPCDelegate: NSObject, NSXPCListenerDelegate {

    let dispatcher: ActionDispatcher

    init(dispatcher: ActionDispatcher) {
        self.dispatcher = dispatcher
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: RightClickHeroXPCProtocol.self)
        newConnection.exportedObject = dispatcher
        newConnection.resume()
        return true
    }
}
