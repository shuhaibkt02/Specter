import Foundation

/// Primary testing seam: abstract interface through which the coordinator samples hardware metrics.
public protocol TelemetryProviding: Sendable {
    func sampleCPU() -> CPUStats
    func sampleMemory() -> MemoryStats
    func sampleNetwork() -> NetworkStats
    func sampleDisk() -> DiskStats
    func sampleBattery() -> BatteryStats
    func sampleAppleSilicon() -> AppleSiliconStats
    func sampleTopProcesses(limit: Int) -> [ProcessSnapshot]
}

/// A synthetic telemetry provider used in unit tests to inject deterministic data.
public final class MockTelemetryProvider: TelemetryProviding, @unchecked Sendable {
    public var cpuToReturn: CPUStats
    public var memoryToReturn: MemoryStats
    public var networkToReturn: NetworkStats
    public var diskToReturn: DiskStats
    public var batteryToReturn: BatteryStats
    public var appleSiliconToReturn: AppleSiliconStats
    public var processesToReturn: [ProcessSnapshot]
    
    public private(set) var cpuSampleCount: Int = 0
    public private(set) var memorySampleCount: Int = 0
    public private(set) var networkSampleCount: Int = 0
    public private(set) var diskSampleCount: Int = 0
    public private(set) var batterySampleCount: Int = 0
    public private(set) var appleSiliconSampleCount: Int = 0
    public private(set) var processSampleCount: Int = 0

    public init(
        cpu: CPUStats = CPUStats(),
        memory: MemoryStats = MemoryStats(),
        network: NetworkStats = NetworkStats(),
        disk: DiskStats = DiskStats(),
        battery: BatteryStats = BatteryStats(),
        appleSilicon: AppleSiliconStats = AppleSiliconStats(),
        processes: [ProcessSnapshot] = []
    ) {
        self.cpuToReturn = cpu
        self.memoryToReturn = memory
        self.networkToReturn = network
        self.diskToReturn = disk
        self.batteryToReturn = battery
        self.appleSiliconToReturn = appleSilicon
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

    public func sampleDisk() -> DiskStats {
        diskSampleCount += 1
        return diskToReturn
    }

    public func sampleBattery() -> BatteryStats {
        batterySampleCount += 1
        return batteryToReturn
    }

    public func sampleAppleSilicon() -> AppleSiliconStats {
        appleSiliconSampleCount += 1
        return appleSiliconToReturn
    }

    public func sampleTopProcesses(limit: Int) -> [ProcessSnapshot] {
        processSampleCount += 1
        return Array(processesToReturn.prefix(limit))
    }
}
