import SwiftUI
import AppKit
import Darwin
import SpecterCore

@main
struct SpecterApp: App {
    @State private var coordinator: TelemetryCoordinator
    @State private var settings = SettingsModel.shared
    @State private var showingSettings = false
    @State private var processActionError: String?
    @State private var closeConfirmation = ProcessCloseConfirmationModel()
    @State private var vitalsColumnHeight: CGFloat? = nil

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
                HStack(alignment: .center, spacing: DesignTokens.Spacing.small) {
                    Text(showingSettings ? "Settings" : "Specter")
                        .font(DesignTokens.Typography.cardTitle)
                        .foregroundStyle(.primary)

                    if !showingSettings {
                        diskMicroPill
                        batteryMicroPill
                    }

                    Spacer()

                    if !showingSettings {
                        Text("● Live")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.normal)
                    }

                    // Settings / Back toggle (⌘,)
                    Button(action: { showingSettings.toggle() }) {
                        if showingSettings {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.backward")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Back")
                                    .font(DesignTokens.Typography.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(DesignTokens.Colors.borderHairline, lineWidth: 0.5)
                            )
                        } else {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: DesignTokens.Geometry.actionHitTarget, height: DesignTokens.Geometry.actionHitTarget)
                                .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .help(showingSettings ? "Back to Cockpit (⌘,)" : "Settings (⌘,)")
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
                    .help("Quit Specter (⌘Q)")
                    .keyboardShortcut("q", modifiers: .command)
                }

                Divider()
                    .overlay(DesignTokens.Colors.borderHairline)

                // Main Content: Settings or Cockpit
                if showingSettings {
                    SettingsView(
                        settings: settings,
                        hasBattery: coordinator.currentBattery.hasBattery,
                        onDismiss: { showingSettings = false }
                    )
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    cockpitView
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.popoverPadding)
            .padding(.vertical, DesignTokens.Spacing.popoverPadding)
            .frame(width: DesignTokens.Geometry.popoverTwoColumnWidth)
            .overlay {
                if let request = closeConfirmation.request {
                    closeConfirmationOverlay(request)
                } else if let processActionError {
                    processActionErrorOverlay(processActionError)
                }
            }
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
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: VitalsHeightPreferenceKey.self, value: geo.size.height)
                    }
                )

            // Column 2: Process Inspector
            processInspectorColumn
                .frame(width: DesignTokens.Geometry.inspectorColumnWidth)
                .frame(height: vitalsColumnHeight)
        }
        .onPreferenceChange(VitalsHeightPreferenceKey.self) { newHeight in
            if newHeight > 0 && abs((vitalsColumnHeight ?? 0) - newHeight) > 1 {
                vitalsColumnHeight = newHeight
            }
        }
    }

    private var vitalsColumn: some View {
        VStack(spacing: DesignTokens.Spacing.interCardGap) {
            // 1. CPU Card with P/E cores, load sparkline, and SoC temp
            CPUCardView(coordinator: coordinator, showProcesses: false)

            // 2. Memory Card with Pressure Status, RAM allocation, and Swap
            MemoryCardView(coordinator: coordinator, showProcesses: false)

            // 3. Network Card with Throughput & BSD Interface
            NetworkCardView(coordinator: coordinator)
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
                cpuProcesses: coordinator.allProcesses,
                memoryProcesses: coordinator.allProcesses,
                closeConfirmationModel: closeConfirmation,
                onEndProcess: endProcess
            )
        }
        .padding(DesignTokens.Spacing.cardPadding)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
        )
    }

    private func closeConfirmationOverlay(
        _ request: ProcessCloseConfirmationModel.Request
    ) -> some View {
        widgetModal {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                Text(confirmationTitle(for: request))
                    .font(DesignTokens.Typography.cardTitle)
                Text(confirmationMessage(for: request))
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        closeConfirmation.cancel()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(confirmationButtonTitle(for: request), role: .destructive) {
                        closeConfirmation.confirm(onConfirm: confirmProcessAction)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private func processActionErrorOverlay(_ message: String) -> some View {
        widgetModal {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                Text("Process Action Status")
                    .font(DesignTokens.Typography.cardTitle)
                Text(message)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("OK") {
                        processActionError = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private func widgetModal<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.22)

            content()
                .padding(DesignTokens.Spacing.large)
                .frame(width: 340, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                        .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .zIndex(1)
    }

    private func confirmationTitle(for request: ProcessCloseConfirmationModel.Request) -> String {
        switch request.target {
        case .app: return "Close \(request.appName)?"
        case .process: return "End \(request.appName)?"
        }
    }

    private func confirmationMessage(for request: ProcessCloseConfirmationModel.Request) -> String {
        switch request.target {
        case .app: return "This asks the app to close normally."
        case .process(let pid): return "This sends a normal termination request to PID \(pid)."
        }
    }

    private func confirmationButtonTitle(for request: ProcessCloseConfirmationModel.Request) -> String {
        switch request.target {
        case .app: return "Close"
        case .process: return "End"
        }
    }

    private func confirmProcessAction(_ request: ProcessCloseConfirmationModel.Request) {
        switch request.target {
        case .app(let bundleIdentifier):
            closeApp(bundleIdentifier: bundleIdentifier)
        case .process(let pid):
            _ = endProcess(pid: pid)
        }
    }

    private func endProcess(pid: pid_t) -> Bool {
        closeConfirmation.markPIDClosing(pid)
        guard kill(pid, SIGTERM) == 0 else {
            let err = errno
            if err == ESRCH {
                // Process already dead
                closeConfirmation.clearPIDClosing(pid)
                coordinator.tick()
                return true
            }
            closeConfirmation.clearPIDClosing(pid)
            processActionError = "Could not end PID \(pid): \(String(cString: strerror(err)))."
            return false
        }

        Task {
            let start = DispatchTime.now()
            while ProcessCollector.isPIDAlive(pid) {
                try? await Task.sleep(nanoseconds: 150_000_000)
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
                if elapsed > 4.0 {
                    _ = kill(pid, SIGKILL)
                    break
                }
            }
            await MainActor.run {
                closeConfirmation.clearPIDClosing(pid)
                coordinator.tick()
            }
        }
        return true
    }

    private func closeApp(bundleIdentifier: String) {
        closeConfirmation.markGroupClosing(bundleIdentifier)

        let groupPIDs = Set(
            coordinator.allProcesses
                .filter { $0.groupIdentifier == bundleIdentifier }
                .map(\.id)
        )

        let application = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { groupPIDs.contains($0.processIdentifier) })

        if let application {
            _ = application.terminate()
        }

        // Terminate any remaining helper PIDs belonging to this group
        for pid in groupPIDs where pid != application?.processIdentifier {
            _ = kill(pid, SIGTERM)
        }

        if application == nil && groupPIDs.isEmpty {
            closeConfirmation.clearGroupClosing(bundleIdentifier)
            coordinator.tick()
            return
        }

        Task {
            let start = DispatchTime.now()
            var remaining = groupPIDs
            while !remaining.isEmpty {
                try? await Task.sleep(nanoseconds: 150_000_000)
                remaining = remaining.filter { ProcessCollector.isPIDAlive($0) }
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
                if elapsed > 4.0 {
                    for pid in remaining {
                        _ = kill(pid, SIGKILL)
                    }
                    break
                }
            }
            await MainActor.run {
                closeConfirmation.clearGroupClosing(bundleIdentifier)
                coordinator.tick()
            }
        }
    }

    private var diskMicroPill: some View {
        let disk = coordinator.currentDisk
        let pct = Int((disk.usedFraction * 100).rounded())
        let tooltip = "Disk: \(disk.formattedUsedGB) used of \(disk.formattedTotalGB) (\(pct)%)\nRead: \(disk.formattedRead) · Write: \(disk.formattedWrite)"

        return HStack(spacing: 4) {
            Image(systemName: "internaldrive")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(disk.formattedUsedGB) / \(disk.formattedTotalGB)")
                .font(DesignTokens.Typography.caption)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(DesignTokens.Colors.borderHairline, lineWidth: 0.5)
        )
        .help(tooltip)
    }

    @ViewBuilder
    private var batteryMicroPill: some View {
        if coordinator.currentBattery.hasBattery {
            let batt = coordinator.currentBattery
            let battTint: Color = batt.capacityFraction <= 0.10 ? DesignTokens.Colors.critical : (batt.capacityFraction <= 0.20 ? DesignTokens.Colors.warning : .primary)
            let iconName = batt.isCharging ? "battery.100.bolt" : (batt.capacityFraction <= 0.20 ? "battery.25" : "battery.100")
            let bolt = batt.isCharging ? " ⚡" : ""
            let timeStr = batt.formattedTimeRemaining ?? "Calculating..."
            let condStr = batt.condition ?? "Normal"
            let tooltip = "Battery: \(batt.percentageString)\(batt.isCharging ? " (Charging)" : "")\nCondition: \(condStr)\nTime Remaining: \(timeStr)"

            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(battTint)
                Text("\(batt.percentageString)\(bolt)")
                    .font(DesignTokens.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(battTint)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(DesignTokens.Colors.borderHairline, lineWidth: 0.5)
            )
            .help(tooltip)
        }
    }
}

private struct VitalsHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
