import SwiftUI

/// Popover cockpit card for Network telemetry adhering to Doc 07 specification.
/// Displays live download and upload transfer rates, throughput sparkline,
/// and the active physical interface and IP label.
public struct NetworkCardView: View {
    private let coordinator: TelemetryCoordinator?
    public let network: NetworkStats
    public let history: [Double]

    public init(network: NetworkStats, history: [Double] = []) {
        self.coordinator = nil
        self.network = network
        self.history = history
    }

    public init(coordinator: TelemetryCoordinator) {
        self.coordinator = coordinator
        self.network = coordinator.currentNetwork
        self.history = coordinator.networkHistory
    }

    private var activeNetwork: NetworkStats { coordinator?.currentNetwork ?? network }
    private var activeHistory: [Double] { coordinator?.networkHistory ?? history }

    public var liveValue: String {
        "↓ \(activeNetwork.formattedDownload)  ↑ \(activeNetwork.formattedUpload)"
    }

    public var interfaceLabel: String {
        activeNetwork.breakdownDescription
    }

    public var body: some View {
        CardView(
            title: "Network",
            value: liveValue,
            sparkline: {
                SparklineView(values: activeHistory)
            },
            breakdown: {
                Text(interfaceLabel)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        )
    }
}
