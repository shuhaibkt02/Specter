import SwiftUI

/// Popover cockpit card for Disk telemetry adhering to Doc 07 specification.
/// Displays storage capacity usage, a storage utilization track bar,
/// and live block I/O read and write throughput.
public struct DiskCardView: View {
    private let coordinator: TelemetryCoordinator?
    public let disk: DiskStats

    public init(disk: DiskStats) {
        self.coordinator = nil
        self.disk = disk
    }

    public init(coordinator: TelemetryCoordinator) {
        self.coordinator = coordinator
        self.disk = coordinator.currentDisk
    }

    private var activeDisk: DiskStats { coordinator?.currentDisk ?? disk }

    public var liveValue: String {
        "\(activeDisk.formattedUsedGB) / \(activeDisk.formattedTotalGB)"
    }

    public var capacityFraction: Double {
        activeDisk.usedFraction
    }

    public var throughputSummary: String {
        "Read \(activeDisk.formattedReadMBs) · Write \(activeDisk.formattedWriteMBs)"
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
