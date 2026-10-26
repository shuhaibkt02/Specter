import Foundation
import Darwin

/// Queries live CPU statistics directly from the Mach kernel in-process.
public final class CPUCollector: @unchecked Sendable {
    private var previousTicks: host_cpu_load_info?
    private var previousPerCoreTicks: [processor_cpu_load_info]?
    public let pCoreCount: Int
    public let eCoreCount: Int

    public init() {
        var pCount: Int32 = 0
        var eCount: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.perflevel0.logicalcpu", &pCount, &size, nil, 0)
        sysctlbyname("hw.perflevel1.logicalcpu", &eCount, &size, nil, 0)
        self.pCoreCount = max(Int(pCount), 0)
        self.eCoreCount = max(Int(eCount), 0)
    }

    /// Samples aggregate CPU ticks and calculates utilization since the last sample.
    public func sample() -> CPUStats {
        guard let currentTicks = Self.readHostCPULoadInfo() else {
            return CPUStats(usageFraction: 0.0)
        }

        guard let prev = previousTicks else {
            previousTicks = currentTicks
            return CPUStats(usageFraction: 0.0)
        }

        previousTicks = currentTicks
        let usage = Self.calculateUsage(previous: prev, current: currentTicks)
        return CPUStats(usageFraction: usage)
    }

    /// Samples per-core utilization and partitions into Performance (P) and Efficiency (E) clusters.
    public func samplePerCore() -> (pUsage: Double, eUsage: Double, perCore: [Double]) {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        let result = host_processor_info(hostPort, PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo)
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return (0.0, 0.0, [])
        }

        let cpuCount = Int(numCPUsU)
        var currentTicks: [processor_cpu_load_info] = []
        currentTicks.reserveCapacity(cpuCount)

        for i in 0..<cpuCount {
            let offset = Int(CPU_STATE_MAX) * i
            let ticks = (
                UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_USER)]),
                UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_IDLE)]),
                UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_NICE)])
            )
            var pInfo = processor_cpu_load_info()
            pInfo.cpu_ticks = ticks
            currentTicks.append(pInfo)
        }

        // Cleanly deallocate Mach buffer to prevent memory leaks
        let deallocSize = MemoryLayout<integer_t>.stride * Int(numCpuInfo)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(deallocSize))

        guard let prev = previousPerCoreTicks, prev.count == cpuCount else {
            previousPerCoreTicks = currentTicks
            return (0.0, 0.0, [Double](repeating: 0.0, count: cpuCount))
        }

        previousPerCoreTicks = currentTicks
        var perCore: [Double] = []
        perCore.reserveCapacity(cpuCount)

        for i in 0..<cpuCount {
            let user = Double(currentTicks[i].cpu_ticks.0 &- prev[i].cpu_ticks.0)
            let sys  = Double(currentTicks[i].cpu_ticks.1 &- prev[i].cpu_ticks.1)
            let idle = Double(currentTicks[i].cpu_ticks.2 &- prev[i].cpu_ticks.2)
            let nice = Double(currentTicks[i].cpu_ticks.3 &- prev[i].cpu_ticks.3)
            let inUse = user + sys + nice
            let total = inUse + idle
            perCore.append(total > 0 ? min(max(inUse / total, 0.0), 1.0) : 0.0)
        }

        let pUsages = Array(perCore.prefix(pCoreCount))
        let eUsages = Array(perCore.dropFirst(pCoreCount).prefix(eCoreCount))

        let pAvg = pUsages.isEmpty ? 0.0 : pUsages.reduce(0.0, +) / Double(pUsages.count)
        let eAvg = eUsages.isEmpty ? 0.0 : eUsages.reduce(0.0, +) / Double(eUsages.count)

        return (pAvg, eAvg, perCore)
    }

    /// Calculates CPU usage fraction from tick state transitions.
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
