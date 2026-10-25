import Foundation

/// Snapshot of network bandwidth rates.
public struct NetworkStats: Sendable, Equatable {
    public let uploadBytesPerSecond: Double
    public let downloadBytesPerSecond: Double

    public init(uploadBytesPerSecond: Double = 0.0, downloadBytesPerSecond: Double = 0.0) {
        self.uploadBytesPerSecond = max(uploadBytesPerSecond, 0.0)
        self.downloadBytesPerSecond = max(downloadBytesPerSecond, 0.0)
    }

    /// Formats bytes per second into human-readable rate (e.g. "1.2 MB/s", "45 KB/s").
    public static func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576.0 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576.0)
        } else if bytesPerSec >= 1_024.0 {
            return String(format: "%.0f KB/s", bytesPerSec / 1_024.0)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }

    public var formattedDownload: String {
        Self.formatRate(downloadBytesPerSecond)
    }

    public var formattedUpload: String {
        Self.formatRate(uploadBytesPerSecond)
    }
}
