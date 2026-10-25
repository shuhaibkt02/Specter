import SwiftUI

/// Popover cockpit card for Battery telemetry adhering to Doc 07 specification.
/// Displays battery percentage with optional charging glyph, charging state text,
/// capacity track bar, and health/condition/time remaining breakdown.
public struct BatteryCardView: View {
    public let battery: BatteryStats

    public init(battery: BatteryStats) {
        self.battery = battery
    }

    public init(coordinator: TelemetryCoordinator) {
        self.init(battery: coordinator.currentBattery)
    }

    public var liveValue: String {
        "\(battery.percentageString)\(battery.isCharging ? " ⚡" : "")"
    }

    public var statusText: String {
        battery.chargingStatusDescription
    }

    public var statusDotColor: Color? {
        guard battery.hasBattery else { return nil }
        if !battery.isCharging && battery.capacityFraction <= 0.10 {
            return DesignTokens.Colors.critical
        } else if !battery.isCharging && battery.capacityFraction <= 0.20 {
            return DesignTokens.Colors.warning
        }
        return nil
    }

    public var breakdownSummary: String {
        var parts: [String] = []
        if let health = battery.healthPercentage {
            parts.append("\(health)% health")
        }
        if let condition = battery.condition, !condition.isEmpty {
            parts.append(condition)
        }
        if let timeRemaining = battery.formattedTimeRemaining {
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
                    fraction: battery.capacityFraction,
                    fillColor: (!battery.isCharging && battery.capacityFraction <= 0.10) ? DesignTokens.Colors.critical : .accentColor
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
