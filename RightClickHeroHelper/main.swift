import Foundation
import RightClickHeroKit

/// Entry point for the XPC Login Item helper.
/// Registers as a Mach service so both the main app and the Finder extension can connect.
let dispatcher = ActionDispatcher()
let delegate = HelperXPCDelegate(dispatcher: dispatcher)
let listener = NSXPCListener(machServiceName: kHelperMachServiceName)
listener.delegate = delegate
listener.resume()

// Keep the helper running indefinitely.
RunLoop.main.run()
