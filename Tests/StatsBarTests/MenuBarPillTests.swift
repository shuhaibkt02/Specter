import Testing
import SwiftUI
@testable import StatsBarCore

@Suite("MenuBarPill Tests")
@MainActor
struct MenuBarPillTests {

    private func createIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.statsbar.pill.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - 1. VoiceOver Accessibility Label Generation

    @Test("VoiceOver label produces exact unabbreviated spoken description for default metrics")
    func testVoiceOverDefaultMetrics() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults) // default: CPU, Memory, Network enabled

        let cpu = CPUStats(usageFraction: 0.14)
        // 8.2 GB = 8.2 * 1_073_741_824 = 8_804_682_956 bytes
        let memory = MemoryStats(usedBytes: 8_804_682_957, totalBytes: 17_179_869_184, pressure: .normal)
        // 1.5 MB/s = 1.5 * 1_048_576 = 1_572_864 bytes/sec
        let network = NetworkStats(uploadBytesPerSecond: 0, downloadBytesPerSecond: 1_572_864)
        let disk = DiskStats(totalBytes: 500_000_000_000, freeBytes: 341_200_000_000, usedBytes: 158_800_000_000)
        let battery = BatteryStats(capacityFraction: 0.95, isCharging: false)

        let label = MenuBarPillView.accessibilityDescription(
            cpu: cpu,
            memory: memory,
            network: network,
            disk: disk,
            battery: battery,
            settings: settings
        )

        // Verifies exact match with Doc 07 & prompt specification:
        // "CPU: 14 percent, Memory: 8.2 gigabytes, Download: 1.5 megabytes per second"
        #expect(label == "CPU: 14 percent, Memory: 8.2 gigabytes, Download: 1.5 megabytes per second")
    }

    @Test("VoiceOver label includes all five segments when enabled")
    func testVoiceOverAllSegments() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = true
        settings.showMemory = true
        settings.showNetwork = true
        settings.showDisk = true
        settings.showBattery = true

        let cpu = CPUStats(usageFraction: 0.25)
        let memory = MemoryStats(usedBytes: 16_000_000_000, totalBytes: 32_000_000_000, pressure: .normal)
        let network = NetworkStats(uploadBytesPerSecond: 500, downloadBytesPerSecond: 512_000) // 500 KB/s
        let disk = DiskStats(totalBytes: 1_000_000_000_000, freeBytes: 600_000_000_000, usedBytes: 400_000_000_000) // ~372.5 GB
        let battery = BatteryStats(capacityFraction: 0.88, isCharging: false)

        let label = MenuBarPillView.accessibilityDescription(
            cpu: cpu,
            memory: memory,
            network: network,
            disk: disk,
            battery: battery,
            settings: settings
        )

        #expect(label.contains("CPU: 25 percent"))
        #expect(label.contains("Memory: 14.9 gigabytes"))
        #expect(label.contains("Download: 500 kilobytes per second"))
        #expect(label.contains("Disk: 372.5 gigabytes"))
        #expect(label.contains("Battery: 88 percent"))
    }

    @Test("VoiceOver label reflects charging state and low/critical battery levels")
    func testVoiceOverBatteryVariations() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = false
        settings.showMemory = false
        settings.showNetwork = false
        settings.showDisk = false
        settings.showBattery = true

        let cpu = CPUStats()
        let memory = MemoryStats()
        let network = NetworkStats()
        let disk = DiskStats()

        // 1. Charging nominal
        let battCharging = BatteryStats(capacityFraction: 0.85, isCharging: true)
        let labelCharging = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memory, network: network, disk: disk, battery: battCharging, settings: settings
        )
        #expect(labelCharging == "Battery: 85 percent, charging")

        // 2. Low battery (<= 20%)
        let battLow = BatteryStats(capacityFraction: 0.18, isCharging: false)
        let labelLow = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memory, network: network, disk: disk, battery: battLow, settings: settings
        )
        #expect(labelLow == "Battery: 18 percent, low")

        // 3. Critical battery (<= 10%)
        let battCritical = BatteryStats(capacityFraction: 0.08, isCharging: false)
        let labelCritical = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memory, network: network, disk: disk, battery: battCritical, settings: settings
        )
        #expect(labelCritical == "Battery: 8 percent, critical")

        // 4. Critical while charging
        let battCriticalCharging = BatteryStats(capacityFraction: 0.05, isCharging: true)
        let labelCritCharging = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memory, network: network, disk: disk, battery: battCriticalCharging, settings: settings
        )
        #expect(labelCritCharging == "Battery: 5 percent, charging, critical")
    }

    @Test("VoiceOver label reflects memory pressure states")
    func testVoiceOverMemoryPressure() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = false
        settings.showMemory = true
        settings.showNetwork = false
        settings.showDisk = false
        settings.showBattery = false

        let cpu = CPUStats()
        let network = NetworkStats()
        let disk = DiskStats()
        let battery = BatteryStats()

        // 1. Normal pressure
        let memNormal = MemoryStats(usedBytes: 8_804_682_957, totalBytes: 16_000_000_000, pressure: .normal)
        let labelNormal = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memNormal, network: network, disk: disk, battery: battery, settings: settings
        )
        #expect(labelNormal == "Memory: 8.2 gigabytes")

        // 2. Warning pressure
        let memWarning = MemoryStats(usedBytes: 8_804_682_957, totalBytes: 16_000_000_000, pressure: .warning)
        let labelWarning = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memWarning, network: network, disk: disk, battery: battery, settings: settings
        )
        #expect(labelWarning == "Memory: 8.2 gigabytes, warning pressure")

        // 3. Critical pressure
        let memCritical = MemoryStats(usedBytes: 8_804_682_957, totalBytes: 16_000_000_000, pressure: .critical)
        let labelCritical = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memCritical, network: network, disk: disk, battery: battery, settings: settings
        )
        #expect(labelCritical == "Memory: 8.2 gigabytes, critical pressure")
    }

    @Test("VoiceOver label omits battery on desktop hardware even when enabled in settings")
    func testVoiceOverDesktopBatteryOmission() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = true
        settings.showMemory = false
        settings.showNetwork = false
        settings.showDisk = false
        settings.showBattery = true

        let cpu = CPUStats(usageFraction: 0.10)
        let memory = MemoryStats()
        let network = NetworkStats()
        let disk = DiskStats()
        let desktopBattery = BatteryStats.noBattery

        let label = MenuBarPillView.accessibilityDescription(
            cpu: cpu, memory: memory, network: network, disk: disk, battery: desktopBattery, settings: settings
        )

        #expect(label == "CPU: 10 percent")
        #expect(!label.contains("Battery"))
    }

    @Test("VoiceOver label returns fallback when all segments are toggled off")
    func testVoiceOverAllDisabled() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = false
        settings.showMemory = false
        settings.showNetwork = false
        settings.showDisk = false
        settings.showBattery = false

        let label = MenuBarPillView.accessibilityDescription(
            cpu: CPUStats(), memory: MemoryStats(), network: NetworkStats(), disk: DiskStats(), battery: BatteryStats(), settings: settings
        )

        #expect(label == "StatsBar")
    }

    @Test("VoiceOver network formatting across unit magnitudes")
    func testVoiceOverNetworkUnits() {
        let netGB = NetworkStats(downloadBytesPerSecond: 2_147_483_648) // 2.0 GB/s
        let netMB = NetworkStats(downloadBytesPerSecond: 1_572_864)     // 1.5 MB/s
        let netKB = NetworkStats(downloadBytesPerSecond: 46_080)        // 45 KB/s
        let netB = NetworkStats(downloadBytesPerSecond: 120)            // 120 B/s

        #expect(MenuBarPillView.formatSpokenNetwork(netGB) == "Download: 2.0 gigabytes per second")
        #expect(MenuBarPillView.formatSpokenNetwork(netMB) == "Download: 1.5 megabytes per second")
        #expect(MenuBarPillView.formatSpokenNetwork(netKB) == "Download: 45 kilobytes per second")
        #expect(MenuBarPillView.formatSpokenNetwork(netB) == "Download: 120 bytes per second")
    }

    // MARK: - 2. Warning State & Tint Calculation

    @Test("Nominal state returns monochrome primary tint")
    func testNominalWarningTint() {
        let state = MenuBarPillView.warningState(
            memoryPressure: .normal,
            battery: BatteryStats(capacityFraction: 0.80)
        )
        #expect(state == .nominal)
        #expect(MenuBarPillView.warningTint(for: state) == .primary)
        #expect(MenuBarPillView.warningTint(memoryPressure: .normal, battery: BatteryStats(capacityFraction: 0.80)) == .primary)
    }

    @Test("Memory pressure warning triggers amber warning tint")
    func testMemoryPressureWarningTint() {
        let state = MenuBarPillView.warningState(
            memoryPressure: .warning,
            battery: BatteryStats(capacityFraction: 0.80)
        )
        #expect(state == .warning)
        #expect(MenuBarPillView.warningTint(for: state) == DesignTokens.Colors.warning)
    }

    @Test("Battery level <= 20% triggers amber warning tint")
    func testBatteryWarningTint() {
        let state = MenuBarPillView.warningState(
            memoryPressure: .normal,
            battery: BatteryStats(capacityFraction: 0.20)
        )
        #expect(state == .warning)
        #expect(MenuBarPillView.warningTint(for: state) == DesignTokens.Colors.warning)
    }

    @Test("Memory pressure critical triggers red critical tint")
    func testMemoryPressureCriticalTint() {
        let state = MenuBarPillView.warningState(
            memoryPressure: .critical,
            battery: BatteryStats(capacityFraction: 0.80)
        )
        #expect(state == .critical)
        #expect(MenuBarPillView.warningTint(for: state) == DesignTokens.Colors.critical)
    }

    @Test("Battery level <= 10% triggers red critical tint")
    func testBatteryCriticalTint() {
        let state = MenuBarPillView.warningState(
            memoryPressure: .normal,
            battery: BatteryStats(capacityFraction: 0.10)
        )
        #expect(state == .critical)
        #expect(MenuBarPillView.warningTint(for: state) == DesignTokens.Colors.critical)
    }

    @Test("Critical condition takes precedence over warning condition")
    func testCriticalPrecedenceOverWarning() {
        // Warning memory, critical battery
        let state1 = MenuBarPillView.warningState(
            memoryPressure: .warning,
            battery: BatteryStats(capacityFraction: 0.08)
        )
        #expect(state1 == .critical)
        #expect(MenuBarPillView.warningTint(for: state1) == DesignTokens.Colors.critical)

        // Critical memory, warning battery
        let state2 = MenuBarPillView.warningState(
            memoryPressure: .critical,
            battery: BatteryStats(capacityFraction: 0.18)
        )
        #expect(state2 == .critical)
        #expect(MenuBarPillView.warningTint(for: state2) == DesignTokens.Colors.critical)
    }

    @Test("Desktop hardware without battery does not trigger false warnings")
    func testDesktopNoBatteryWarningSafety() {
        let state = MenuBarPillView.warningState(
            memoryPressure: .normal,
            battery: BatteryStats.noBattery
        )
        #expect(state == .nominal)
        #expect(MenuBarPillView.warningTint(for: state) == .primary)
    }

    @Test("Individual segment warning state calculations")
    func testIndividualSegmentWarningStates() {
        // Memory
        #expect(MenuBarPillView.memoryWarningState(pressure: .normal) == .nominal)
        #expect(MenuBarPillView.memoryWarningState(pressure: .warning) == .warning)
        #expect(MenuBarPillView.memoryWarningState(pressure: .critical) == .critical)

        // Battery
        #expect(MenuBarPillView.batteryWarningState(battery: BatteryStats(capacityFraction: 0.95)) == .nominal)
        #expect(MenuBarPillView.batteryWarningState(battery: BatteryStats(capacityFraction: 0.20)) == .warning)
        #expect(MenuBarPillView.batteryWarningState(battery: BatteryStats(capacityFraction: 0.10)) == .critical)
        #expect(MenuBarPillView.batteryWarningState(battery: BatteryStats.noBattery) == .nominal)
    }

    // MARK: - 3. Segment Visibility Logic

    @Test("Active segments default to CPU, Memory, and Network")
    func testActiveSegmentsDefault() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)

        let segments = MenuBarPillView.activeSegments(settings: settings, hasBattery: true)
        #expect(segments == [.cpu, .memory, .network])
    }

    @Test("Active segments include all five items when enabled on battery-equipped device")
    func testActiveSegmentsAllOnLaptop() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = true
        settings.showMemory = true
        settings.showNetwork = true
        settings.showDisk = true
        settings.showBattery = true

        let segments = MenuBarPillView.activeSegments(settings: settings, hasBattery: true)
        #expect(segments == [.cpu, .memory, .network, .disk, .battery])
    }

    @Test("Active segments omit battery on desktop device even when showBattery is true")
    func testActiveSegmentsDesktopOmitsBattery() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = true
        settings.showMemory = true
        settings.showNetwork = true
        settings.showDisk = true
        settings.showBattery = true

        let segments = MenuBarPillView.activeSegments(settings: settings, hasBattery: false)
        #expect(segments == [.cpu, .memory, .network, .disk])
    }

    @Test("Active segments preserve strict fixed order regardless of enablement sequence")
    func testActiveSegmentsPreserveFixedOrder() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = false
        settings.showMemory = false
        settings.showNetwork = true
        settings.showDisk = true
        settings.showBattery = false

        let segments = MenuBarPillView.activeSegments(settings: settings, hasBattery: true)
        #expect(segments == [.network, .disk])

        settings.showCPU = true
        let reordered = MenuBarPillView.activeSegments(settings: settings, hasBattery: true)
        #expect(reordered == [.cpu, .network, .disk])
    }

    @Test("Active segments returns empty array when all segments disabled")
    func testActiveSegmentsEmpty() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)
        settings.showCPU = false
        settings.showMemory = false
        settings.showNetwork = false
        settings.showDisk = false
        settings.showBattery = false

        let segments = MenuBarPillView.activeSegments(settings: settings, hasBattery: true)
        #expect(segments.isEmpty)
    }

    // MARK: - 4. Layout Constants & Pill Formatters

    @Test("Fixed segment widths ensure zero-jitter layout reservation")
    func testSegmentReservedWidths() {
        #expect(MenuBarPillView.SegmentWidths.cpu == 48)
        #expect(MenuBarPillView.SegmentWidths.memory == 52)
        #expect(MenuBarPillView.SegmentWidths.network == 46)
        #expect(MenuBarPillView.SegmentWidths.disk == 54)
        #expect(MenuBarPillView.SegmentWidths.battery == 46)
    }

    @Test("Pill formatters produce abbreviated and stable unit strings")
    func testPillFormatters() {
        // Memory
        #expect(MenuBarPillView.formatPillMemory(8_804_682_957) == "8.2G")

        // Network
        #expect(MenuBarPillView.formatPillNetwork(1_572_864) == "1.5M")
        #expect(MenuBarPillView.formatPillNetwork(46_080) == "45K")
        #expect(MenuBarPillView.formatPillNetwork(120) == "120B")
        #expect(MenuBarPillView.formatPillNetwork(2_147_483_648) == "2.0G")

        // Disk
        #expect(MenuBarPillView.formatPillDisk(170_728_570_880) == "159G")
        #expect(MenuBarPillView.formatPillDisk(53_687_091_200) == "50.0G")
    }

    @Test("MenuBarPillView coordinates with TelemetryCoordinator via accessibility label")
    func testCoordinatorAccessibilityLabelIntegration() {
        let mock = MockTelemetryProvider(
            cpu: CPUStats(usageFraction: 0.14),
            memory: MemoryStats(usedBytes: 8_804_682_957, totalBytes: 17_179_869_184, pressure: .normal),
            network: NetworkStats(uploadBytesPerSecond: 0, downloadBytesPerSecond: 1_572_864)
        )
        let coordinator = TelemetryCoordinator(provider: mock, autoStart: false)
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)

        // Seed coordinator manually for synchronous test assertion
        coordinator.currentCPU = mock.cpuToReturn
        coordinator.currentMemory = mock.memoryToReturn
        coordinator.currentNetwork = mock.networkToReturn

        let label = MenuBarPillView.accessibilityDescription(coordinator: coordinator, settings: settings)
        #expect(label == "CPU: 14 percent, Memory: 8.2 gigabytes, Download: 1.5 megabytes per second")
    }
}
