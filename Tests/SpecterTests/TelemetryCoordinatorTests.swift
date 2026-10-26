import Testing
import Foundation
import SpecterCore

@Suite("TelemetryCoordinator Tests")
@MainActor
struct TelemetryCoordinatorTests {

    @Test("Coordinator ticks invoke telemetry provider")
    func testCoordinatorTick() async throws {
        let expectedCPU = CPUStats(usageFraction: 0.45)
        let expectedMem = MemoryStats(usedBytes: 8_000_000_000, totalBytes: 16_000_000_000, pressure: .normal)
        let expectedNet = NetworkStats(uploadBytesPerSecond: 1024, downloadBytesPerSecond: 2048)
        let expectedDisk = DiskStats(totalBytes: 500_000_000_000, freeBytes: 300_000_000_000, usedBytes: 200_000_000_000, readBytesPerSecond: 5000, writeBytesPerSecond: 10000)
        let expectedBattery = BatteryStats(capacityFraction: 0.85, isCharging: true, isACPower: true, timeRemainingMinutes: 45)

        let mock = MockTelemetryProvider(cpu: expectedCPU, memory: expectedMem, network: expectedNet, disk: expectedDisk, battery: expectedBattery)
        let coordinator = TelemetryCoordinator(provider: mock, autoStart: false)

        #expect(mock.cpuSampleCount == 0)
        #expect(mock.memorySampleCount == 0)
        #expect(mock.networkSampleCount == 0)
        #expect(mock.diskSampleCount == 0)
        #expect(mock.batterySampleCount == 0)

        coordinator.tick()

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(mock.cpuSampleCount == 1)
        #expect(mock.memorySampleCount == 1)
        #expect(mock.networkSampleCount == 1)
        #expect(mock.diskSampleCount == 1)
        #expect(mock.batterySampleCount == 1)
        #expect(coordinator.currentCPU == expectedCPU)
        #expect(coordinator.currentDisk == expectedDisk)
        #expect(coordinator.currentBattery == expectedBattery)
        #expect(coordinator.cpuHistory == [0.45])
    }

    @Test("Two-tier polling completely suspends process polling when popover is closed")
    func testTwoTierProcessSuspension() async throws {
        let sampleProcesses = [
            ProcessSnapshot(id: 100, name: "WindowServer", cpuFraction: 0.12),
            ProcessSnapshot(id: 101, name: "Xcode", cpuFraction: 0.25)
        ]
        let mock = MockTelemetryProvider(processes: sampleProcesses)
        let coordinator = TelemetryCoordinator(provider: mock, autoStart: false)

        // Popover closed (Tier 1: Background mode)
        coordinator.isPopoverPresented = false
        coordinator.tick()
        try await Task.sleep(nanoseconds: 50_000_000)

        // Process collector must NEVER be called while popover is closed!
        #expect(mock.processSampleCount == 0)
        #expect(coordinator.topProcesses.isEmpty)

        // Popover opened (Tier 2: Active dashboard mode)
        coordinator.isPopoverPresented = true
        try await Task.sleep(nanoseconds: 50_000_000)

        // Process collector must now be invoked and state published
        #expect(mock.processSampleCount == 1)
        #expect(coordinator.topProcesses == sampleProcesses)
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
