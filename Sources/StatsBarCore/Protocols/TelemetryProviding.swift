import Foundation

/// Primary testing seam: abstract interface through which the coordinator samples hardware metrics.
public protocol TelemetryProviding: Sendable {
    func sampleCPU() -> CPUStats
    func sampleMemory() -> MemoryStats
    func sampleNetwork() -> NetworkStats
    func sampleTopProcesses(limit: Int) -> [ProcessSnapshot]
}

/// A synthetic telemetry provider used in unit tests to inject deterministic data.
public final class MockTelemetryProvider: TelemetryProviding, @unchecked Sendable {
    public var cpuToReturn: CPUStats
    public var memoryToReturn: MemoryStats
    public var networkToReturn: NetworkStats
    public var processesToReturn: [ProcessSnapshot]
    
    public private(set) var cpuSampleCount: Int = 0
    public private(set) var memorySampleCount: Int = 0
    public private(set) var networkSampleCount: Int = 0
    public private(set) var processSampleCount: Int = 0

    public init(
        cpu: CPUStats = CPUStats(),
        memory: MemoryStats = MemoryStats(),
        network: NetworkStats = NetworkStats(),
        processes: [ProcessSnapshot] = []
    ) {
        self.cpuToReturn = cpu
        self.memoryToReturn = memory
        self.networkToReturn = network
        self.processesToReturn = processes
    }

    public func sampleCPU() -> CPUStats {
        cpuSampleCount += 1
        return cpuToReturn
    }

    public func sampleMemory() -> MemoryStats {
        memorySampleCount += 1
        return memoryToReturn
    }

    public func sampleNetwork() -> NetworkStats {
        networkSampleCount += 1
        return networkToReturn
    }

    public func sampleTopProcesses(limit: Int) -> [ProcessSnapshot] {
        processSampleCount += 1
        return Array(processesToReturn.prefix(limit))
    }
}
