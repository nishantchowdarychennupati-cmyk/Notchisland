import Darwin
import Foundation
import IOKit

/// CPU, GPU, memory and network usage. Sampled only while the System tab is on screen.
final class SystemStats: ObservableObject {
    @Published private(set) var cpu: Double = 0          // 0...1
    @Published private(set) var gpu: Double?             // 0...1
    @Published private(set) var memoryUsed: Double = 0   // bytes
    @Published private(set) var memoryTotal: Double = Double(ProcessInfo.processInfo.physicalMemory)
    @Published private(set) var downBytesPerSec: Double = 0
    @Published private(set) var upBytesPerSec: Double = 0
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var thermal: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState

    private var timer: Timer?
    private var lastTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var lastNet: (down: UInt64, up: UInt64, time: Date)?
    private let queue = DispatchQueue(label: "notchisland.stats", qos: .utility)

    var memoryFraction: Double { memoryTotal > 0 ? memoryUsed / memoryTotal : 0 }

    func start(interval: Double) {
        stop()
        sample()
        let t = Timer(timeInterval: max(interval, 1), repeats: true) { [weak self] _ in self?.sample() }
        t.tolerance = interval * 0.25
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastNet = nil
    }

    private func sample() {
        queue.async { [weak self] in
            guard let self else { return }
            let cpu = self.readCPU()
            let mem = Self.readMemory()
            let net = Self.readNetwork()
            let gpu = Self.readGPU()
            DispatchQueue.main.async {
                if let cpu {
                    self.cpu = cpu
                    self.cpuHistory = Array((self.cpuHistory + [cpu]).suffix(30))
                }
                if let mem { self.memoryUsed = mem }
                self.gpu = gpu
                let now = Date()
                if let last = self.lastNet, net.down >= last.down, net.up >= last.up {
                    let dt = max(now.timeIntervalSince(last.time), 0.1)
                    self.downBytesPerSec = Double(net.down - last.down) / dt
                    self.upBytesPerSec = Double(net.up - last.up) / dt
                }
                self.lastNet = (net.down, net.up, now)
                self.thermal = ProcessInfo.processInfo.thermalState
            }
        }
    }

    private func readCPU() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = (user: UInt64(info.cpu_ticks.0), system: UInt64(info.cpu_ticks.1),
                     idle: UInt64(info.cpu_ticks.2), nice: UInt64(info.cpu_ticks.3))
        defer { lastTicks = ticks }
        guard let last = lastTicks else { return nil }
        let used = Double((ticks.user &- last.user) &+ (ticks.system &- last.system) &+ (ticks.nice &- last.nice))
        let total = used + Double(ticks.idle &- last.idle)
        return total > 0 ? used / total : nil
    }

    private static func readMemory() -> Double? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = Double(getpagesize())
        let appMemory = Double(stats.internal_page_count) - Double(stats.purgeable_count)
        return (appMemory + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
    }

    private static func readNetwork() -> (down: UInt64, up: UInt64) {
        var down: UInt64 = 0
        var up: UInt64 = 0
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0 else { return (0, 0) }
        defer { freeifaddrs(addresses) }
        var pointer = addresses
        while let entry = pointer {
            let name = String(cString: entry.pointee.ifa_name)
            if name.hasPrefix("en"),
               let addr = entry.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
               let data = entry.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                down += UInt64(data.pointee.ifi_ibytes)
                up += UInt64(data.pointee.ifi_obytes)
            }
            pointer = entry.pointee.ifa_next
        }
        return (down, up)
    }

    private static func readGPU() -> Double? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var result: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any],
               let utilization = perf["Device Utilization %"] as? Int {
                result = Double(utilization) / 100
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }
}

func formatBytes(_ bytes: Double, perSecond: Bool = false) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = perSecond ? .binary : .memory
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    let text = formatter.string(fromByteCount: Int64(max(bytes, 0)))
    return perSecond ? text + "/s" : text
}
