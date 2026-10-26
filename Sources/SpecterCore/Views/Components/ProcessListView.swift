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

/// Process inspector with expandable app groups, search, sorting, and safe process actions.
public struct ProcessListView: View {
    public let cpuProcesses: [ProcessSnapshot]
    public let memoryProcesses: [ProcessSnapshot]
    public var closeConfirmationModel: ProcessCloseConfirmationModel?
    public var onQuitProcess: ((pid_t) -> Void)?
    public var onEndProcess: ((pid_t) -> Bool)?

    @State private var selectedCategory: ProcessCategory = .user
    @State private var selectedMetric: ProcessMetricType
    @State private var searchText = ""
    @State private var isExpanded = false
    @State private var expandedGroups: Set<String> = []
    @State private var hoveredGroups: [ProcessGroup]?

    public init(
        cpuProcesses: [ProcessSnapshot],
        memoryProcesses: [ProcessSnapshot] = [],
        closeConfirmationModel: ProcessCloseConfirmationModel? = nil,
        onQuitProcess: ((pid_t) -> Void)? = nil,
        onEndProcess: ((pid_t) -> Bool)? = nil
    ) {
        self.cpuProcesses = cpuProcesses
        self.memoryProcesses = memoryProcesses.isEmpty ? cpuProcesses : memoryProcesses
        self.closeConfirmationModel = closeConfirmationModel
        self.onQuitProcess = onQuitProcess
        self.onEndProcess = onEndProcess
        self._selectedMetric = State(initialValue: .cpu)
    }

    /// Backwards-compatible initializer for tests and single-metric scenarios.
    public init(
        processes: [ProcessSnapshot],
        metricType: ProcessMetricType = .cpu,
        closeConfirmationModel: ProcessCloseConfirmationModel? = nil,
        onQuitProcess: ((pid_t) -> Void)? = nil,
        onEndProcess: ((pid_t) -> Bool)? = nil
    ) {
        self.cpuProcesses = processes
        self.memoryProcesses = processes
        self.closeConfirmationModel = closeConfirmationModel
        self.onQuitProcess = onQuitProcess
        self.onEndProcess = onEndProcess
        self._selectedMetric = State(initialValue: metricType)
    }

    public var currentPool: [ProcessSnapshot] {
        switch selectedMetric {
        case .cpu:
            return cpuProcesses.sorted { $0.cpuFraction > $1.cpuFraction }
        case .memory:
            return memoryProcesses.sorted { $0.ramBytes > $1.ramBytes }
        }
    }

    public var filteredProcesses: [ProcessSnapshot] {
        currentPool.filter { process in
            let matchesCategory = selectedCategory == .user ? process.isUserApp : !process.isUserApp
            guard matchesCategory else { return false }
            guard !searchText.isEmpty else { return true }
            return process.name.localizedCaseInsensitiveContains(searchText)
                || String(process.id).contains(searchText)
        }
    }

    public var filteredGroups: [ProcessGroup] {
        let processes = currentPool.filter {
            selectedCategory == .user ? $0.isUserApp : !$0.isUserApp
        }
        let grouped = Dictionary(grouping: processes) { $0.groupIdentifier ?? "pid:\($0.id)" }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return grouped.values.compactMap { members in
            let group = ProcessGroup(processes: members)
            return group.matches(searchQuery: query) ? group : nil
        }
        .sorted {
            switch selectedMetric {
            case .cpu: return $0.cpuFraction > $1.cpuFraction
            case .memory: return $0.ramBytes > $1.ramBytes
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ProcessCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(maxWidth: 165)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    TextField("Filter...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.caption)
                        .frame(maxWidth: 72)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            HStack {
                Text("PROCESS NAME")
                    .font(DesignTokens.Typography.captionSecondary)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Sort Metric", selection: $selectedMetric) {
                    Text("CPU").tag(ProcessMetricType.cpu)
                    Text("RAM").tag(ProcessMetricType.memory)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 86)
            }

            Divider()
                .overlay(DesignTokens.Colors.borderHairline)

            let groups = hoveredGroups ?? filteredGroups
            if groups.isEmpty {
                Text(searchText.isEmpty ? "No active \(selectedCategory.rawValue.lowercased())" : "No matching processes")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(groups) { group in
                            groupRow(group)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .onHover { isHovering in
                    hoveredGroups = isHovering ? filteredGroups : nil
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func groupRow(_ group: ProcessGroup) -> some View {
        if !group.containsMultipleProcesses, let process = group.processes.first {
            ProcessItemRow(
                process: process,
                metricType: selectedMetric,
                allowQuit: selectedCategory == .user,
                onQuit: onQuitProcess,
                onEnd: onEndProcess,
                onRequestEnd: requestEndProcess
            )
        } else {
            ProcessGroupRow(
                group: group,
                metricType: selectedMetric,
                allowQuit: selectedCategory == .user,
                isExpanded: expandedGroups.contains(group.id),
                onToggle: { toggleGroup(group.id) },
                onQuitProcess: onQuitProcess,
                onEndProcess: onEndProcess,
                onRequestEndProcess: requestEndProcess,
                onRequestClose: closeConfirmationModel != nil
                    ? { bundleIdentifier, appName in
                        closeConfirmationModel?.requestClose(
                            bundleIdentifier: bundleIdentifier,
                            appName: appName
                        )
                    }
                    : nil,
            )
        }
    }

    private var requestEndProcess: ((ProcessSnapshot) -> Void)? {
        guard let closeConfirmationModel else { return nil }
        return { process in
            closeConfirmationModel.requestEndProcess(pid: process.id, processName: process.name)
        }
    }

    private func toggleGroup(_ id: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            if expandedGroups.contains(id) {
                expandedGroups.remove(id)
            } else {
                expandedGroups.insert(id)
            }
        }
    }
}

private struct ProcessGroupRow: View {
    let group: ProcessGroup
    let metricType: ProcessMetricType
    let allowQuit: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onQuitProcess: ((pid_t) -> Void)?
    let onEndProcess: ((pid_t) -> Bool)?
    let onRequestEndProcess: ((ProcessSnapshot) -> Void)?
    let onRequestClose: ((String, String) -> Void)?

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                // Interactive group header: tapping chevron, name, count, or metric toggles expansion
                HStack(spacing: 5) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Text(group.name)
                        .font(.body)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(group.processes.count) \(group.processes.count == 1 ? "process" : "processes")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(metricType == .cpu ? group.formattedCPU : group.formattedRAM)
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 48, alignment: .trailing)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggle()
                }

                if allowQuit && onRequestClose != nil && group.processes.contains(where: { $0.groupIdentifier != nil }) {
                    Button("Close") {
                        if let identifier = group.processes.first?.groupIdentifier {
                            onRequestClose?(identifier, group.name)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Request \(group.name) to close normally")
                }
            }
            .frame(minHeight: 26)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? DesignTokens.Colors.hoverBackground : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(group.processes) { process in
                        ProcessItemRow(
                            process: process,
                            metricType: metricType,
                            allowQuit: allowQuit,
                            onQuit: onQuitProcess,
                            onEnd: onEndProcess,
                            onRequestEnd: onRequestEndProcess
                        )
                        .padding(.leading, 14)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Individual process row with an explicit end-process confirmation.
public struct ProcessItemRow: View {
    public let process: ProcessSnapshot
    public let metricType: ProcessMetricType
    public let allowQuit: Bool
    public var onQuit: ((pid_t) -> Void)?
    public var onEnd: ((pid_t) -> Bool)?
    public var onRequestEnd: ((ProcessSnapshot) -> Void)?

    @State private var isHovered = false
    @State private var isTerminated = false

    public init(
        process: ProcessSnapshot,
        metricType: ProcessMetricType,
        allowQuit: Bool = true,
        onQuit: ((pid_t) -> Void)? = nil,
        onEnd: ((pid_t) -> Bool)? = nil,
        onRequestEnd: ((ProcessSnapshot) -> Void)? = nil
    ) {
        self.process = process
        self.metricType = metricType
        self.allowQuit = allowQuit
        self.onQuit = onQuit
        self.onEnd = onEnd
        self.onRequestEnd = onRequestEnd
    }

    public var metricString: String {
        switch metricType {
        case .cpu: return process.percentageString
        case .memory: return process.formattedRAM
        }
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Text(process.name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .strikethrough(isTerminated, color: .secondary)
                .foregroundStyle(isTerminated ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("(\(process.id))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(metricString)
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)

            if allowQuit && !isTerminated {
                Button("Close", role: .destructive) {
                    requestEnd()
                }
                .font(.system(size: 10, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Close \(process.name) (PID: \(process.id))")
            }
        }
        .frame(minHeight: 24)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? DesignTokens.Colors.hoverBackground : Color.clear)
        )
        .opacity(isTerminated ? 0.3 : 1.0)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("\(process.name) (PID: \(process.id)) — \(metricType == .cpu ? "CPU: " : "RAM: ")\(metricString)")
    }

    @discardableResult
    public func closeProcess() -> Bool {
        if let onEnd {
            return onEnd(process.id)
        }
        onQuit?(process.id)
        return true
    }

    public func requestEnd() {
        if let onRequestEnd {
            onRequestEnd(process)
        } else {
            isTerminated = closeProcess()
        }
    }
}
