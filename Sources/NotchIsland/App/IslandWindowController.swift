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

/// Positions the island and decides when it opens and closes.
///
/// Battery: instead of polling the cursor, this reacts to mouse events (global + local monitors),
/// so it does no work at all while the mouse isn't moving.
final class IslandWindowController {
    let model: IslandModel
    private let prefs = Preferences.shared
    private let panel: IslandPanel
    private var monitors: [Any] = []
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var dragCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    private var isButtonDown = false
    private var isDragging = false
    private var cancellables = Set<AnyCancellable>()

    /// Fixed canvas; the island grows inside it. Transparent areas pass clicks through.
    private static let panelSize = NSSize(width: 1000, height: 360)

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
        // When the island changes size under a still cursor, re-check hover state.
        model.$isOpen
            .dropFirst()
            .debounce(for: .milliseconds(450), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.evaluate() }
            .store(in: &cancellables)
    }

    func show() {
        panel.orderFrontRegardless()
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
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

    // MARK: - Mouse handling

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            isButtonDown = true
            isDragging = false
            dragCountAtMouseDown = NSPasteboard(name: .drag).changeCount
        case .leftMouseUp:
            isButtonDown = false
            isDragging = false
        case .leftMouseDragged:
            if NSPasteboard(name: .drag).changeCount != dragCountAtMouseDown { isDragging = true }
        default:
            break
        }
        evaluate()
    }

    private func islandRect(expandedForDrag: Bool) -> NSRect {
        let size = model.currentSize
        let width = size.width + 2 * model.topRadius
        let frame = panel.frame
        var rect = NSRect(x: frame.midX - width / 2, y: frame.maxY - size.height, width: width, height: size.height)
            .insetBy(dx: -6, dy: -6)
        if expandedForDrag { rect = rect.insetBy(dx: -60, dy: -30) }
        return rect
    }

    private func evaluate() {
        let mouse = NSEvent.mouseLocation
        let draggingToShelf = isDragging && prefs.shelfOpenOnDrag && prefs.isEnabled(.shelf)
        let inside = islandRect(expandedForDrag: draggingToShelf && !model.isOpen).contains(mouse)

        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        let hovering = inside && !model.isOpen
        if model.isHovering != hovering { model.isHovering = hovering }

        if inside {
            closeWork?.cancel()
            closeWork = nil
            guard !model.isOpen else { return }
            if draggingToShelf {
                model.open(tab: .shelf)
                return
            }
            guard prefs.openMode == .hover, !isButtonDown, openWork == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.openWork = nil
                if self.islandRect(expandedForDrag: false).contains(NSEvent.mouseLocation) && !self.isButtonDown {
                    self.model.open()
                }
            }
            openWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + prefs.hoverDelay, execute: work)
        } else {
            openWork?.cancel()
            openWork = nil
            // Stay open while a button is held (dragging a file out, scrubbing, etc.).
            guard model.isOpen, !isButtonDown, closeWork == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.closeWork = nil
                if !self.islandRect(expandedForDrag: false).contains(NSEvent.mouseLocation) && !self.isButtonDown {
                    self.model.close()
                }
            }
            closeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + prefs.closeDelay, execute: work)
        }
    }
}
