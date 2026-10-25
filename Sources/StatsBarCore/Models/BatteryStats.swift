import Foundation

/// Snapshot of system battery telemetry and power source state.
public struct BatteryStats: Sendable, Equatable {
    /// Normalized capacity fraction between 0.0 and 1.0.
    public let capacityFraction: Double
    /// Whether the battery is actively charging.
    public let isCharging: Bool
    /// Whether the Mac is currently connected to AC mains power.
    public let isACPower: Bool
    /// Estimated time remaining in minutes (to empty if discharging, or to full charge if charging).
    public let timeRemainingMinutes: Int?
    /// User-friendly percentage integer (e.g. "95%").
    public let percentageString: String
    /// Whether the device has a physical internal battery (false on desktops like Mac mini, Mac Studio, Mac Pro).
    public let hasBattery: Bool

    public init(
        capacityFraction: Double = 0.0,
        isCharging: Bool = false,
        isACPower: Bool = true,
        timeRemainingMinutes: Int? = nil,
        percentageString: String? = nil,
        hasBattery: Bool = true
    ) {
        let clamped = min(max(capacityFraction, 0.0), 1.0)
        self.capacityFraction = clamped
        self.isCharging = isCharging
        self.isACPower = isACPower
        self.timeRemainingMinutes = timeRemainingMinutes
        self.percentageString = percentageString ?? "\(Int((clamped * 100).rounded()))%"
        self.hasBattery = hasBattery
    }

    /// Formatted human-readable time remaining string (e.g. "2h 30m", "45m", or nil if calculating/unavailable).
    public var formattedTimeRemaining: String? {
        guard let minutes = timeRemainingMinutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    /// Canonical representation for desktop Mac hardware without an internal battery.
    public static let noBattery = BatteryStats(
        capacityFraction: 0.0,
        isCharging: false,
        isACPower: true,
        timeRemainingMinutes: nil,
        percentageString: "0%",
        hasBattery: false
    )
}
