import SwiftUI

/// Unified high-polish settings panel adhering to macOS form idioms.
/// Replaces fragmented floating cards with a single cohesive container,
/// a 2-column menu bar visibility grid, and native dropdown menus.
public struct SettingsView: View {
    @Bindable public var settings: SettingsModel
    public let hasBattery: Bool
    public var onDismiss: () -> Void

    public init(
        settings: SettingsModel,
        hasBattery: Bool = true,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.hasBattery = hasBattery
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.interCardGap) {
            // Unified Preferences Card
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                // Section 1: Menu Bar Visibility
                menuBarVisibilitySection

                Divider()
                    .overlay(DesignTokens.Colors.borderHairline)

                // Section 2: Telemetry & Hardware
                telemetryHardwareSection

                Divider()
                    .overlay(DesignTokens.Colors.borderHairline)

                // Section 3: Preferences
                preferencesSection
            }
            .padding(DesignTokens.Spacing.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                    .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
            )

            // Bottom Footer Action
            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Section Views

    private var menuBarVisibilitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Text("MENU BAR VISIBILITY")
                .font(DesignTokens.Typography.captionSecondary)
                .foregroundStyle(.secondary)

            Text("Configure which telemetry metrics appear directly in the status bar.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ],
                spacing: DesignTokens.Spacing.small
            ) {
                Toggle("CPU Utilization", isOn: $settings.showCPU)
                Toggle("Memory (RAM)", isOn: $settings.showMemory)
                Toggle("Network Throughput", isOn: $settings.showNetwork)
                Toggle("Disk Capacity", isOn: $settings.showDisk)
                if hasBattery {
                    Toggle("Battery State", isOn: $settings.showBattery)
                }
            }
            .toggleStyle(.checkbox)
            .font(DesignTokens.Typography.body)
        }
    }

    private var telemetryHardwareSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("TELEMETRY & HARDWARE")
                .font(DesignTokens.Typography.captionSecondary)
                .foregroundStyle(.secondary)

            HStack {
                Text("Refresh Rate")
                    .font(DesignTokens.Typography.body)
                Spacer()
                Picker("Refresh Rate", selection: $settings.backgroundInterval) {
                    Text("1s (Fast)").tag(1.0)
                    Text("2s (Balanced)").tag(2.0)
                    Text("3s (Quiet)").tag(3.0)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }

            HStack {
                Text("Temperature Unit")
                    .font(DesignTokens.Typography.body)
                Spacer()
                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                    Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("PREFERENCES")
                .font(DesignTokens.Typography.captionSecondary)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Toggle("Show per-core breakdown in CPU card", isOn: $settings.showPerCoreBreakdown)
                Toggle("Launch StatsBar at login", isOn: $settings.launchAtLogin)
            }
            .toggleStyle(.checkbox)
            .font(DesignTokens.Typography.body)
        }
    }
}
