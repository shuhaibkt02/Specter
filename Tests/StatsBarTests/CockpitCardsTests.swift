import Testing
import SwiftUI
import StatsBarCore

@Suite("CockpitCards Tests")
@MainActor
struct CockpitCardsTests {

    // MARK: - CPUCardView Tests

    @Test("CPUCardView model binding and process row formatting")
    func testCPUCardViewModelBindingAndProcessFormatting() {
        let cpu = CPUStats(usageFraction: 0.32)
        let silicon = AppleSiliconStats(
            pCoreCount: 8,
            eCoreCount: 4,
            pCoreUsageFraction: 0.38,
            eCoreUsageFraction: 0.21,
            perCoreUsage: [0.38, 0.21],
            socTemperatureCelsius: 41.0,
            thermalStateDescription: "Nominal"
        )
        let processes = [
            ProcessSnapshot(id: 1234, name: "com.apple.Safari", cpuFraction: 0.182),
            ProcessSnapshot(id: 5678, name: "Xcode", cpuFraction: 0.094)
        ]

        let card = CPUCardView(
            cpu: cpu,
            history: [0.10, 0.25, 0.32],
            silicon: silicon,
            topProcesses: processes
        )

        #expect(card.liveValue == "32%")
        #expect(card.formattedTemperature == "41°C")
        #expect(card.history.count == 3)
        #expect(card.silicon.pCoreCount == 8)
        #expect(card.silicon.eCoreCount == 4)
        #expect(card.silicon.pCoreUsageFraction == 0.38)
        #expect(card.silicon.eCoreUsageFraction == 0.21)

        // ProcessRowView validation
        let row0 = ProcessRowView(process: processes[0])
        #expect(row0.nameText == "com.apple.Safari")
        #expect(row0.pidText == "(1234)")
        #expect(row0.percentageText == "18%")

        let row1 = ProcessRowView(process: processes[1])
        #expect(row1.nameText == "Xcode")
        #expect(row1.pidText == "(5678)")
        #expect(row1.percentageText == "9%")

        // Test safe quit callback invocation
        var quitPid: pid_t?
        let rowWithCallback = ProcessRowView(process: processes[0]) { pid in
            quitPid = pid
        }
        rowWithCallback.onQuit?(1234)
        #expect(quitPid == 1234)
    }

    // MARK: - MemoryCardView Tests

    @Test("MemoryCardView status dot color and breakdown values")
    func testMemoryCardViewStatusDotColorAndBreakdownValues() {
        // Normal memory pressure
        let normalMem = MemoryStats(
            usedBytes: 6_871_947_674, // ~6.4 GB
            totalBytes: 17_179_869_184, // 16.0 GB
            pressure: .normal,
            activeBytes: 3_328_599_654, // ~3.1 GB
            inactiveBytes: 1_073_741_824,
            wiredBytes: 1_288_490_188, // ~1.2 GB
            compressedBytes: 536_870_912, // ~0.5 GB
            purgeableBytes: 1_073_741_824,
            externalBytes: 1_181_116_006, // purgeable + external = ~2.1 GB cached
            swap: SwapStats(usedBytes: 0, totalBytes: 2_147_483_648)
        )
        let normalCard = MemoryCardView(memory: normalMem, history: [0.35, 0.40])
        #expect(normalCard.liveValue == "6.4 GB / 16.0 GB")
        #expect(normalCard.statusDotColor == DesignTokens.Colors.normal)
        #expect(normalCard.statusText == "Normal")
        #expect(normalCard.breakdownSummary.contains("Wired 1.2 GB"))
        #expect(normalCard.breakdownSummary.contains("Active 3.1 GB"))
        #expect(normalCard.breakdownSummary.contains("Compressed 0.5 GB"))
        #expect(normalCard.breakdownSummary.contains("Cached 2.1 GB"))
        #expect(normalCard.swapSummary == "Swap 0 B")

        // Warning memory pressure
        let warningMem = MemoryStats(
            usedBytes: 14_000_000_000,
            totalBytes: 16_000_000_000,
            pressure: .warning,
            swap: SwapStats(usedBytes: 1_073_741_824, totalBytes: 2_147_483_648)
        )
        let warningCard = MemoryCardView(memory: warningMem)
        #expect(warningCard.statusDotColor == DesignTokens.Colors.warning)
        #expect(warningCard.statusText == "Warning")
        #expect(warningCard.swapSummary == "Swap 1.0 GB")

        // Critical memory pressure
        let criticalMem = MemoryStats(
            usedBytes: 15_800_000_000,
            totalBytes: 16_000_000_000,
            pressure: .critical
        )
        let criticalCard = MemoryCardView(memory: criticalMem)
        #expect(criticalCard.statusDotColor == DesignTokens.Colors.critical)
        #expect(criticalCard.statusText == "Critical")
    }

    // MARK: - NetworkCardView Tests

    @Test("NetworkCardView rate display and interface labeling")
    func testNetworkCardViewRateDisplayAndInterfaceLabeling() {
        let netWithIP = NetworkStats(
            uploadBytesPerSecond: 348_160,    // 340 KB/s
            downloadBytesPerSecond: 1_258_291, // 1.2 MB/s
            interfaceName: "en0",
            localIP: "192.168.1.42"
        )
        let cardWithIP = NetworkCardView(network: netWithIP, history: [0.2, 0.4, 0.8])
        #expect(cardWithIP.liveValue == "↓ 1.2 MB/s  ↑ 340 KB/s")
        #expect(cardWithIP.interfaceLabel == "en0 · 192.168.1.42")
        #expect(cardWithIP.history.count == 3)

        // Without IP (active fallback)
        let netWithoutIP = NetworkStats(
            uploadBytesPerSecond: 0,
            downloadBytesPerSecond: 500,
            interfaceName: "en1",
            localIP: nil
        )
        let cardWithoutIP = NetworkCardView(network: netWithoutIP)
        #expect(cardWithoutIP.liveValue == "↓ 500 B/s  ↑ 0 B/s")
        #expect(cardWithoutIP.interfaceLabel == "en1 · active")
    }

    // MARK: - DiskCardView Tests

    @Test("DiskCardView capacity fraction calculations and throughput formatting")
    func testDiskCardViewCapacityAndThroughput() {
        let disk = DiskStats(
            totalBytes: 994_000_000_000,
            freeBytes: 582_000_000_000,
            usedBytes: 412_000_000_000,
            readBytesPerSecond: 12_582_912, // 12.0 MB/s
            writeBytesPerSecond: 3_145_728   // 3.0 MB/s
        )
        let card = DiskCardView(disk: disk)
        #expect(card.liveValue == "\(disk.formattedUsedGB) / \(disk.formattedTotalGB)")
        #expect(card.capacityFraction > 0.41 && card.capacityFraction < 0.42)
        #expect(card.throughputSummary == "Read 12.0 MB/s · Write 3.0 MB/s")

        // Zero totalBytes safeguard
        let emptyDisk = DiskStats(totalBytes: 0, freeBytes: 0, usedBytes: 0)
        let emptyCard = DiskCardView(disk: emptyDisk)
        #expect(emptyCard.capacityFraction == 0.0)
    }

    // MARK: - BatteryCardView Tests

    @Test("BatteryCardView charging glyph and health display")
    func testBatteryCardViewChargingGlyphAndHealth() {
        // Discharging on battery
        let discharging = BatteryStats(
            capacityFraction: 0.87,
            isCharging: false,
            isACPower: false,
            timeRemainingMinutes: 72,
            percentageString: "87%",
            hasBattery: true,
            healthPercentage: 94,
            condition: "Normal"
        )
        let dischargingCard = BatteryCardView(battery: discharging)
        #expect(dischargingCard.liveValue == "87%")
        #expect(!dischargingCard.liveValue.contains("⚡"))
        #expect(dischargingCard.statusText == "Discharging")
        #expect(dischargingCard.statusDotColor == nil)
        #expect(dischargingCard.breakdownSummary == "94% health · Normal · 1h 12m")

        // Actively charging
        let charging = BatteryStats(
            capacityFraction: 0.45,
            isCharging: true,
            isACPower: true,
            timeRemainingMinutes: 40,
            percentageString: "45%",
            hasBattery: true,
            healthPercentage: 98,
            condition: "Normal"
        )
        let chargingCard = BatteryCardView(battery: charging)
        #expect(chargingCard.liveValue == "45% ⚡")
        #expect(chargingCard.statusText == "Charging")
        #expect(chargingCard.breakdownSummary == "98% health · Normal · 40m")

        // Charged on AC Power
        let charged = BatteryStats(
            capacityFraction: 1.0,
            isCharging: false,
            isACPower: true,
            timeRemainingMinutes: nil,
            percentageString: "100%",
            hasBattery: true,
            healthPercentage: 100,
            condition: "Normal"
        )
        let chargedCard = BatteryCardView(battery: charged)
        #expect(chargedCard.liveValue == "100%")
        #expect(chargedCard.statusText == "Charged")

        // Low battery critical warning status dot (<= 10%)
        let criticalBattery = BatteryStats(
            capacityFraction: 0.08,
            isCharging: false,
            isACPower: false,
            percentageString: "8%",
            hasBattery: true
        )
        let criticalCard = BatteryCardView(battery: criticalBattery)
        #expect(criticalCard.statusDotColor == DesignTokens.Colors.critical)

        // Low battery warning status dot (<= 20%)
        let warningBattery = BatteryStats(
            capacityFraction: 0.18,
            isCharging: false,
            isACPower: false,
            percentageString: "18%",
            hasBattery: true
        )
        let warningCard = BatteryCardView(battery: warningBattery)
        #expect(warningCard.statusDotColor == DesignTokens.Colors.warning)

        // Desktop Mac without internal battery
        let desktop = BatteryStats.noBattery
        let desktopCard = BatteryCardView(battery: desktop)
        #expect(desktopCard.liveValue == "0%")
        #expect(desktopCard.statusText == "On AC Power")
        #expect(desktopCard.statusDotColor == nil)
        #expect(desktopCard.breakdownSummary == "")
    }

    // MARK: - Coordinator History Integration Tests

    @Test("Coordinator maintains memory and network history arrays capped at 30 items")
    func testCoordinatorHistoryArrayCaps() async throws {
        let mock = MockTelemetryProvider(
            cpu: CPUStats(usageFraction: 0.5),
            memory: MemoryStats(usedBytes: 4_000_000_000, totalBytes: 8_000_000_000),
            network: NetworkStats(uploadBytesPerSecond: 1000, downloadBytesPerSecond: 500_000)
        )
        let coordinator = TelemetryCoordinator(provider: mock, autoStart: false)

        #expect(coordinator.memoryHistory.isEmpty)
        #expect(coordinator.networkHistory.isEmpty)

        // Run 35 ticks
        for _ in 0..<35 {
            coordinator.tick()
        }

        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(coordinator.cpuHistory.count <= 30)
        #expect(coordinator.memoryHistory.count <= 30)
        #expect(coordinator.networkHistory.count <= 30)
        #expect(!coordinator.memoryHistory.isEmpty)
        #expect(!coordinator.networkHistory.isEmpty)

        // Cards initialize properly with coordinator
        let cpuCard = CPUCardView(coordinator: coordinator)
        let memCard = MemoryCardView(coordinator: coordinator)
        let netCard = NetworkCardView(coordinator: coordinator)
        let diskCard = DiskCardView(coordinator: coordinator)
        let batCard = BatteryCardView(coordinator: coordinator)

        #expect(cpuCard.liveValue == "50%")
        #expect(memCard.liveValue.contains("GB"))
        #expect(!netCard.liveValue.isEmpty)
        #expect(!diskCard.liveValue.isEmpty)
        #expect(!batCard.liveValue.isEmpty)
    }
}
