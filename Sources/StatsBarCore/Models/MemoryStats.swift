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
}

/// Snapshot of physical RAM and swap metrics.
public struct MemoryStats: Sendable, Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let pressure: MemoryPressureLevel

    public init(
        usedBytes: UInt64 = 0,
        totalBytes: UInt64 = 0,
        pressure: MemoryPressureLevel = .normal
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
    }

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0.0), 1.0)
    }

    /// Formatted gigabyte string (e.g. "8.2 GB").
    public var formattedUsedGB: String {
        let gb = Double(usedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}
