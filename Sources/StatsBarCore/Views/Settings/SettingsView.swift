import SwiftUI

/// Dedicated 5-control anti-settings panel strictly adhering to Doc 07 Section 2.3.
/// Prevents feature bloat by enforcing a strict under-10-controls limit.
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
            // Control 1: Menu bar segments
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text("MENU BAR SEGMENTS")
                    .font(DesignTokens.Typography.captionSecondary)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
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
            .padding(DesignTokens.Spacing.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                    .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
            )

            // Control 2: Background Sampling Interval
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text("BACKGROUND SAMPLING INTERVAL")
                    .font(DesignTokens.Typography.captionSecondary)
                    .foregroundStyle(.secondary)

                Picker("Background Interval", selection: $settings.backgroundInterval) {
                    Text("1s (Fast)").tag(1.0)
                    Text("2s (Balanced)").tag(2.0)
                    Text("3s (Quiet)").tag(3.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(DesignTokens.Spacing.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                    .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
            )

            // Control 3: Temperature Unit
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text("TEMPERATURE UNIT")
                    .font(DesignTokens.Typography.captionSecondary)
                    .foregroundStyle(.secondary)

                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                    Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(DesignTokens.Spacing.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                    .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
            )

            // Control 4 & 5: Toggles (Per-Core Breakdown & Launch at Login)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Toggle("Show per-core breakdown in CPU card", isOn: $settings.showPerCoreBreakdown)
                Toggle("Launch StatsBar at login", isOn: $settings.launchAtLogin)
            }
            .toggleStyle(.checkbox)
            .font(DesignTokens.Typography.body)
            .padding(DesignTokens.Spacing.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                    .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
            )

            Button(action: onDismiss) {
                HStack {
                    Spacer()
                    Text("Done")
                        .font(DesignTokens.Typography.cardTitle)
                    Spacer()
                }
                .frame(height: DesignTokens.Geometry.actionHitTarget)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
}
