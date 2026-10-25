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
        _coordinator = State(initialValue: TelemetryCoordinator(provider: provider, backgroundInterval: settings.backgroundInterval))
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.interCardGap) {
                // Popover Header
                HStack(alignment: .center) {
                    Text(showingSettings ? "Settings" : "StatsBar")
                        .font(DesignTokens.Typography.cardTitle)
                        .foregroundStyle(.primary)

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
                } else {
                    cockpitView
                }
            }
            .padding(DesignTokens.Spacing.popoverPadding)
            .frame(width: DesignTokens.Geometry.popoverWidth)
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
        } label: {
            MenuBarPillView(coordinator: coordinator, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }

    private var cockpitView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.Spacing.interCardGap) {
                // 1. CPU Card with P/E cores and Top Processes
                CPUCardView(coordinator: coordinator) { pid in
                    kill(pid, SIGTERM)
                }

                // 2. Memory Card with Pressure Status & Swap
                MemoryCardView(coordinator: coordinator)

                // 3. Network Card with Throughput & Interface
                NetworkCardView(coordinator: coordinator)

                // 4. Disk Card with Capacity & Block I/O Throughput
                DiskCardView(coordinator: coordinator)

                // 5. Battery Card (shown if device has battery)
                if coordinator.currentBattery.hasBattery {
                    BatteryCardView(coordinator: coordinator)
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(maxHeight: DesignTokens.Geometry.popoverMaxHeight)
    }
}
