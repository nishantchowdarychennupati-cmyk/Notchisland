import AppKit
import Combine
import SwiftUI

/// Borderless, transparent panel that sits over the notch and never steals focus.
final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets buttons respond to the first click even though the panel is never key.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class IslandWindowController {
    let model: IslandModel
    private let prefs = Preferences.shared
    private let panel: IslandPanel
    private var trackTimer: Timer?
    private var hoverSince: Date?
    private var leftSince: Date?
    private var lastDragCount = NSPasteboard(name: .drag).changeCount
    private var isDragging = false
    private var cancellables = Set<AnyCancellable>()

    /// Fixed canvas; the island grows inside it. Transparent areas pass clicks through.
    private static let panelSize = NSSize(width: 960, height: 340)

    init(model: IslandModel) {
        self.model = model
        panel = IslandPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none

        let host = IslandHostingView(rootView: IslandView(model: model, prefs: prefs))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: Self.panelSize)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        applyCollectionBehavior()
        reposition()

        prefs.$displayChoice
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.reposition() } }
            .store(in: &cancellables)
        prefs.$showInFullScreen
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.applyCollectionBehavior() } }
            .store(in: &cancellables)
    }

    func show() {
        panel.orderFrontRegardless()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.trackMouse() }
        RunLoop.main.add(timer, forMode: .common)
        trackTimer = timer
    }

    private func applyCollectionBehavior() {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if prefs.showInFullScreen { behavior.insert(.fullScreenAuxiliary) }
        panel.collectionBehavior = behavior
    }

    private var targetScreen: NSScreen? {
        switch prefs.displayChoice {
        case .builtIn:
            return NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        case .main:
            return NSScreen.screens.first ?? NSScreen.main
        }
    }

    /// Places the panel at the top-centre of the chosen display and measures its notch.
    func reposition() {
        guard let screen = targetScreen else { return }

        let topInset = screen.safeAreaInsets.top
        var notchWidth: CGFloat = 200
        if topInset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchWidth = screen.frame.width - left.width - right.width
        }
        let height = topInset > 0 ? topInset : max(screen.frame.maxY - screen.visibleFrame.maxY, 24)

        model.hasNotch = topInset > 0
        model.notchSize = CGSize(width: notchWidth, height: height)

        let size = Self.panelSize
        panel.setFrame(NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        ), display: true)
    }

    // MARK: - Mouse tracking

    private func trackMouse() {
        let mouse = NSEvent.mouseLocation
        let buttonDown = NSEvent.pressedMouseButtons & 1 != 0

        // Detect a drag in progress (e.g. a file from Finder) via the drag pasteboard.
        let dragCount = NSPasteboard(name: .drag).changeCount
        if !buttonDown {
            lastDragCount = dragCount
            isDragging = false
        } else if dragCount != lastDragCount {
            isDragging = true
        }
        let draggingToShelf = isDragging && prefs.shelfEnabled && prefs.shelfOpenOnDrag

        let size = model.currentSize
        let width = size.width + 2 * model.topRadius
        let frame = panel.frame
        var rect = NSRect(x: frame.midX - width / 2, y: frame.maxY - size.height, width: width, height: size.height)
            .insetBy(dx: -6, dy: -6)
        if draggingToShelf && !model.isOpen {
            rect = rect.insetBy(dx: -60, dy: -30)
        }

        let inside = rect.contains(mouse)
        if panel.ignoresMouseEvents == inside {
            panel.ignoresMouseEvents = !inside
        }

        let now = Date()
        if inside {
            leftSince = nil
            guard !model.isOpen else { return }
            if draggingToShelf {
                model.open(tab: .shelf)
                return
            }
            guard prefs.openMode == .hover, !buttonDown else {
                hoverSince = nil
                return
            }
            if let since = hoverSince {
                if now.timeIntervalSince(since) >= prefs.hoverDelay {
                    hoverSince = nil
                    model.open()
                }
            } else {
                hoverSince = now
            }
        } else {
            hoverSince = nil
            // Stay open while a button is held (dragging a file out, scrubbing, etc.).
            guard model.isOpen, !buttonDown else {
                leftSince = nil
                return
            }
            if let since = leftSince {
                if now.timeIntervalSince(since) >= prefs.closeDelay {
                    leftSince = nil
                    model.close()
                }
            } else {
                leftSince = now
            }
        }
    }
}
