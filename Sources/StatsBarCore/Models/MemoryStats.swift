import Foundation

/// Memory pressure classifications matching BSD `kern.memorystatus_vm_pressure_level`.
public enum MemoryPressureLevel: String, Sendable, Equatable {
    case normal
    case warning
    case critical

    public init(level: Int) {
        switch level {
        case 2: self = .warning
        case 4: self = .critical
        default: self = .normal
        }
    }

    public init(level: Int32) {
        self.init(level: Int(level))
    }
}

/// Snapshot of system virtual swap disk allocation and utilization.
public struct SwapStats: Sendable, Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64

    public init(usedBytes: UInt64 = 0, totalBytes: UInt64 = 0) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    /// Available / unallocated swap disk space in bytes.
    public var availableBytes: UInt64 {
        totalBytes > usedBytes ? (totalBytes - usedBytes) : 0
    }

    /// Swap utilization fraction bounded between 0.0 and 1.0.
    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0.0), 1.0)
    }

    /// Formatted gigabyte string for used swap (e.g. "0.5 GB").
    public var formattedUsedGB: String {
        let gb = Double(usedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }

    /// Formatted gigabyte string for total swap allocation (e.g. "2.0 GB").
    public var formattedTotalGB: String {
        let gb = Double(totalBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}

/// Snapshot of physical RAM and swap metrics.
public struct MemoryStats: Sendable, Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let pressure: MemoryPressureLevel
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let purgeableBytes: UInt64
    public let externalBytes: UInt64
    public let freeBytes: UInt64
    public let swap: SwapStats

    public init(
        usedBytes: UInt64 = 0,
        totalBytes: UInt64 = 0,
        pressure: MemoryPressureLevel = .normal,
        activeBytes: UInt64 = 0,
        inactiveBytes: UInt64 = 0,
        wiredBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        purgeableBytes: UInt64 = 0,
        externalBytes: UInt64 = 0,
        freeBytes: UInt64 = 0,
        swap: SwapStats = SwapStats()
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.purgeableBytes = purgeableBytes
        self.externalBytes = externalBytes
        self.freeBytes = freeBytes
        self.swap = swap
    }

    public init(
        usedBytes: UInt64,
        totalBytes: UInt64,
        pressure: MemoryPressureLevel = .normal,
        swapUsedBytes: UInt64,
        swapTotalBytes: UInt64
    ) {
        self.init(
            usedBytes: usedBytes,
            totalBytes: totalBytes,
            pressure: pressure,
            swap: SwapStats(usedBytes: swapUsedBytes, totalBytes: swapTotalBytes)
        )
    }

    public var swapUsedBytes: UInt64 { swap.usedBytes }
    public var swapTotalBytes: UInt64 { swap.totalBytes }

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0.0), 1.0)
    }

    /// Formatted gigabyte string (e.g. "8.2 GB").
    public var formattedUsedGB: String {
        let gb = Double(usedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }

    /// Formatted total physical RAM string (e.g. "16.0 GB").
    public var formattedTotalGB: String {
        let gb = Double(totalBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}
