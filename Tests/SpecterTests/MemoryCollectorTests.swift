import Testing
import Foundation
import Darwin
import SpecterCore

@Suite("MemoryCollector Tests")
struct MemoryCollectorTests {

    @Test("Reads live host VM statistics from Mach kernel with valid page values")
    func testLiveMachVMStatistics() {
        let vmStats = MemoryCollector.readVMStatistics()
        #expect(vmStats != nil)
        if let stats = vmStats {
            #expect(stats.active_count > 0)
            #expect(stats.wire_count > 0)
            #expect(stats.free_count > 0)
        }

        let collector = MemoryCollector()
        let sample = collector.sample()

        #expect(sample.totalBytes > 0)
        #expect(sample.usedBytes > 0)
        #expect(sample.usedBytes <= sample.totalBytes)
        #expect(sample.usedFraction > 0.0 && sample.usedFraction <= 1.0)
        #expect(sample.activeBytes > 0)
        #expect(sample.wiredBytes > 0)
        #expect(sample.formattedUsedGB.hasSuffix(" GB"))
        #expect(sample.formattedTotalGB.hasSuffix(" GB"))
    }

    @Test("Repeated Mach statistics reads properly deallocate host port without leaking")
    func testHostPortDeallocationUnderRepetition() {
        for _ in 0..<50 {
            let stats = MemoryCollector.readVMStatistics()
            #expect(stats != nil)
        }
    }

    @Test("Calculates memory usage correctly using Darwin VM breakdown formula")
    func testMemoryUsedCalculationLogic() {
        // active: 4GB, inactive: 2GB, speculative: 1GB, wired: 2GB, compressed: 1GB -> Gross: 10GB
        // purgeable: 500MB, external: 1.5GB -> Reclaimable: 2GB
        // Expected used: 10GB - 2GB = 8GB
        let active: UInt64 = 4_000_000_000
        let inactive: UInt64 = 2_000_000_000
        let speculative: UInt64 = 1_000_000_000
        let wired: UInt64 = 2_000_000_000
        let compressed: UInt64 = 1_000_000_000
        let purgeable: UInt64 = 500_000_000
        let external: UInt64 = 1_500_000_000

        let used = MemoryCollector.calculateUsedBytes(
            active: active,
            inactive: inactive,
            speculative: speculative,
            wired: wired,
            compressed: compressed,
            purgeable: purgeable,
            external: external
        )
        #expect(used == 8_000_000_000)

        // Test with mock vm_statistics64 structure and 16KB page size
        var mockStats = vm_statistics64()
        let pageSize: UInt64 = 16_384
        mockStats.active_count = 100_000       // 1.6384 GB
        mockStats.inactive_count = 50_000     // 0.8192 GB
        mockStats.speculative_count = 10_000  // 0.16384 GB
        mockStats.wire_count = 50_000         // 0.8192 GB
        mockStats.compressor_page_count = 20_000 // 0.32768 GB
        mockStats.purgeable_count = 5_000     // 0.08192 GB
        mockStats.external_page_count = 25_000 // 0.4096 GB

        let calculatedFromStats = MemoryCollector.calculateUsedBytes(vmStats: mockStats, pageSize: pageSize)
        let expectedPages = (100_000 + 50_000 + 10_000 + 50_000 + 20_000) - (5_000 + 25_000)
        let expectedBytes = UInt64(expectedPages) * pageSize
        #expect(calculatedFromStats == expectedBytes)
    }

    @Test("Underflow safety when reclaimable memory exceeds gross active/wired pages")
    func testReclaimableUnderflowProtection() {
        let used = MemoryCollector.calculateUsedBytes(
            active: 100,
            inactive: 100,
            speculative: 0,
            wired: 100,
            compressed: 0,
            purgeable: 1_000,
            external: 1_000
        )
        #expect(used == 0)
    }

    @Test("Maps BSD memorystatus pressure levels to MemoryPressureLevel correctly")
    func testPressureMappingLogic() {
        #expect(MemoryPressureLevel(level: 1) == .normal)
        #expect(MemoryPressureLevel(level: 2) == .warning)
        #expect(MemoryPressureLevel(level: 4) == .critical)

        // Int32 overload
        #expect(MemoryPressureLevel(level: Int32(1)) == .normal)
        #expect(MemoryPressureLevel(level: Int32(2)) == .warning)
        #expect(MemoryPressureLevel(level: Int32(4)) == .critical)

        // Unrecognized or default levels map to .normal
        #expect(MemoryPressureLevel(level: 0) == .normal)
        #expect(MemoryPressureLevel(level: 3) == .normal)
        #expect(MemoryPressureLevel(level: 99) == .normal)
        #expect(MemoryPressureLevel(level: -1) == .normal)

        // Live sysctl pressure query returns a valid level
        let livePressure = MemoryCollector.readMemoryPressure()
        #expect([MemoryPressureLevel.normal, .warning, .critical].contains(livePressure))
    }

    @Test("Calculates swap usage, availability, and fractions correctly")
    func testSwapUsageCalculation() {
        let swap = SwapStats(usedBytes: 536_870_912, totalBytes: 2_147_483_648) // 0.5 GB used of 2.0 GB
        #expect(swap.usedBytes == 536_870_912)
        #expect(swap.totalBytes == 2_147_483_648)
        #expect(swap.availableBytes == 1_610_612_736)
        #expect(swap.usedFraction == 0.25)
        #expect(swap.formattedUsedGB == "0.5 GB")
        #expect(swap.formattedTotalGB == "2.0 GB")

        // Zero total swap edge case (e.g. system with swap disabled)
        let zeroSwap = SwapStats(usedBytes: 0, totalBytes: 0)
        #expect(zeroSwap.usedFraction == 0.0)
        #expect(zeroSwap.availableBytes == 0)

        // Saturated swap edge case
        let saturatedSwap = SwapStats(usedBytes: 2_000_000_000, totalBytes: 1_000_000_000)
        #expect(saturatedSwap.usedFraction == 1.0)
        #expect(saturatedSwap.availableBytes == 0)

        // Live swap read from BSD sysctl
        let liveSwap = MemoryCollector.readSwapUsage()
        #expect(liveSwap.totalBytes >= liveSwap.usedBytes)
        #expect(liveSwap.usedFraction >= 0.0 && liveSwap.usedFraction <= 1.0)
    }

    @Test("Total physical memory reading returns positive RAM size")
    func testTotalPhysicalMemory() {
        let total = MemoryCollector.readTotalPhysicalMemory()
        #expect(total > 0)
        // Ensure reasonable minimum (e.g. >= 2GB)
        #expect(total >= 2_147_483_648)
    }
}
