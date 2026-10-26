import SwiftUI
import AppKit
import StatsBarCore

@main
struct StatsBarApp: App {
    @State private var coordinator: TelemetryCoordinator
    @State private var settings = SettingsModel.shared
    @State private var showingSettings = false

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let provider = SystemTelemetryProvider()
        let settings = SettingsModel.shared
        let coord = TelemetryCoordinator(provider: provider, backgroundInterval: settings.backgroundInterval)
        coord.tick() // Prime live metrics immediately on launch
        _coordinator = State(initialValue: coord)
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.interCardGap) {
                // Popover Header
                HStack(alignment: .center) {
                    Text(showingSettings ? "Settings" : "StatsBar")
                        .font(DesignTokens.Typography.cardTitle)
                        .foregroundStyle(.primary)

                    if !showingSettings {
                        Text("● Live Telemetry")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }

                    Spacer()

                    // Gear button to toggle settings (⌘,)
                    Button(action: { showingSettings.toggle() }) {
                        Image(systemName: showingSettings ? "chevron.backward" : "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: DesignTokens.Geometry.actionHitTarget, height: DesignTokens.Geometry.actionHitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(showingSettings ? "Back to Cockpit" : "Settings (⌘,)")
                    .keyboardShortcut(",", modifiers: .command)

                    // Quit Button (⌘Q)
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: DesignTokens.Geometry.actionHitTarget, height: DesignTokens.Geometry.actionHitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Quit StatsBar (⌘Q)")
                    .keyboardShortcut("q", modifiers: .command)
                }
                .padding(.horizontal, 4)

                Divider()
                    .overlay(DesignTokens.Colors.borderHairline)

                // Main Content: Settings or Cockpit
                if showingSettings {
                    SettingsView(
                        settings: settings,
                        hasBattery: coordinator.currentBattery.hasBattery,
                        onDismiss: { showingSettings = false }
                    )
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    cockpitView
                }
            }
            .padding(DesignTokens.Spacing.popoverPadding)
            .frame(width: DesignTokens.Geometry.popoverTwoColumnWidth)
            .onAppear {
                coordinator.isPopoverPresented = true
            }
            .onDisappear {
                coordinator.isPopoverPresented = false
                showingSettings = false
            }
            .onChange(of: settings.backgroundInterval) { _, newInterval in
                coordinator.backgroundInterval = newInterval
            }
            .onChange(of: settings.showCPU) { _, _ in coordinator.tick() }
            .onChange(of: settings.showMemory) { _, _ in coordinator.tick() }
            .onChange(of: settings.showNetwork) { _, _ in coordinator.tick() }
            .onChange(of: settings.showDisk) { _, _ in coordinator.tick() }
            .onChange(of: settings.showBattery) { _, _ in coordinator.tick() }
        } label: {
            MenuBarPillView(coordinator: coordinator, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }

    private var cockpitView: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.interCardGap) {
            // Column 1: System Vitals
            vitalsColumn
                .frame(width: DesignTokens.Geometry.vitalsColumnWidth)

            // Column 2: Process Inspector
            processInspectorColumn
                .frame(width: DesignTokens.Geometry.inspectorColumnWidth)
        }
        .onAppear {
            coordinator.isPopoverPresented = true
            coordinator.tick()
        }
    }

    private var vitalsColumn: some View {
        VStack(spacing: DesignTokens.Spacing.interCardGap) {
            // 1. CPU Card with P/E cores and SoC temp (vitals glance)
            CPUCardView(coordinator: coordinator, showProcesses: false)

            // 2. Memory Card with Pressure Status & Swap (vitals glance)
            MemoryCardView(coordinator: coordinator, showProcesses: false)

            // 3. Network Card with Throughput & Interface
            NetworkCardView(coordinator: coordinator)

            // 4. Disk Card with Capacity & Block I/O Throughput
            DiskCardView(coordinator: coordinator)

            // 5. Battery Card (shown if device has battery)
            if coordinator.currentBattery.hasBattery {
                BatteryCardView(coordinator: coordinator)
            }
        }
    }

    private var processInspectorColumn: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.intraCardGap) {
            HStack(alignment: .firstTextBaseline) {
                Text("Process Inspector")
                    .font(DesignTokens.Typography.cardTitle)
                    .foregroundStyle(.primary)

                Circle()
                    .fill(DesignTokens.Colors.normal)
                    .frame(width: 6, height: 6)

                Spacer()
            }

            ProcessListView(
                cpuProcesses: coordinator.topProcesses,
                memoryProcesses: coordinator.topMemoryProcesses
            ) { pid in
                kill(pid, SIGTERM)
            }
        }
        .padding(DesignTokens.Spacing.cardPadding)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
        )
    }
}
