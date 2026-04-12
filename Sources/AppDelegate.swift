import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SpaceMonitor!
    private var store: SpaceStore!
    private var statusController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerAsLoginItem()
        monitor = SpaceMonitor()
        store = SpaceStore()
        statusController = StatusItemController(monitor: monitor, store: store)
    }

    /// Register the app to launch automatically at login. The first call on a
    /// given user account surfaces a System Settings prompt; after that it is
    /// silent. `try?` because registration failure should never block startup:
    /// the user can always relaunch manually or toggle the setting in System
    /// Settings → General → Login Items.
    private func registerAsLoginItem() {
        try? SMAppService.mainApp.register()
    }
}
