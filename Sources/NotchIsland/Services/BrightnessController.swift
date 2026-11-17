import AppKit
import CoreGraphics

/// Built-in display brightness via the DisplayServices framework (the same API the brightness keys use).
/// Changes are detected from the brightness keys, with a relaxed fallback check.
final class BrightnessController: ObservableObject {
    @Published private(set) var brightness: Float = 0.5
    @Published private(set) var isAvailable = false

    var onChange: ((Float) -> Void)?

    private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (UInt32, Float) -> Int32
    private var getFn: GetFn?
    private var setFn: SetFn?
    private var keyMonitor: Any?
    private var fallbackTimer: Timer?
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

    /// Starts watching for changes. Cheap: an event monitor for the brightness keys,
    /// plus a 2-second check (with generous timer tolerance) for changes from Control Center.
    func startMonitoring() {
        guard isAvailable, keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard event.subtype.rawValue == 8 else { return }
            let keyCode = (event.data1 & 0xFFFF0000) >> 16
            if keyCode == 2 || keyCode == 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { self?.check(announce: true) }
            }
        }
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.check(announce: true) }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        fallbackTimer = t
    }

    func stopMonitoring() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    func set(_ value: Float) {
        let v = min(max(value, 0), 1)
        lastUserSet = Date()
        _ = setFn?(builtInDisplay, v)
        brightness = v
    }

    func check(announce: Bool) {
        guard let value = read(), abs(value - brightness) > 0.004 else { return }
        brightness = value
        if announce && Date().timeIntervalSince(lastUserSet) > 1 { onChange?(value) }
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
