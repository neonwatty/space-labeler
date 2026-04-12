import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SpaceMonitor!
    private var store: SpaceStore!
    private var statusController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = SpaceMonitor()
        store = SpaceStore()
        statusController = StatusItemController(monitor: monitor, store: store)
    }
}
