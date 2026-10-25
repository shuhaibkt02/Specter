import Foundation
import Darwin

/// Queries live CPU statistics directly from the Mach kernel.
/// Runs in-process with zero subprocess spawning and sub-millisecond execution time.
public final class CPUCollector: @unchecked Sendable {
    private var previousTicks: host_cpu_load_info?
    private let lock = NSLock()
    public let logicalCoreCount: Int

    public init(logicalCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.logicalCoreCount = max(logicalCoreCount, 1)
    }

    /// Samples aggregate CPU ticks and calculates utilization since the last sample.
    public func sample() -> CPUStats {
        lock.lock()
        defer { lock.unlock() }

        guard let currentTicks = Self.readHostCPULoadInfo() else {
            return CPUStats(usageFraction: 0.0, logicalCoreCount: logicalCoreCount)
        }

        guard let prev = previousTicks else {
            // First tick baseline: store and return 0.0 until second tick establishes delta
            previousTicks = currentTicks
            return CPUStats(usageFraction: 0.0, logicalCoreCount: logicalCoreCount)
        }

        previousTicks = currentTicks
        let usage = Self.calculateUsage(previous: prev, current: currentTicks)
        return CPUStats(usageFraction: usage, logicalCoreCount: logicalCoreCount)
    }

    /// Pure function calculating CPU usage fraction from tick state transitions.
    public static func calculateUsage(previous: host_cpu_load_info, current: host_cpu_load_info) -> Double {
        let userDiff   = Double(current.cpu_ticks.0 &- previous.cpu_ticks.0)
        let sysDiff    = Double(current.cpu_ticks.1 &- previous.cpu_ticks.1)
        let idleDiff   = Double(current.cpu_ticks.2 &- previous.cpu_ticks.2)
        let niceDiff   = Double(current.cpu_ticks.3 &- previous.cpu_ticks.3)

        let inUseTicks = userDiff + sysDiff + niceDiff
        let totalTicks = inUseTicks + idleDiff

        guard totalTicks > 0 else { return 0.0 }
        let fraction = inUseTicks / totalTicks
        guard !fraction.isNaN && fraction.isFinite else { return 0.0 }
        return min(max(fraction, 0.0), 1.0)
    }

    /// Reads raw Mach kernel host statistics for aggregate CPU load.
    public static func readHostCPULoadInfo() -> host_cpu_load_info? {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        
        let hostPort = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, hostPort)
        }

        let result: kern_return_t = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }
        return cpuInfo
    }
}
