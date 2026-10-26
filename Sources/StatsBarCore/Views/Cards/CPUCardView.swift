import SwiftUI

/// Popover cockpit card for CPU telemetry adhering to Doc 07 specification.
/// Displays aggregate CPU utilization, 60s sparkline, P/E core clusters, SoC temperature,
/// and top 5 processes with hover selection, PID tooltips, and safe quit confirmation.
public struct CPUCardView: View {
    private let coordinator: TelemetryCoordinator?
    public let cpu: CPUStats
    public let history: [Double]
    public let silicon: AppleSiliconStats
    public let topProcesses: [ProcessSnapshot]
    public let showProcesses: Bool
    public var onQuitProcess: ((pid_t) -> Void)?

    public init(
        cpu: CPUStats,
        history: [Double] = [],
        silicon: AppleSiliconStats = AppleSiliconStats(),
        topProcesses: [ProcessSnapshot] = [],
        showProcesses: Bool = true,
        onQuitProcess: ((pid_t) -> Void)? = nil
    ) {
        self.coordinator = nil
        self.cpu = cpu
        self.history = history
        self.silicon = silicon
        self.topProcesses = topProcesses
        self.showProcesses = showProcesses
        self.onQuitProcess = onQuitProcess
    }

    public init(
        coordinator: TelemetryCoordinator,
        showProcesses: Bool = true,
        onQuitProcess: ((pid_t) -> Void)? = nil
    ) {
        self.coordinator = coordinator
        self.cpu = coordinator.currentCPU
        self.history = coordinator.cpuHistory
        self.silicon = coordinator.currentAppleSilicon
        self.topProcesses = coordinator.topProcesses
        self.showProcesses = showProcesses
        self.onQuitProcess = onQuitProcess
    }

    // Dynamic properties observing coordinator when present, falling back to static snapshots for tests
    private var activeCPU: CPUStats { coordinator?.currentCPU ?? cpu }
    private var activeHistory: [Double] { coordinator?.cpuHistory ?? history }
    private var activeSilicon: AppleSiliconStats { coordinator?.currentAppleSilicon ?? silicon }
    private var activeProcesses: [ProcessSnapshot] { coordinator?.topProcesses ?? topProcesses }

    public var liveValue: String {
        activeCPU.percentageString
    }

    public var formattedTemperature: String {
        activeSilicon.formattedTemperature
    }

    public var body: some View {
        CardView(
            title: "CPU",
            value: liveValue,
            sparkline: {
                SparklineView(values: activeHistory)
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
        let hasPCores = activeSilicon.pCoreCount > 0
        let hasECores = activeSilicon.eCoreCount > 0
        let hasTemp = activeSilicon.socTemperatureCelsius != nil

        if hasPCores || hasECores || hasTemp {
            VStack(spacing: DesignTokens.Spacing.xSmall) {
                if hasPCores {
                    coreTrackRow(
                        label: "P-Cores",
                        fraction: activeSilicon.pCoreUsageFraction,
                        percentText: "\(Int((activeSilicon.pCoreUsageFraction * 100).rounded()))%"
                    )
                }
                if hasECores {
                    coreTrackRow(
                        label: "E-Cores",
                        fraction: activeSilicon.eCoreUsageFraction,
                        percentText: "\(Int((activeSilicon.eCoreUsageFraction * 100).rounded()))%"
                    )
                }
                if hasTemp {
                    HStack {
                        Text("SoC Temp")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(activeSilicon.formattedTemperature)
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
        if showProcesses {
            ProcessListView(
                processes: activeProcesses,
                metricType: .cpu,
                onQuitProcess: onQuitProcess
            )
        }
    }
}

/// Interactive process list row with hover highlight, PID badge, right-aligned percentage,
/// and safe quit confirmation affordance complying with Fitts's and Jakob's Laws.
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
                        withAnimation(.easeOut(duration: 0.15)) {
                            onQuit?(process.id)
                            isConfirmingQuit = false
                        }
                    } label: {
                        Text("Quit?")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.critical)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(height: DesignTokens.Geometry.actionHitTarget)
                } else {
                    Button {
                        isConfirmingQuit = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: DesignTokens.Geometry.actionHitTarget, height: DesignTokens.Geometry.actionHitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Force quit \(process.name) (PID: \(process.id))")
                }
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
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
