import SwiftUI

/// Popover cockpit card for Battery telemetry adhering to Doc 07 specification.
/// Displays battery percentage with optional charging glyph, charging state text,
/// capacity track bar, and health/condition/time remaining breakdown.
public struct BatteryCardView: View {
    private let coordinator: TelemetryCoordinator?
    public let battery: BatteryStats

    public init(battery: BatteryStats) {
        self.coordinator = nil
        self.battery = battery
    }

    public init(coordinator: TelemetryCoordinator) {
        self.coordinator = coordinator
        self.battery = coordinator.currentBattery
    }

    private var activeBattery: BatteryStats { coordinator?.currentBattery ?? battery }

    public var liveValue: String {
        "\(activeBattery.percentageString)\(activeBattery.isCharging ? " ⚡" : "")"
    }

    public var statusText: String {
        activeBattery.chargingStatusDescription
    }

    public var statusDotColor: Color? {
        guard activeBattery.hasBattery else { return nil }
        if !activeBattery.isCharging && activeBattery.capacityFraction <= 0.10 {
            return DesignTokens.Colors.critical
        } else if !activeBattery.isCharging && activeBattery.capacityFraction <= 0.20 {
            return DesignTokens.Colors.warning
        }
        return nil
    }

    public var breakdownSummary: String {
        var parts: [String] = []
        if let health = activeBattery.healthPercentage {
            parts.append("\(health)% health")
        }
        if let condition = activeBattery.condition, !condition.isEmpty {
            parts.append(condition)
        }
        if let timeRemaining = activeBattery.formattedTimeRemaining {
            parts.append(timeRemaining)
        }
        return parts.joined(separator: " · ")
    }

    public var body: some View {
        CardView(
            title: "Battery",
            value: liveValue,
            statusDotColor: statusDotColor,
            statusText: statusText,
            sparkline: {
                TrackBarView(
                    fraction: activeBattery.capacityFraction,
                    fillColor: (!activeBattery.isCharging && activeBattery.capacityFraction <= 0.10) ? DesignTokens.Colors.critical : .accentColor
                )
            },
            breakdown: {
                if !breakdownSummary.isEmpty {
                    Text(breakdownSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        )
    }
}
