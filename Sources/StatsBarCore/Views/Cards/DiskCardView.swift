import SwiftUI

/// Popover cockpit card for Disk telemetry adhering to Doc 07 specification.
/// Displays storage capacity usage, a storage utilization track bar,
/// and live block I/O read and write throughput.
public struct DiskCardView: View {
    public let disk: DiskStats

    public init(disk: DiskStats) {
        self.disk = disk
    }

    public init(coordinator: TelemetryCoordinator) {
        self.init(disk: coordinator.currentDisk)
    }

    public var liveValue: String {
        "\(disk.formattedUsedGB) / \(disk.formattedTotalGB)"
    }

    public var capacityFraction: Double {
        disk.usedFraction
    }

    public var throughputSummary: String {
        "Read \(disk.formattedReadMBs) · Write \(disk.formattedWriteMBs)"
    }

    public var body: some View {
        CardView(
            title: "Disk",
            value: liveValue,
            sparkline: {
                TrackBarView(fraction: capacityFraction)
            },
            breakdown: {
                Text(throughputSummary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        )
    }
}
