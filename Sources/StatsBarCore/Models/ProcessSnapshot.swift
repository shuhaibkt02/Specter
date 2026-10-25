import Foundation

/// Snapshot of an individual process's resource consumption.
public struct ProcessSnapshot: Identifiable, Sendable, Equatable {
    public let id: pid_t
    public let name: String
    public let cpuFraction: Double

    public init(id: pid_t, name: String, cpuFraction: Double) {
        self.id = id
        self.name = name
        self.cpuFraction = max(cpuFraction, 0.0)
    }

    /// User-friendly percentage integer (e.g. "15%").
    public var percentageString: String {
        "\(Int((cpuFraction * 100).rounded()))%"
    }
}
