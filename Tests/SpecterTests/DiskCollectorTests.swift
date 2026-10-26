import Testing
import Foundation
import SpecterCore

@Suite("DiskCollector Tests")
struct DiskCollectorTests {

    @Test("DiskCollector queries live root volume capacity with positive values")
    func testRootVolumeCapacityQuery() {
        let capacity = DiskCollector.readVolumeCapacity(path: "/")
        #expect(capacity.totalBytes > 0)
        #expect(capacity.freeBytes > 0)
        #expect(capacity.usedBytes > 0)
        #expect(capacity.totalBytes >= capacity.freeBytes)
        #expect(capacity.totalBytes >= capacity.usedBytes)
    }

    @Test("DiskCollector reads live IOKit block storage statistics from host driver")
    func testLiveBlockStorageCounters() {
        let counters = DiskCollector.readBlockStorageCounters()
        #expect(counters != nil)
        if let counters {
            #expect(counters.readBytes > 0)
        }
    }

    @Test("Rate calculation derives exact throughput from byte deltas and time elapsed")
    func testRateCalculationMath() {
        // 10 MB in 1.0 second (1_000_000_000 nanoseconds)
        let rate1 = DiskCollector.calculateRate(
            currentBytes: 10_485_760,
            previousBytes: 0,
            timeDeltaNanoseconds: 1_000_000_000
        )
        #expect(rate1 == 10_485_760.0)

        // 5 MB in 0.5 seconds (500_000_000 nanoseconds) -> 10 MB/s
        let rate2 = DiskCollector.calculateRate(
            currentBytes: 15_728_640,
            previousBytes: 10_485_760,
            timeDeltaNanoseconds: 500_000_000
        )
        #expect(rate2 == 10_485_760.0)

        // Zero time delta must not divide by zero
        let zeroTime = DiskCollector.calculateRate(
            currentBytes: 1_000,
            previousBytes: 0,
            timeDeltaNanoseconds: 0
        )
        #expect(zeroTime == 0.0)

        // Zero byte delta produces zero throughput
        let zeroBytes = DiskCollector.calculateRate(
            currentBytes: 5_000,
            previousBytes: 5_000,
            timeDeltaNanoseconds: 1_000_000_000
        )
        #expect(zeroBytes == 0.0)

        // Counter regression / driver reset handles cleanly without negative rate
        let regression = DiskCollector.calculateRate(
            currentBytes: 500,
            previousBytes: 1_000,
            timeDeltaNanoseconds: 1_000_000_000
        )
        #expect(regression == 0.0)
    }

    @Test("Synthetic sampling handles baseline initialization, active throughput, and reset")
    func testSyntheticSamplingProgression() {
        let collector = DiskCollector()
        let mockCapacity = (
            totalBytes: UInt64(500_000_000_000),
            freeBytes: UInt64(300_000_000_000),
            usedBytes: UInt64(200_000_000_000)
        )

        // Tick 1: Establishing initial baseline
        let tick1 = collector.sample(
            currentTimeNanoseconds: 1_000_000_000,
            counters: (readBytes: 100_000, writeBytes: 50_000),
            capacity: mockCapacity
        )
        #expect(tick1.readBytesPerSecond == 0.0)
        #expect(tick1.writeBytesPerSecond == 0.0)
        #expect(tick1.totalBytes == 500_000_000_000)
        #expect(tick1.freeBytes == 300_000_000_000)
        #expect(tick1.usedBytes == 200_000_000_000)

        // Tick 2: 1.0s later, 1 MB read and 2 MB written
        let tick2 = collector.sample(
            currentTimeNanoseconds: 2_000_000_000,
            counters: (readBytes: 100_000 + 1_048_576, writeBytes: 50_000 + 2_097_152),
            capacity: mockCapacity
        )
        #expect(tick2.readBytesPerSecond == 1_048_576.0)
        #expect(tick2.writeBytesPerSecond == 2_097_152.0)
        #expect(tick2.formattedReadMBs == "1.0 MB/s")
        #expect(tick2.formattedWriteMBs == "2.0 MB/s")

        // Tick 3: Counter resets due to driver remount or unplug
        let tick3 = collector.sample(
            currentTimeNanoseconds: 3_000_000_000,
            counters: (readBytes: 100, writeBytes: 50),
            capacity: mockCapacity
        )
        #expect(tick3.readBytesPerSecond == 0.0)
        #expect(tick3.writeBytesPerSecond == 0.0)

        // Tick 4: Re-established baseline continues cleanly
        let tick4 = collector.sample(
            currentTimeNanoseconds: 4_000_000_000,
            counters: (readBytes: 100 + 524_288, writeBytes: 50 + 1_048_576),
            capacity: mockCapacity
        )
        #expect(tick4.readBytesPerSecond == 524_288.0)
        #expect(tick4.writeBytesPerSecond == 1_048_576.0)
        #expect(tick4.formattedReadMBs == "0.5 MB/s")
        #expect(tick4.formattedWriteMBs == "1.0 MB/s")
    }

    @Test("DiskStats formats storage capacity and throughput correctly")
    func testDiskStatsFormatting() {
        let stats = DiskStats(
            totalBytes: 536_870_912_000, // 500 GB
            freeBytes: 322_122_547_200,  // 300 GB
            usedBytes: 214_748_364_800,  // 200 GB
            readBytesPerSecond: 10_485_760.0, // 10 MB/s
            writeBytesPerSecond: 20_971_520.0 // 20 MB/s
        )
        #expect(stats.formattedTotalGB == "500.0 GB")
        #expect(stats.formattedFreeGB == "300.0 GB")
        #expect(stats.formattedUsedGB == "200.0 GB")
        #expect(stats.formattedReadMBs == "10.0 MB/s")
        #expect(stats.formattedWriteMBs == "20.0 MB/s")
        #expect(stats.usedFraction == 0.4)
        #expect(stats.percentageString == "40%")
    }
}
