import SwiftUI
import StatsBarCore

/// Minimal placeholder wireframe for the unified menu bar status pill.
/// Enforces monospaced tabular digits to completely eliminate horizontal width jitter.
public struct MenuBarPillView: View {
    public let coordinator: TelemetryCoordinator

    public init(coordinator: TelemetryCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text("C: \(coordinator.currentCPU.percentageString)")
                .monospacedDigit()
            Text("•")
                .foregroundStyle(.secondary)
            Text("R: \(coordinator.currentMemory.formattedUsedGB)")
                .monospacedDigit()
            Text("•")
                .foregroundStyle(.secondary)
            Text("↓\(coordinator.currentNetwork.formattedDownload)")
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium, design: .default))
    }
}
