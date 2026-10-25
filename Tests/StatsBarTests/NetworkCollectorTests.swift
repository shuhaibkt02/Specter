import Testing
import Foundation
import StatsBarCore

@Suite("NetworkCollector Tests")
struct NetworkCollectorTests {

    @Test("Calculates exact transfer rates from synthetic byte deltas over elapsed time")
    func testSyntheticRateCalculation() {
        let prev = (inBytes: UInt64(10_000_000), outBytes: UInt64(5_000_000), timestampNanos: UInt64(1_000_000_000))
        // 1 second later: +1,048,576 bytes down (1 MB), +524,288 bytes up (512 KB)
        let curr = (inBytes: UInt64(11_048_576), outBytes: UInt64(5_524_288), timestampNanos: UInt64(2_000_000_000))

        let stats = NetworkCollector.calculateRates(previous: prev, current: curr)

        #expect(abs(stats.downloadBytesPerSecond - 1_048_576.0) < 0.001)
        #expect(abs(stats.uploadBytesPerSecond - 524_288.0) < 0.001)
        #expect(stats.formattedDownload == "1.0 MB/s")
        #expect(stats.formattedUpload == "512 KB/s")
    }

    @Test("Handles fractional second deltas accurately")
    func testFractionalTimeDelta() {
        // 500ms elapsed (0.5s), 500,000 bytes down -> 1,000,000 bytes/sec
        let prev = (inBytes: UInt64(0), outBytes: UInt64(0), timestampNanos: UInt64(1_000_000_000))
        let curr = (inBytes: UInt64(500_000), outBytes: UInt64(250_000), timestampNanos: UInt64(1_500_000_000))

        let stats = NetworkCollector.calculateRates(previous: prev, current: curr)

        #expect(abs(stats.downloadBytesPerSecond - 1_000_000.0) < 0.001)
        #expect(abs(stats.uploadBytesPerSecond - 500_000.0) < 0.001)
    }

    @Test("Guards against zero or negative elapsed time without division by zero")
    func testZeroOrNegativeElapsedTime() {
        let sample = (inBytes: UInt64(1000), outBytes: UInt64(1000), timestampNanos: UInt64(5_000_000))
        let earlierSample = (inBytes: UInt64(2000), outBytes: UInt64(2000), timestampNanos: UInt64(4_000_000))

        let zeroStats = NetworkCollector.calculateRates(previous: sample, current: sample)
        #expect(zeroStats.downloadBytesPerSecond == 0.0)
        #expect(zeroStats.uploadBytesPerSecond == 0.0)

        let negativeStats = NetworkCollector.calculateRates(previous: sample, current: earlierSample)
        #expect(negativeStats.downloadBytesPerSecond == 0.0)
        #expect(negativeStats.uploadBytesPerSecond == 0.0)
    }

    @Test("Handles 64-bit integer wraparound gracefully with wrapping subtraction")
    func testWraparoundSubtraction() {
        // inBytes wraps from UInt64.max - 1023 to 0 -> delta is 1024 bytes
        // outBytes wraps from UInt64.max - 2047 to 0 -> delta is 2048 bytes
        let prev = (inBytes: UInt64.max - 1023, outBytes: UInt64.max - 2047, timestampNanos: UInt64(1_000_000_000))
        let curr = (inBytes: UInt64(0), outBytes: UInt64(0), timestampNanos: UInt64(2_000_000_000))

        let stats = NetworkCollector.calculateRates(previous: prev, current: curr)

        #expect(abs(stats.downloadBytesPerSecond - 1024.0) < 0.001)
        #expect(abs(stats.uploadBytesPerSecond - 2048.0) < 0.001)
    }

    @Test("First sample establishes baseline and returns zero rates")
    func testFirstSampleBaseline() {
        let collector = NetworkCollector()
        let stats = collector.sample()

        #expect(stats.downloadBytesPerSecond == 0.0)
        #expect(stats.uploadBytesPerSecond == 0.0)
    }

    @Test("Correctly identifies and skips virtual VPN / tunnel adapters")
    func testVirtualInterfaceDetection() {
        #expect(NetworkCollector.isVirtualInterface("utun0"))
        #expect(NetworkCollector.isVirtualInterface("utun4"))
        #expect(NetworkCollector.isVirtualInterface("ipsec0"))
        #expect(NetworkCollector.isVirtualInterface("lo0"))
        #expect(NetworkCollector.isVirtualInterface("awdl0"))
        #expect(NetworkCollector.isVirtualInterface("llw0"))
        #expect(NetworkCollector.isVirtualInterface("bridge0"))

        #expect(!NetworkCollector.isVirtualInterface("en0"))
        #expect(!NetworkCollector.isVirtualInterface("en1"))
        #expect(!NetworkCollector.isVirtualInterface("en7"))
    }

    @Test("Resolves active physical interface on host machine")
    func testLiveActiveInterfaceResolution() {
        let active = NetworkCollector.resolveActiveInterfaceName()
        #expect(!active.isEmpty)
        #expect(!NetworkCollector.isVirtualInterface(active))

        let index = NetworkCollector.interfaceIndex(forName: active)
        #expect(index != nil)
        #expect((index ?? 0) > 0)
    }

    @Test("Queries BSD routing table sysctl for active interface with non-negative byte count")
    func testLiveInterfaceByteCountQuery() {
        let active = NetworkCollector.resolveActiveInterfaceName()
        guard let index = NetworkCollector.interfaceIndex(forName: active) else {
            Issue.record("Could not resolve index for interface \(active)")
            return
        }

        let bytes = NetworkCollector.readInterfaceBytes(ifIndex: index)
        #expect(bytes != nil)
        if let bytes {
            #expect(bytes.inBytes >= 0)
            #expect(bytes.outBytes >= 0)
        }
    }

    @Test("Consecutive samples produce valid non-negative telemetry rates")
    func testConsecutiveLiveSampling() async throws {
        let collector = NetworkCollector()

        // Tick 1: Baseline
        let tick1 = collector.sample()
        #expect(tick1.downloadBytesPerSecond == 0.0)
        #expect(tick1.uploadBytesPerSecond == 0.0)

        // Elapsed delay
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Tick 2: Active rate
        let tick2 = collector.sample()
        #expect(tick2.downloadBytesPerSecond >= 0.0)
        #expect(tick2.uploadBytesPerSecond >= 0.0)
    }

    @Test("Resetting collector re-establishes baseline")
    func testCollectorReset() async throws {
        let collector = NetworkCollector()
        _ = collector.sample()
        try await Task.sleep(nanoseconds: 50_000_000)

        collector.reset()
        let afterReset = collector.sample()
        #expect(afterReset.downloadBytesPerSecond == 0.0)
        #expect(afterReset.uploadBytesPerSecond == 0.0)
    }
}
