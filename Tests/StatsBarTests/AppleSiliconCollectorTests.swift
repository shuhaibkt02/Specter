import Testing
import Darwin
import StatsBarCore

@Suite("AppleSiliconCollector Tests")
struct AppleSiliconCollectorTests {

    @Test("Detects Apple Silicon core topology on host Mac")
    func testCoreTopology() {
        let collector = CPUCollector()
        let total = collector.pCoreCount + collector.eCoreCount
        #expect(total > 0)
        #expect(collector.pCoreCount >= 0)
        #expect(collector.eCoreCount >= 0)
    }

    @Test("Samples per-core utilization and partitions clusters")
    func testSamplePerCore() {
        let collector = CPUCollector()
        // Baseline sample
        _ = collector.samplePerCore()
        // Second sample
        let (pUsage, eUsage, perCore) = collector.samplePerCore()

        #expect(pUsage >= 0.0 && pUsage <= 1.0)
        #expect(eUsage >= 0.0 && eUsage <= 1.0)
        #expect(perCore.count == collector.pCoreCount + collector.eCoreCount)
    }

    @Test("ThermalCollector reads valid system thermal state description")
    func testThermalState() {
        let state = ThermalCollector.currentThermalState()
        #expect(["Nominal", "Fair", "Serious", "Critical"].contains(state))
    }

    @Test("ThermalCollector queries SoC temperatures without crashing")
    func testTemperatureReading() {
        let collector = ThermalCollector()
        let temp = collector.sampleTemperature()
        if let t = temp {
            #expect(t >= 15.0 && t <= 125.0)
        }
    }

    @Test("AppleSiliconStats formats temperature cleanly")
    func testModelFormatting() {
        let stats = AppleSiliconStats(socTemperatureCelsius: 42.6)
        #expect(stats.formattedTemperature == "43°C")

        let nilStats = AppleSiliconStats(socTemperatureCelsius: nil)
        #expect(nilStats.formattedTemperature == "--°C")
    }
}
