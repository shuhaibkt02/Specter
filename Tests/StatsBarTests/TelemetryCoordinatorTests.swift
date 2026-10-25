import Testing
import Foundation
import StatsBarCore

@Suite("TelemetryCoordinator Tests")
@MainActor
struct TelemetryCoordinatorTests {

    @Test("Coordinator ticks invoke telemetry provider")
    func testCoordinatorTick() async throws {
        let expectedCPU = CPUStats(usageFraction: 0.45)
        let expectedMem = MemoryStats(usedBytes: 8_000_000_000, totalBytes: 16_000_000_000, pressure: .normal)
        let expectedNet = NetworkStats(uploadBytesPerSecond: 1024, downloadBytesPerSecond: 2048)

        let mock = MockTelemetryProvider(cpu: expectedCPU, memory: expectedMem, network: expectedNet)
        let coordinator = TelemetryCoordinator(provider: mock, autoStart: false)

        #expect(mock.cpuSampleCount == 0)
        #expect(mock.memorySampleCount == 0)
        #expect(mock.networkSampleCount == 0)

        coordinator.tick()

        // Allow background queue tick to complete
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(mock.cpuSampleCount == 1)
        #expect(mock.memorySampleCount == 1)
        #expect(mock.networkSampleCount == 1)
        #expect(coordinator.currentCPU == expectedCPU)
        #expect(coordinator.cpuHistory == [0.45])
    }

    @Test("Popover presentation adapts sampling interval between Tier 1 and Tier 2")
    func testTwoTierAdaptivePolling() {
        let mock = MockTelemetryProvider()
        let coordinator = TelemetryCoordinator(provider: mock, autoStart: false)

        // Tier 1 (Background: popover closed) -> 2.0s
        #expect(coordinator.samplingInterval == 2.0)

        // User opens popover (Tier 2: Active dashboard) -> 1.0s
        coordinator.isPopoverPresented = true
        #expect(coordinator.samplingInterval == 1.0)

        // User closes popover (Tier 1: Background idle) -> 2.0s
        coordinator.isPopoverPresented = false
        #expect(coordinator.samplingInterval == 2.0)
    }
}
