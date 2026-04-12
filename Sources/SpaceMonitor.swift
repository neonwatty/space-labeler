import AppKit
import Combine

/// Publishes the currently-active Space ID and emits whenever it changes.
/// Combines the public NSWorkspace notification (edge trigger) with the
/// private SkyLight API (value source).
final class SpaceMonitor: ObservableObject {
    @Published private(set) var currentSpaceID: UInt64 = 0

    init() {
        refresh()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        currentSpaceID = SkyLight.currentSpaceID() ?? 0
    }
}
