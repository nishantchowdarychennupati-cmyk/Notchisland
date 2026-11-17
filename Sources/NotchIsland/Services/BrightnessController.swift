import AppKit
import CoreGraphics

/// Built-in display brightness via the DisplayServices framework (the same API the brightness keys use).
/// The HUD appears only when the brightness keys are pressed.
final class BrightnessController: ObservableObject {
    @Published private(set) var brightness: Float = 0.5
    @Published private(set) var isAvailable = false

    var onChange: ((Float) -> Void)?

    private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (UInt32, Float) -> Int32
    private var getFn: GetFn?
    private var setFn: SetFn?
    private var keyMonitor: Any?
    private var announceUntil = Date.distantPast
    private var lastUserSet = Date.distantPast

    init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") { getFn = unsafeBitCast(sym, to: GetFn.self) }
            if let sym = dlsym(handle, "DisplayServicesSetBrightness") { setFn = unsafeBitCast(sym, to: SetFn.self) }
        }
        if let value = read() {
            brightness = value
            isAvailable = true
        }
    }

    /// Starts watching the brightness keys.
    ///
    /// The HUD is shown only in response to a brightness key press. Automatic brightness (the ambient
    /// light sensor) changes the screen on its own all the time, so reacting to every change made the
    /// HUD pop up by itself. There is also no background polling, which saves power.
    func startMonitoring() {
        guard isAvailable, keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard event.subtype.rawValue == 8 else { return }
            let keyCode = (event.data1 & 0xFFFF0000) >> 16
            let keyDown = ((event.data1 & 0x0000FF00) >> 8) == 0x0A
            guard keyDown, keyCode == 2 || keyCode == 3 else { return }
            self?.brightnessKeyPressed()
        }
    }

    func stopMonitoring() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        announceUntil = .distantPast
    }

    func set(_ value: Float) {
        let v = min(max(value, 0), 1)
        lastUserSet = Date()
        _ = setFn?(builtInDisplay, v)
        brightness = v
    }

    /// Re-reads brightness. Pass `announce: false` to update silently (e.g. when the System tab opens).
    func check(announce: Bool) {
        guard let value = read(), abs(value - brightness) > 0.004 else { return }
        brightness = value
        let fromKey = Date() < announceUntil
        if announce && fromKey && Date().timeIntervalSince(lastUserSet) > 1 { onChange?(value) }
    }

    /// macOS animates the change, so read a few times shortly after the key press.
    private func brightnessKeyPressed() {
        announceUntil = Date().addingTimeInterval(0.8)
        for delay in [0.05, 0.2, 0.45] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.check(announce: true) }
        }
    }

    private func read() -> Float? {
        guard let getFn else { return nil }
        var value: Float = 0
        return getFn(builtInDisplay, &value) == 0 ? value : nil
    }

    private var builtInDisplay: UInt32 {
        var count: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        CGGetOnlineDisplayList(8, &displays, &count)
        return displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }) ?? CGMainDisplayID()
    }
}
