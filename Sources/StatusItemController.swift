import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let monitor: SpaceMonitor
    private let store: SpaceStore
    private var cancellables = Set<AnyCancellable>()

    init(monitor: SpaceMonitor, store: SpaceStore) {
        self.monitor = monitor
        self.store = store

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 290, height: 380)
        popover.contentViewController = NSHostingController(
            rootView: EditorPopover(monitor: monitor, store: store)
        )

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        // React to Space changes.
        monitor.$currentSpaceID
            .receive(on: RunLoop.main)
            .sink { [weak self] id in
                self?.render(id: id)
            }
            .store(in: &cancellables)

        // React to label edits (rename / recolor).
        store.$labels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.render(id: self.monitor.currentSpaceID)
            }
            .store(in: &cancellables)
    }

    private func render(id: UInt64) {
        guard let button = statusItem.button else { return }
        let label = store.label(for: id)
        let color = NSColor(hex: label.colorHex) ?? .labelColor

        let attributed = NSMutableAttributedString()
        attributed.append(
            NSAttributedString(
                string: "● ",
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: 13),
                ]
            ))
        attributed.append(
            NSAttributedString(
                string: label.name,
                attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                ]
            ))
        button.attributedTitle = attributed
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
