import SwiftUI
import AppKit
import StatsBarCore

@main
struct StatsBarApp: App {
    @State private var coordinator: TelemetryCoordinator
    @State private var settings = SettingsModel.shared
    @State private var showingSettings = false

    init() {
        let provider = SystemTelemetryProvider()
        let settings = SettingsModel.shared
        _coordinator = State(initialValue: TelemetryCoordinator(provider: provider, backgroundInterval: settings.backgroundInterval))
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(showingSettings ? "Settings" : "StatsBar")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingSettings.toggle() }) {
                        Image(systemName: showingSettings ? "chevron.backward" : "gearshape")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                if showingSettings {
                    settingsView
                } else {
                    dashboardView
                }

                Divider()

                Button("Quit StatsBar") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 250)
            .onAppear {
                coordinator.isPopoverPresented = true
            }
            .onDisappear {
                coordinator.isPopoverPresented = false
            }
            .onChange(of: settings.backgroundInterval) { _, newInterval in
                coordinator.backgroundInterval = newInterval
            }
        } label: {
            MenuBarPillView(coordinator: coordinator, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu Bar Items")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Toggle("CPU Usage", isOn: $settings.showCPU)
            Toggle("Memory", isOn: $settings.showMemory)
            Toggle("Network", isOn: $settings.showNetwork)
            Toggle("Disk", isOn: $settings.showDisk)
            if coordinator.currentBattery.hasBattery {
                Toggle("Battery", isOn: $settings.showBattery)
            }

            Divider()

            Text("Background Interval")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Interval", selection: $settings.backgroundInterval) {
                Text("1s").tag(1.0)
                Text("2s").tag(2.0)
                Text("3s").tag(3.0)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            Toggle("Show Per-Core CPU", isOn: $settings.showPerCoreBreakdown)
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
        }
        .toggleStyle(.checkbox)
        .font(.subheadline)
    }

    private var dashboardView: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                if settings.showPerCoreBreakdown && (coordinator.currentAppleSilicon.pCoreCount > 0 || coordinator.currentAppleSilicon.eCoreCount > 0) {
                    HStack {
                        Text("P-Cores: \(Int((coordinator.currentAppleSilicon.pCoreUsageFraction * 100).rounded()))%")
                        Spacer()
                        Text("E-Cores: \(Int((coordinator.currentAppleSilicon.eCoreUsageFraction * 100).rounded()))%")
                        Spacer()
                        Text("SoC: \(coordinator.currentAppleSilicon.formattedTemperature)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
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
        }
    }
}
