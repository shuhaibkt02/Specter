import Foundation

/// Snapshot of aggregate CPU utilization.
public struct CPUStats: Sendable, Equatable {
    public let usageFraction: Double

    public init(usageFraction: Double = 0.0) {
        self.usageFraction = min(max(usageFraction, 0.0), 1.0)
    }

    /// User-friendly percentage integer (0% to 100%).
    public var percentageString: String {
        "\(Int((usageFraction * 100).rounded()))%"
    }
}
