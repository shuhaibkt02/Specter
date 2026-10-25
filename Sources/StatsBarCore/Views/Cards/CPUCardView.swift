import SwiftUI

/// Popover cockpit card for CPU telemetry adhering to Doc 07 specification.
/// Displays aggregate CPU utilization, 60s sparkline, P/E core clusters, SoC temperature,
/// and top 5 processes with hover selection, PID tooltips, and safe quit confirmation.
public struct CPUCardView: View {
    public let cpu: CPUStats
    public let history: [Double]
    public let silicon: AppleSiliconStats
    public let topProcesses: [ProcessSnapshot]
    public var onQuitProcess: ((pid_t) -> Void)?

    public init(
        cpu: CPUStats,
        history: [Double] = [],
        silicon: AppleSiliconStats = AppleSiliconStats(),
        topProcesses: [ProcessSnapshot] = [],
        onQuitProcess: ((pid_t) -> Void)? = nil
    ) {
        self.cpu = cpu
        self.history = history
        self.silicon = silicon
        self.topProcesses = topProcesses
        self.onQuitProcess = onQuitProcess
    }

    public init(coordinator: TelemetryCoordinator, onQuitProcess: ((pid_t) -> Void)? = nil) {
        self.init(
            cpu: coordinator.currentCPU,
            history: coordinator.cpuHistory,
            silicon: coordinator.currentAppleSilicon,
            topProcesses: coordinator.topProcesses,
            onQuitProcess: onQuitProcess
        )
    }

    public var liveValue: String {
        cpu.percentageString
    }

    public var formattedTemperature: String {
        silicon.formattedTemperature
    }

    public var body: some View {
        CardView(
            title: "CPU",
            value: liveValue,
            sparkline: {
                SparklineView(values: history)
            },
            breakdown: {
                breakdownContent
            },
            detail: {
                detailContent
            }
        )
    }

    @ViewBuilder
    private var breakdownContent: some View {
        let hasPCores = silicon.pCoreCount > 0
        let hasECores = silicon.eCoreCount > 0
        let hasTemp = silicon.socTemperatureCelsius != nil

        if hasPCores || hasECores || hasTemp {
            VStack(spacing: DesignTokens.Spacing.xSmall) {
                if hasPCores {
                    coreTrackRow(
                        label: "P-Cores",
                        fraction: silicon.pCoreUsageFraction,
                        percentText: "\(Int((silicon.pCoreUsageFraction * 100).rounded()))%"
                    )
                }
                if hasECores {
                    coreTrackRow(
                        label: "E-Cores",
                        fraction: silicon.eCoreUsageFraction,
                        percentText: "\(Int((silicon.eCoreUsageFraction * 100).rounded()))%"
                    )
                }
                if hasTemp {
                    HStack {
                        Text("SoC Temp")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(silicon.formattedTemperature)
                            .font(DesignTokens.Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func coreTrackRow(label: String, fraction: Double, percentText: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            TrackBarView(fraction: fraction)

            Text(percentText)
                .font(DesignTokens.Typography.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Text("Top Processes")
                .font(DesignTokens.Typography.captionSecondary)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 2)

            if topProcesses.isEmpty {
                // Tier-2 skeleton rows per Doc 07 (zero-flicker reserved space)
                ForEach(0..<5, id: \.self) { _ in
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignTokens.Colors.trackBackground)
                            .frame(width: 90, height: 11)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignTokens.Colors.trackBackground)
                            .frame(width: 32, height: 11)
                    }
                    .frame(height: 20)
                }
            } else {
                ForEach(topProcesses.prefix(5)) { process in
                    ProcessRowView(process: process) { pid in
                        onQuitProcess?(pid)
                    }
                }
            }
        }
    }
}

/// Interactive process list row with hover highlight, PID badge, right-aligned percentage,
/// and safe quit confirmation affordance.
public struct ProcessRowView: View {
    public let process: ProcessSnapshot
    public var onQuit: ((pid_t) -> Void)?

    @State private var isHovered: Bool = false
    @State private var isConfirmingQuit: Bool = false

    public init(
        process: ProcessSnapshot,
        onQuit: ((pid_t) -> Void)? = nil
    ) {
        self.process = process
        self.onQuit = onQuit
    }

    public var nameText: String { process.name }
    public var pidText: String { "(\(process.id))" }
    public var percentageText: String { process.percentageString }

    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Text(nameText)
                .font(DesignTokens.Typography.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(pidText)
                .font(DesignTokens.Typography.captionSecondary)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(percentageText)
                .font(DesignTokens.Typography.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            if isHovered {
                if isConfirmingQuit {
                    Button {
                        onQuit?(process.id)
                        isConfirmingQuit = false
                    } label: {
                        Text("Quit?")
                            .font(DesignTokens.Typography.captionSecondary)
                            .foregroundStyle(DesignTokens.Colors.critical)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        isConfirmingQuit = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: DesignTokens.Geometry.minHitTarget, height: DesignTokens.Geometry.minHitTarget)
                    }
                    .buttonStyle(.plain)
                    .help("Force quit \(process.name) (PID: \(process.id))")
                }
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? DesignTokens.Colors.hoverBackground : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
                if !hovering {
                    isConfirmingQuit = false
                }
            }
        }
        .help("\(process.name) (PID: \(process.id)) — CPU: \(percentageText)")
    }
}
