import Foundation

/// Snapshot of an individual process's resource consumption.
public struct ProcessSnapshot: Identifiable, Sendable, Equatable {
    public let id: pid_t
    public let name: String
    public let cpuFraction: Double
    public let ramBytes: UInt64
    public let isUserApp: Bool
    public let groupIdentifier: String?
    public let groupName: String?

    public init(
        id: pid_t,
        name: String,
        cpuFraction: Double,
        ramBytes: UInt64 = 0,
        isUserApp: Bool = true,
        groupIdentifier: String? = nil,
        groupName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.cpuFraction = max(cpuFraction, 0.0)
        self.ramBytes = ramBytes
        self.isUserApp = isUserApp
        self.groupIdentifier = groupIdentifier
        self.groupName = groupName
    }

    /// User-friendly percentage integer (e.g. "15%").
    public var percentageString: String {
        "\(Int((cpuFraction * 100).rounded()))%"
    }

    /// User-friendly RAM usage (e.g. "1.4 GB" or "450 MB").
    public var formattedRAM: String {
        let mb = Double(ramBytes) / 1_048_576.0
        if mb >= 1024.0 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else if mb >= 1.0 {
            return String(format: "%.0f MB", mb)
        } else {
            return "< 1 MB"
        }
    }
}
