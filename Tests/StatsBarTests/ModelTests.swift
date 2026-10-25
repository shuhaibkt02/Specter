import Testing
import StatsBarCore

@Suite("Domain Model Tests")
struct ModelTests {

    @Test("CPUStats clamps negative and excessive usage fractions")
    func testCPUStatsClamping() {
        let negative = CPUStats(usageFraction: -0.5)
        #expect(negative.usageFraction == 0.0)
        #expect(negative.percentageString == "0%")

        let excessive = CPUStats(usageFraction: 1.5)
        #expect(excessive.usageFraction == 1.0)
        #expect(excessive.percentageString == "100%")

        let normal = CPUStats(usageFraction: 0.354)
        #expect(normal.percentageString == "35%")
    }

    @Test("MemoryStats calculates fractions and handles pressure mapping")
    func testMemoryStats() {
        let stats = MemoryStats(
            usedBytes: 8_589_934_592, // 8 GB
            totalBytes: 17_179_869_184, // 16 GB
            pressure: .normal
        )
        #expect(stats.usedFraction == 0.5)
        #expect(stats.formattedUsedGB == "8.0 GB")

        #expect(MemoryPressureLevel(level: 1) == .normal)
        #expect(MemoryPressureLevel(level: 2) == .warning)
        #expect(MemoryPressureLevel(level: 4) == .critical)
        #expect(MemoryPressureLevel(level: 99) == .normal)
    }

    @Test("NetworkStats formats transfer rates across unit thresholds")
    func testNetworkStatsFormatting() {
        #expect(NetworkStats.formatRate(500) == "500 B/s")
        #expect(NetworkStats.formatRate(2048) == "2 KB/s")
        #expect(NetworkStats.formatRate(1_572_864) == "1.5 MB/s")
    }
}
