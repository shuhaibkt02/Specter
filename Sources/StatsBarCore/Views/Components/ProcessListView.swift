import SwiftUI

/// Process category filter adhering to User Apps vs System Daemons matrix.
public enum ProcessCategory: String, CaseIterable, Sendable {
    case user = "User Apps"
    case system = "System Daemons"
}

/// Telemetry metric type displayed in the process row.
public enum ProcessMetricType: Sendable {
    case cpu
    case memory
}

/// Fluid, Apple-designed process list with User/System filter matrix, inline search,
/// progressive disclosure (Top 5 default -> expandable scrollable list), and safe 2-step termination.
public struct ProcessListView: View {
    public let processes: [ProcessSnapshot]
    public let metricType: ProcessMetricType
    public var onQuitProcess: ((pid_t) -> Void)?

    @State private var selectedCategory: ProcessCategory = .user
    @State private var searchText: String = ""
    @State private var isExpanded: Bool = false

    public init(
        processes: [ProcessSnapshot],
        metricType: ProcessMetricType,
        onQuitProcess: ((pid_t) -> Void)? = nil
    ) {
        self.processes = processes
        self.metricType = metricType
        self.onQuitProcess = onQuitProcess
    }

    /// Evaluates category and search query filters.
    public var filteredProcesses: [ProcessSnapshot] {
        processes.filter { proc in
            let matchesCategory = (selectedCategory == .user) ? proc.isUserApp : !proc.isUserApp
            guard matchesCategory else { return false }
            if searchText.isEmpty { return true }
            return proc.name.localizedCaseInsensitiveContains(searchText) || String(proc.id).contains(searchText)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            // Header Controls: Category Segmented Picker & Inline Search Toggle
            HStack(spacing: DesignTokens.Spacing.xSmall) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ProcessCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(maxWidth: 190)

                Spacer()

                // Compact Search Input Field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    TextField("Filter...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.caption)
                        .frame(maxWidth: 80)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(DesignTokens.Colors.borderHairline, lineWidth: 0.5)
                )
            }
            .padding(.top, 4)

            // Process Rows Container
            let displayed = filteredProcesses
            if displayed.isEmpty {
                Text(searchText.isEmpty ? "No active \(selectedCategory.rawValue.lowercased())" : "No matching processes")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                let visibleCount = isExpanded ? displayed.count : min(5, displayed.count)
                let itemsToShow = Array(displayed.prefix(visibleCount))

                if isExpanded {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 2) {
                            ForEach(itemsToShow) { process in
                                ProcessItemRow(
                                    process: process,
                                    metricType: metricType,
                                    allowQuit: selectedCategory == .user,
                                    onQuit: onQuitProcess
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                } else {
                    VStack(spacing: 2) {
                        ForEach(itemsToShow) { process in
                            ProcessItemRow(
                                process: process,
                                metricType: metricType,
                                allowQuit: selectedCategory == .user,
                                onQuit: onQuitProcess
                            )
                        }
                    }
                }

                // Progressive Disclosure Accordion Footer
                if displayed.count > 5 {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                            Text(isExpanded ? "Show Top 5" : "Show All (\(displayed.count - 5) more)")
                                .font(DesignTokens.Typography.captionSecondary)
                            Spacer()
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Unified process row view with tactile hover affordance, PID badge, right-aligned metric,
/// and safe two-stage "Quit?" confirmation capsule.
public struct ProcessItemRow: View {
    public let process: ProcessSnapshot
    public let metricType: ProcessMetricType
    public let allowQuit: Bool
    public var onQuit: ((pid_t) -> Void)?

    @State private var isHovered: Bool = false
    @State private var isConfirmingQuit: Bool = false
    @State private var isTerminated: Bool = false

    public init(
        process: ProcessSnapshot,
        metricType: ProcessMetricType,
        allowQuit: Bool = true,
        onQuit: ((pid_t) -> Void)? = nil
    ) {
        self.process = process
        self.metricType = metricType
        self.allowQuit = allowQuit
        self.onQuit = onQuit
    }

    public var metricString: String {
        switch metricType {
        case .cpu:
            return process.percentageString
        case .memory:
            return process.formattedRAM
        }
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            // Process Name
            Text(process.name)
                .font(DesignTokens.Typography.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .strikethrough(isTerminated, color: .secondary)
                .foregroundStyle(isTerminated ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // PID Badge
            Text("(\(process.id))")
                .font(DesignTokens.Typography.captionSecondary)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            // Metric Value (CPU % or RAM)
            Text(metricString)
                .font(DesignTokens.Typography.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)

            // Action / Confirmation Slot
            if isHovered && allowQuit && !isTerminated {
                if isConfirmingQuit {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isTerminated = true
                            isConfirmingQuit = false
                            onQuit?(process.id)
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
        .opacity(isTerminated ? 0.3 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
                if !hovering {
                    isConfirmingQuit = false
                }
            }
        }
        .help("\(process.name) (PID: \(process.id)) — \(metricType == .cpu ? "CPU: " : "RAM: ")\(metricString)")
    }
}
