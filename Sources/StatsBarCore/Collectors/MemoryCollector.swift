import Foundation
import Darwin

/// Queries live memory metrics directly from the Mach kernel and Darwin BSD sysctls.
public final class MemoryCollector: Sendable {
    public let totalPhysicalMemory: UInt64

    /// System virtual memory page size in bytes (typically 16,384 bytes on Apple Silicon).
    public static var pageSize: UInt64 {
        UInt64(getpagesize())
    }

    public init(totalPhysicalMemory: UInt64 = MemoryCollector.readTotalPhysicalMemory()) {
        self.totalPhysicalMemory = totalPhysicalMemory
    }

    /// Samples live virtual memory breakdown, memory pressure, and swap usage.
    public func sample() -> MemoryStats {
        guard let vmStats = Self.readVMStatistics() else {
            return MemoryStats(
                usedBytes: 0,
                totalBytes: totalPhysicalMemory,
                pressure: .normal
            )
        }

        let ps = Self.pageSize
        let active = UInt64(vmStats.active_count) * ps
        let inactive = UInt64(vmStats.inactive_count) * ps
        let speculative = UInt64(vmStats.speculative_count) * ps
        let wired = UInt64(vmStats.wire_count) * ps
        let compressed = UInt64(vmStats.compressor_page_count) * ps
        let purgeable = UInt64(vmStats.purgeable_count) * ps
        let external = UInt64(vmStats.external_page_count) * ps
        let free = UInt64(vmStats.free_count) * ps

        let used = Self.calculateUsedBytes(
            active: active,
            inactive: inactive,
            speculative: speculative,
            wired: wired,
            compressed: compressed,
            purgeable: purgeable,
            external: external
        )
        let clampedUsed = min(used, totalPhysicalMemory)

        let pressure = Self.readMemoryPressure()
        let swap = Self.readSwapUsage()

        return MemoryStats(
            usedBytes: clampedUsed,
            totalBytes: totalPhysicalMemory,
            pressure: pressure,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            purgeableBytes: purgeable,
            externalBytes: external,
            freeBytes: free,
            swap: swap
        )
    }

    /// Calculates used memory bytes based on Darwin virtual memory breakdown:
    /// Used = (Active + Inactive + Speculative + Wired + Compressed) - (Purgeable + External)
    public static func calculateUsedBytes(
        active: UInt64,
        inactive: UInt64,
        speculative: UInt64,
        wired: UInt64,
        compressed: UInt64,
        purgeable: UInt64,
        external: UInt64
    ) -> UInt64 {
        let gross = active + inactive + speculative + wired + compressed
        let reclaimable = purgeable + external
        return gross > reclaimable ? (gross - reclaimable) : 0
    }

    /// Calculates used memory directly from a `vm_statistics64` structure and given page size.
    public static func calculateUsedBytes(
        vmStats: vm_statistics64,
        pageSize: UInt64? = nil
    ) -> UInt64 {
        let size = pageSize ?? Self.pageSize
        return calculateUsedBytes(
            active: UInt64(vmStats.active_count) * size,
            inactive: UInt64(vmStats.inactive_count) * size,
            speculative: UInt64(vmStats.speculative_count) * size,
            wired: UInt64(vmStats.wire_count) * size,
            compressed: UInt64(vmStats.compressor_page_count) * size,
            purgeable: UInt64(vmStats.purgeable_count) * size,
            external: UInt64(vmStats.external_page_count) * size
        )
    }

    /// Queries the Mach kernel for 64-bit virtual memory statistics (`HOST_VM_INFO64`).
    /// Deallocates the Mach host port on exit to prevent port right leaks.
    public static func readVMStatistics() -> vm_statistics64? {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let hostPort = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, hostPort)
        }

        let result: kern_return_t = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }
        return vmStats
    }

    /// Queries system memory pressure level via BSD sysctl `kern.memorystatus_vm_pressure_level`.
    public static func readMemoryPressure() -> MemoryPressureLevel {
        var pressureLevel: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0) == 0 {
            return MemoryPressureLevel(level: pressureLevel)
        }
        return .normal
    }

    /// Queries system virtual swap allocation and usage via BSD sysctl `vm.swapusage`.
    public static func readSwapUsage() -> SwapStats {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
            return SwapStats(
                usedBytes: swap.xsu_used,
                totalBytes: swap.xsu_total
            )
        }
        return SwapStats(usedBytes: 0, totalBytes: 0)
    }

    /// Reads total installed physical RAM in bytes via sysctl `hw.memsize`, falling back to `ProcessInfo`.
    public static func readTotalPhysicalMemory() -> UInt64 {
        var memsize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &memsize, &size, nil, 0) == 0 {
            return memsize
        }
        return ProcessInfo.processInfo.physicalMemory
    }
}
