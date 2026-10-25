import SwiftUI
import AppKit
import StatsBarCore

@main
struct StatsBarApp: App {
    @State private var coordinator: TelemetryCoordinator

    init() {
        // Uses production SystemTelemetryProvider with live Mach CPUCollector
        let provider = SystemTelemetryProvider()
        _coordinator = State(initialValue: TelemetryCoordinator(provider: provider))
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("StatsBar (Engine Placeholder)")
                    .font(.headline)
                
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CPU Usage:")
                            .font(.subheadline)
                        Spacer()
                        Text(coordinator.currentCPU.percentageString)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    
                    SparklineView(values: coordinator.cpuHistory)
                        .frame(height: 36)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Divider()

                Text("Memory: \(coordinator.currentMemory.formattedUsedGB)")
                    .monospacedDigit()

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Network:")
                            .font(.subheadline)
                        Spacer()
                        Text("↓\(coordinator.currentNetwork.formattedDownload) ↑\(coordinator.currentNetwork.formattedUpload)")
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Disk:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(coordinator.currentDisk.formattedUsedGB) / \(coordinator.currentDisk.formattedTotalGB)")
                            .font(.subheadline)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("R: \(coordinator.currentDisk.formattedReadMBs)")
                        Spacer()
                        Text("W: \(coordinator.currentDisk.formattedWriteMBs)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }

                if coordinator.currentBattery.hasBattery {
                    Divider()
                    HStack {
                        Text("Battery:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(coordinator.currentBattery.percentageString)\(coordinator.currentBattery.isCharging ? " ⚡" : "")")
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }

                if !coordinator.topProcesses.isEmpty {
                    Divider()
                    Text("Top Processes (CPU)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        ForEach(coordinator.topProcesses) { proc in
                            HStack {
                                Text(proc.name)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Text(proc.percentageString)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
                
                Divider()

                Button("Quit StatsBar") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 240)
            .onAppear {
                coordinator.isPopoverPresented = true
            }
            .onDisappear {
                coordinator.isPopoverPresented = false
            }
        } label: {
            MenuBarPillView(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
