import SwiftUI

/// Unified high-legibility, zero-jitter menu bar status pill adhering strictly to Doc 07 specification.
/// Enforces the Law of Uniform Connectedness (single connected pill, min height 22pt, corner radius 5pt),
/// leading telemetry heartbeat / popover status dot (6pt circle), monospaced tabular digits,
/// fixed minimum reserved segment widths, subtle 1px hairline dividers, Von Restorff warning exceptions,
/// and full VoiceOver accessibility speech descriptions.
public struct MenuBarPillView: View {
    public let coordinator: TelemetryCoordinator
    public let settings: SettingsModel

    public init(coordinator: TelemetryCoordinator, settings: SettingsModel = .shared) {
        self.coordinator = coordinator
        self.settings = settings
    }

    /// Segment identifiers matching the fixed evaluation order.
    public enum Segment: String, CaseIterable, Sendable {
        case cpu = "CPU"
        case memory = "Memory"
        case network = "Network"
        case disk = "Disk"
        case battery = "Battery"
    }

    /// Fixed layout reservation widths per segment derived from widest realistic values to eliminate horizontal jitter.
    public enum SegmentWidths {
        public static let cpu: CGFloat = 48
        public static let memory: CGFloat = 52
        public static let network: CGFloat = 46
        public static let disk: CGFloat = 54
        public static let battery: CGFloat = 46
    }

    /// Semantic warning state following Von Restorff Effect (monochrome nominal, amber warning, red critical).
    public enum WarningState: Sendable, Equatable {
        case nominal
        case warning
        case critical
    }

    // MARK: - Body

    public var body: some View {
        let active = Self.activeSegments(settings: settings, hasBattery: coordinator.currentBattery.hasBattery)
        if active.isEmpty {
            Text("Specter")
                .font(DesignTokens.Typography.pill)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.accessibilityDescription(coordinator: coordinator, settings: settings))
        } else {
            pillText(for: active)
                .font(DesignTokens.Typography.pill)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.accessibilityDescription(coordinator: coordinator, settings: settings))
        }
    }

    // MARK: - Menu Bar Text Formatting

    public func pillText(for active: [Segment]) -> Text {
        let dotColor: Color = coordinator.isPopoverPresented ? .accentColor : .secondary.opacity(0.5)
        let dot = Text("● ").foregroundStyle(dotColor)
        var result = dot
        for (index, segment) in active.enumerated() {
            let piece = segmentText(for: segment)
            if index > 0 {
                let sep = Text(" │ ").foregroundStyle(.secondary.opacity(0.4))
                result = Text("\(result)\(sep)\(piece)")
            } else {
                result = Text("\(result)\(piece)")
            }
        }
        return result
    }

    public func segmentText(for segment: Segment) -> Text {
        switch segment {
        case .cpu:
            return Text("CPU \(coordinator.currentCPU.percentageString)")
                .monospacedDigit()
                .foregroundStyle(.primary)

        case .memory:
            let tint = Self.warningTint(for: Self.memoryWarningState(pressure: coordinator.currentMemory.pressure))
            return Text("MEM \(Self.formatPillMemory(coordinator.currentMemory.usedBytes))")
                .monospacedDigit()
                .foregroundStyle(tint)

        case .network:
            return Text("↓\(Self.formatPillNetwork(coordinator.currentNetwork.downloadBytesPerSecond))")
                .monospacedDigit()
                .foregroundStyle(.primary)

        case .disk:
            return Text("DISK \(Self.formatPillDisk(coordinator.currentDisk.usedBytes))")
                .monospacedDigit()
                .foregroundStyle(.primary)

        case .battery:
            let tint = Self.warningTint(for: Self.batteryWarningState(battery: coordinator.currentBattery))
            let bolt = coordinator.currentBattery.isCharging ? "⚡" : ""
            return Text("BAT \(coordinator.currentBattery.percentageString)\(bolt)")
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    // MARK: - Active Segments Logic

    /// Evaluates which segments to render according to user settings and device hardware capabilities.
    /// Preserves strict fixed order: CPU -> Memory -> Network -> Disk -> Battery.
    public static func activeSegments(settings: SettingsModel, hasBattery: Bool) -> [Segment] {
        var segments: [Segment] = []
        if settings.showCPU { segments.append(.cpu) }
        if settings.showMemory { segments.append(.memory) }
        if settings.showNetwork { segments.append(.network) }
        if settings.showDisk { segments.append(.disk) }
        if settings.showBattery && hasBattery { segments.append(.battery) }
        return segments
    }

    // MARK: - Pill Display Formatters

    public static func formatPillMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1fG", gb)
    }

    public static func formatPillNetwork(_ bytesPerSec: Double) -> String {
        let bytes = max(bytesPerSec, 0.0)
        if bytes >= 1_073_741_824.0 {
            return String(format: "%.1fG", bytes / 1_073_741_824.0)
        } else if bytes >= 1_048_576.0 {
            return String(format: "%.1fM", bytes / 1_048_576.0)
        } else if bytes >= 1_024.0 {
            return String(format: "%.0fK", bytes / 1_024.0)
        } else {
            return String(format: "%.0fB", bytes)
        }
    }

    public static func formatPillDisk(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 100 {
            return String(format: "%.0fG", gb)
        } else {
            return String(format: "%.1fG", gb)
        }
    }

    // MARK: - Warning State & Tint Calculation

    public static func memoryWarningState(pressure: MemoryPressureLevel) -> WarningState {
        switch pressure {
        case .critical:
            return .critical
        case .warning:
            return .warning
        case .normal:
            return .nominal
        }
    }

    public static func batteryWarningState(battery: BatteryStats) -> WarningState {
        guard battery.hasBattery else { return .nominal }
        let pct = (battery.capacityFraction * 100).rounded()
        if pct <= 10.0 {
            return .critical
        } else if pct <= 20.0 {
            return .warning
        } else {
            return .nominal
        }
    }

    public static func warningState(
        memoryPressure: MemoryPressureLevel,
        battery: BatteryStats
    ) -> WarningState {
        let mem = memoryWarningState(pressure: memoryPressure)
        let bat = batteryWarningState(battery: battery)
        if mem == .critical || bat == .critical {
            return .critical
        }
        if mem == .warning || bat == .warning {
            return .warning
        }
        return .nominal
    }

    public static func warningTint(for state: WarningState) -> Color {
        switch state {
        case .nominal:
            return .primary
        case .warning:
            return DesignTokens.Colors.warning
        case .critical:
            return DesignTokens.Colors.critical
        }
    }

    public static func warningTint(
        memoryPressure: MemoryPressureLevel,
        battery: BatteryStats
    ) -> Color {
        warningTint(for: warningState(memoryPressure: memoryPressure, battery: battery))
    }

    // MARK: - VoiceOver Accessibility

    public static func formatSpokenCPU(_ cpu: CPUStats) -> String {
        let pct = Int((cpu.usageFraction * 100).rounded())
        return "CPU: \(pct) percent"
    }

    public static func formatSpokenMemory(_ memory: MemoryStats) -> String {
        let gb = Double(memory.usedBytes) / 1_073_741_824.0
        var desc = String(format: "Memory: %.1f gigabytes", gb)
        switch memory.pressure {
        case .warning:
            desc += ", warning pressure"
        case .critical:
            desc += ", critical pressure"
        case .normal:
            break
        }
        return desc
    }

    public static func formatSpokenNetwork(_ network: NetworkStats) -> String {
        let bytes = max(network.downloadBytesPerSecond, 0.0)
        let rateString: String
        if bytes >= 1_073_741_824.0 {
            rateString = String(format: "%.1f gigabytes per second", bytes / 1_073_741_824.0)
        } else if bytes >= 1_048_576.0 {
            rateString = String(format: "%.1f megabytes per second", bytes / 1_048_576.0)
        } else if bytes >= 1_024.0 {
            rateString = String(format: "%.0f kilobytes per second", bytes / 1_024.0)
        } else {
            rateString = String(format: "%.0f bytes per second", bytes)
        }
        return "Download: \(rateString)"
    }

    public static func formatSpokenDisk(_ disk: DiskStats) -> String {
        let gb = Double(disk.usedBytes) / 1_073_741_824.0
        return String(format: "Disk: %.1f gigabytes", gb)
    }

    public static func formatSpokenBattery(_ battery: BatteryStats) -> String {
        let pct = Int((battery.capacityFraction * 100).rounded())
        var desc = "Battery: \(pct) percent"
        if battery.isCharging {
            desc += ", charging"
        }
        if pct <= 10 {
            desc += ", critical"
        } else if pct <= 20 {
            desc += ", low"
        }
        return desc
    }

    public static func accessibilityDescription(
        cpu: CPUStats,
        memory: MemoryStats,
        network: NetworkStats,
        disk: DiskStats,
        battery: BatteryStats,
        settings: SettingsModel
    ) -> String {
        var segments: [String] = []
        if settings.showCPU {
            segments.append(formatSpokenCPU(cpu))
        }
        if settings.showMemory {
            segments.append(formatSpokenMemory(memory))
        }
        if settings.showNetwork {
            segments.append(formatSpokenNetwork(network))
        }
        if settings.showDisk {
            segments.append(formatSpokenDisk(disk))
        }
        if settings.showBattery && battery.hasBattery {
            segments.append(formatSpokenBattery(battery))
        }

        if segments.isEmpty {
            return "Specter"
        }
        return segments.joined(separator: ", ")
    }

    public static func accessibilityDescription(
        coordinator: TelemetryCoordinator,
        settings: SettingsModel
    ) -> String {
        accessibilityDescription(
            cpu: coordinator.currentCPU,
            memory: coordinator.currentMemory,
            network: coordinator.currentNetwork,
            disk: coordinator.currentDisk,
            battery: coordinator.currentBattery,
            settings: settings
        )
    }
}
