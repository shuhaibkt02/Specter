import SwiftUI

/// Popover cockpit card for Network telemetry adhering to Doc 07 specification.
/// Displays live download and upload transfer rates, throughput sparkline,
/// and the active physical interface and IP label.
public struct NetworkCardView: View {
    public let network: NetworkStats
    public let history: [Double]

    public init(network: NetworkStats, history: [Double] = []) {
        self.network = network
        self.history = history
    }

    public init(coordinator: TelemetryCoordinator) {
        self.init(network: coordinator.currentNetwork, history: coordinator.networkHistory)
    }

    public var liveValue: String {
        "↓ \(network.formattedDownload)  ↑ \(network.formattedUpload)"
    }

    public var interfaceLabel: String {
        network.breakdownDescription
    }

    public var body: some View {
        CardView(
            title: "Network",
            value: liveValue,
            sparkline: {
                SparklineView(values: history)
            },
            breakdown: {
                Text(interfaceLabel)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        )
    }
}
