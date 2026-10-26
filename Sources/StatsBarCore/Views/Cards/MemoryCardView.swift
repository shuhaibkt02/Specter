import SwiftUI

/// Popover cockpit card for Memory telemetry adhering to Doc 07 specification.
/// Displays physical memory usage, pressure level status indicator dot + text,
/// 60s memory sparkline, Wired/Active/Compressed/Cached breakdown, and Swap usage.
public struct MemoryCardView: View {
    private let coordinator: TelemetryCoordinator?
    public let memory: MemoryStats
    public let history: [Double]

    public init(memory: MemoryStats, history: [Double] = []) {
        self.coordinator = nil
        self.memory = memory
        self.history = history
    }

    public init(coordinator: TelemetryCoordinator) {
        self.coordinator = coordinator
        self.memory = coordinator.currentMemory
        self.history = coordinator.memoryHistory
    }

    private var activeMemory: MemoryStats { coordinator?.currentMemory ?? memory }
    private var activeHistory: [Double] { coordinator?.memoryHistory ?? history }

    public var liveValue: String {
        "\(activeMemory.formattedUsedGB) / \(activeMemory.formattedTotalGB)"
    }

    public var statusDotColor: Color {
        switch activeMemory.pressure {
        case .normal: return DesignTokens.Colors.normal
        case .warning: return DesignTokens.Colors.warning
        case .critical: return DesignTokens.Colors.critical
        }
    }

    public var statusText: String {
        switch activeMemory.pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    public var breakdownSummary: String {
        "Wired \(activeMemory.formattedWiredGB) · Active \(activeMemory.formattedActiveGB) · Compressed \(activeMemory.formattedCompressedGB) · Cached \(activeMemory.formattedCachedGB)"
    }

    public var swapSummary: String {
        "Swap \(activeMemory.swap.usedBytes == 0 ? "0 B" : activeMemory.swap.formattedUsedGB)"
    }

    public var body: some View {
        CardView(
            title: "Memory",
            value: liveValue,
            statusDotColor: statusDotColor,
            statusText: statusText,
            sparkline: {
                SparklineView(values: activeHistory)
            },
            breakdown: {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                    Text(breakdownSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)

                    Text(swapSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        )
    }
}
