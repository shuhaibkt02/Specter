import Foundation

/// Snapshot of disk storage capacity and real-time block I/O throughput.
public struct DiskStats: Sendable, Equatable {
    public let totalBytes: UInt64
    public let freeBytes: UInt64
    public let usedBytes: UInt64
    public let readBytesPerSecond: Double
    public let writeBytesPerSecond: Double

    public init(
        totalBytes: UInt64 = 0,
        freeBytes: UInt64 = 0,
        usedBytes: UInt64? = nil,
        readBytesPerSecond: Double = 0.0,
        writeBytesPerSecond: Double = 0.0
    ) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        if let used = usedBytes {
            self.usedBytes = used
        } else {
            self.usedBytes = totalBytes >= freeBytes ? totalBytes - freeBytes : 0
        }
        self.readBytesPerSecond = max(readBytesPerSecond, 0.0)
        self.writeBytesPerSecond = max(writeBytesPerSecond, 0.0)
    }

    /// Fraction of volume capacity in use (clamped to 0.0 ... 1.0).
    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0.0), 1.0)
    }

    /// User-facing percentage string (e.g. "32%").
    public var percentageString: String {
        "\(Int(round(usedFraction * 100.0)))%"
    }

    /// Formatted gigabyte string for used capacity (e.g. "158.8 GB").
    public var formattedUsedGB: String {
        Self.formatGigabytes(usedBytes)
    }

    /// Formatted gigabyte string for total capacity (e.g. "494.3 GB").
    public var formattedTotalGB: String {
        Self.formatGigabytes(totalBytes)
    }

    /// Formatted gigabyte string for available capacity (e.g. "335.5 GB").
    public var formattedFreeGB: String {
        Self.formatGigabytes(freeBytes)
    }

    /// Formatted throughput rate for disk reads in MB/s (e.g. "12.4 MB/s").
    public var formattedReadMBs: String {
        Self.formatMegabytesPerSecond(readBytesPerSecond)
    }

    /// Formatted throughput rate for disk writes in MB/s (e.g. "4.1 MB/s").
    public var formattedWriteMBs: String {
        Self.formatMegabytesPerSecond(writeBytesPerSecond)
    }

    public var formattedRead: String {
        formattedReadMBs
    }

    public var formattedWrite: String {
        formattedWriteMBs
    }

    public static func formatGigabytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }

    public static func formatMegabytesPerSecond(_ bytesPerSec: Double) -> String {
        let mbs = max(bytesPerSec, 0.0) / 1_048_576.0
        return String(format: "%.1f MB/s", mbs)
    }
}
