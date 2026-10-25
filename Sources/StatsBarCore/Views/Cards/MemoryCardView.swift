import SwiftUI

/// Popover cockpit card for Memory telemetry adhering to Doc 07 specification.
/// Displays physical memory usage, pressure level status indicator dot + text,
/// 60s memory sparkline, Wired/Active/Compressed/Cached breakdown, and Swap usage.
public struct MemoryCardView: View {
    public let memory: MemoryStats
    public let history: [Double]

    public init(memory: MemoryStats, history: [Double] = []) {
        self.memory = memory
        self.history = history
    }

    public init(coordinator: TelemetryCoordinator) {
        self.init(memory: coordinator.currentMemory, history: coordinator.memoryHistory)
    }

    public var liveValue: String {
        "\(memory.formattedUsedGB) / \(memory.formattedTotalGB)"
    }

    public var statusDotColor: Color {
        switch memory.pressure {
        case .normal: return DesignTokens.Colors.normal
        case .warning: return DesignTokens.Colors.warning
        case .critical: return DesignTokens.Colors.critical
        }
    }

    public var statusText: String {
        switch memory.pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    public var breakdownSummary: String {
        "Wired \(memory.formattedWiredGB) · Active \(memory.formattedActiveGB) · Compressed \(memory.formattedCompressedGB) · Cached \(memory.formattedCachedGB)"
    }

    public var swapSummary: String {
        "Swap \(memory.swap.usedBytes == 0 ? "0 B" : memory.swap.formattedUsedGB)"
    }

    public var body: some View {
        CardView(
            title: "Memory",
            value: liveValue,
            statusDotColor: statusDotColor,
            statusText: statusText,
            sparkline: {
                SparklineView(values: history)
            },
            breakdown: {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxSmall) {
                    Text(breakdownSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(swapSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        )
    }
}
