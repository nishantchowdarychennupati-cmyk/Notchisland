import Foundation
import IOKit.ps

/// Battery state, updated by IOKit power-source notifications (no polling).
final class BatteryMonitor: ObservableObject {
    @Published private(set) var level = 100
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var hasBattery = false
    /// Minutes until empty or full, if macOS has an estimate.
    @Published private(set) var minutesRemaining: Int?

    /// Called when the power adapter is connected (not on launch).
    var onPluggedIn: ((Int) -> Void)?

    private var isFirstRead = true
    private var runLoopSource: CFRunLoopSource?

    init() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.refresh()
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
    }

    var symbolName: String {
        switch level {
        case 88...: return "battery.100"
        case 63..<88: return "battery.75"
        case 38..<63: return "battery.50"
        case 13..<38: return "battery.25"
        default: return "battery.0"
        }
    }

    func refresh() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
            else { continue }

            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = max(info[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
            let newLevel = Int((Double(current) / Double(maximum) * 100).rounded())
            let plugged = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let minutesKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let minutes = info[minutesKey] as? Int
            let remaining = (minutes ?? -1) > 0 ? minutes : nil

            if !hasBattery { hasBattery = true }
            if level != newLevel { level = newLevel }
            if isCharging != charging { isCharging = charging }
            if minutesRemaining != remaining { minutesRemaining = remaining }
            if plugged != isPluggedIn {
                if plugged && !isFirstRead { onPluggedIn?(newLevel) }
                isPluggedIn = plugged
            }
        }
        isFirstRead = false
    }
}
