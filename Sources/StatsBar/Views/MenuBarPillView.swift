import SwiftUI
import StatsBarCore

/// Minimal placeholder wireframe for the unified menu bar status pill.
/// Enforces monospaced tabular digits to completely eliminate horizontal width jitter.
public struct MenuBarPillView: View {
    public let coordinator: TelemetryCoordinator
    public let settings: SettingsModel

    public init(coordinator: TelemetryCoordinator, settings: SettingsModel = .shared) {
        self.coordinator = coordinator
        self.settings = settings
    }

    public var body: some View {
        HStack(spacing: 6) {
            if settings.showCPU {
                Text("C: \(coordinator.currentCPU.percentageString)")
                    .monospacedDigit()
            }
            if settings.showMemory {
                if settings.showCPU { Text("•").foregroundStyle(.secondary) }
                Text("R: \(coordinator.currentMemory.formattedUsedGB)")
                    .monospacedDigit()
            }
            if settings.showNetwork {
                if settings.showCPU || settings.showMemory { Text("•").foregroundStyle(.secondary) }
                Text("↓\(coordinator.currentNetwork.formattedDownload)")
                    .monospacedDigit()
            }
            if settings.showDisk {
                if settings.showCPU || settings.showMemory || settings.showNetwork { Text("•").foregroundStyle(.secondary) }
                Text("D: \(coordinator.currentDisk.formattedUsedGB)")
                    .monospacedDigit()
            }
            if settings.showBattery && coordinator.currentBattery.hasBattery {
                if settings.showCPU || settings.showMemory || settings.showNetwork || settings.showDisk { Text("•").foregroundStyle(.secondary) }
                Text("B: \(coordinator.currentBattery.percentageString)")
                    .monospacedDigit()
            }
        }
        .font(.system(size: 11, weight: .medium, design: .default))
    }
}
