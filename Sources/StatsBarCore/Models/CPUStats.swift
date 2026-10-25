import Foundation

/// Snapshot of CPU utilization.
public struct CPUStats: Sendable, Equatable {
    /// Overall CPU usage fraction between 0.0 and 1.0.
    public let usageFraction: Double
    /// Total number of logical cores detected.
    public let logicalCoreCount: Int

    public init(usageFraction: Double = 0.0, logicalCoreCount: Int = 1) {
        self.usageFraction = min(max(usageFraction, 0.0), 1.0)
        self.logicalCoreCount = max(logicalCoreCount, 1)
    }

    /// User-friendly percentage integer (0 to 100).
    public var percentageString: String {
        "\(Int((usageFraction * 100).rounded()))%"
    }
}
