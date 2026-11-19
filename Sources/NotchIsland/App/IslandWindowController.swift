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
    private var scrollX: CGFloat = 0
    private var scrollY: CGFloat = 0
    private var gestureConsumed = false
    private var scrollingTabs = false
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
        // Scroll events only reach us while the cursor is over the island, so this costs nothing elsewhere.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask.union(.scrollWheel), handler: { [weak self] event in
            guard let self else { return event }
            if event.type == .scrollWheel {
                return self.handleScroll(event) ? nil : event
            }
            self.handle(event)
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

    // MARK: - Trackpad gestures

    /// Two-finger swipes: left/right switches tabs, down opens the island, up (on the header) closes it.
    ///
    /// In continuous mode the tabs behave like a slider: they keep advancing as the fingers travel
    /// (one tab per "step"), and the flick's momentum carries on through more tabs.
    /// Returns true when the event was used and shouldn't reach the content.
    private func handleScroll(_ event: NSEvent) -> Bool {
        guard event.hasPreciseScrollingDeltas else { return false } // trackpad / Magic Mouse only
        let continuous = prefs.swipeStyle == .continuous
        let isMomentum = !event.momentumPhase.isEmpty

        if isMomentum {
            // Momentum only matters for a continuous tab swipe that is already under way.
            guard scrollingTabs && continuous && prefs.swipeMomentum && model.isOpen else {
                return gestureConsumed || scrollingTabs
            }
            if event.momentumPhase == .ended || event.momentumPhase == .cancelled {
                finishSwipe()
                return true
            }
        } else {
            if event.phase == .began || event.phase == .mayBegin {
                scrollX = 0
                scrollY = 0
                gestureConsumed = false
                scrollingTabs = false
            }
            if event.phase == .ended || event.phase == .cancelled {
                let consumed = gestureConsumed || scrollingTabs
                scrollY = 0
                // Keep the swipe alive for momentum; otherwise settle now.
                if !(scrollingTabs && continuous && prefs.swipeMomentum) { finishSwipe() }
                return consumed
            }
            if gestureConsumed { return true }
        }

        // Finger movement, independent of the natural-scrolling setting (right and down are positive).
        let inverted = event.isDirectionInvertedFromDevice
        let fingerX = inverted ? event.scrollingDeltaX : -event.scrollingDeltaX
        let fingerY = inverted ? event.scrollingDeltaY : -event.scrollingDeltaY
        scrollX += fingerX
        scrollY += fingerY

        let horizontal = abs(scrollX) > abs(scrollY) * 1.3
        let vertical = abs(scrollY) > abs(scrollX) * 1.3
        let mouse = NSEvent.mouseLocation
        let overHeader = mouse.y >= panel.frame.maxY - model.notchSize.height - 4
        let sensitivity = CGFloat(max(prefs.swipeSensitivity, 0.25))
        let flip: Int = prefs.swipeReversed ? -1 : 1

        if model.isOpen && prefs.swipeTabs && (horizontal || scrollingTabs) {
            if !scrollingTabs {
                // Tabs whose content scrolls sideways keep their own scrolling unless you swipe on the header.
                let contentScrollsSideways = model.tab == .clipboard || (model.tab == .shelf && !model.shelf.items.isEmpty)
                if contentScrollsSideways && !overHeader { return false }
            }

            if continuous {
                scrollingTabs = true
                let step = 34 / sensitivity
                while abs(scrollX) >= step {
                    let offset = (scrollX < 0 ? 1 : -1) * flip
                    if model.switchTab(by: offset) {
                        scrollX += scrollX < 0 ? step : -step
                    } else {
                        scrollX = 0 // reached the first/last tab
                        break
                    }
                }
                let progress = Double(max(-1, min(1, -scrollX / step))) * Double(flip)
                if abs(progress - model.swipeProgress) > 0.04 { model.swipeProgress = progress }
                return true
            }

            let threshold = 45 / sensitivity
            guard abs(scrollX) > threshold else { return true }
            model.switchTab(by: (scrollX < 0 ? 1 : -1) * flip)
            gestureConsumed = true
            return true
        }

        if prefs.scrollToOpen && vertical && !scrollingTabs {
            if !model.isOpen && scrollY > 18 {
                model.open()
                gestureConsumed = true
                return true
            }
            if model.isOpen && overHeader && scrollY < -30 {
                model.close()
                gestureConsumed = true
                return true
            }
        }
        return false
    }

    private func finishSwipe() {
        scrollX = 0
        scrollingTabs = false
        if model.swipeProgress != 0 {
            withAnimation(islandSpring) { model.swipeProgress = 0 }
        }
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
