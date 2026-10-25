import Foundation

/// Production telemetry provider reading live hardware and process metrics from Darwin kernel APIs.
public final class SystemTelemetryProvider: TelemetryProviding, @unchecked Sendable {
    private let cpuCollector: CPUCollector
    private let memoryCollector: MemoryCollector
    private let networkCollector: NetworkCollector
    private let diskCollector: DiskCollector
    private let batteryCollector: BatteryCollector
    private let thermalCollector: ThermalCollector
    private let processCollector: ProcessCollector

    public init(
        cpuCollector: CPUCollector = CPUCollector(),
        memoryCollector: MemoryCollector = MemoryCollector(),
        networkCollector: NetworkCollector = NetworkCollector(),
        diskCollector: DiskCollector = DiskCollector(),
        batteryCollector: BatteryCollector = BatteryCollector(),
        thermalCollector: ThermalCollector = ThermalCollector(),
        processCollector: ProcessCollector = ProcessCollector()
    ) {
        self.cpuCollector = cpuCollector
        self.memoryCollector = memoryCollector
        self.networkCollector = networkCollector
        self.diskCollector = diskCollector
        self.batteryCollector = batteryCollector
        self.thermalCollector = thermalCollector
        self.processCollector = processCollector
    }

    public func sampleCPU() -> CPUStats {
        cpuCollector.sample()
    }

    public func sampleMemory() -> MemoryStats {
        memoryCollector.sample()
    }

    public func sampleNetwork() -> NetworkStats {
        networkCollector.sample()
    }

    public func sampleDisk() -> DiskStats {
        diskCollector.sample()
    }

    public func sampleBattery() -> BatteryStats {
        batteryCollector.sample()
    }

    public func sampleAppleSilicon() -> AppleSiliconStats {
        let coreInfo = cpuCollector.samplePerCore()
        let temp = thermalCollector.sampleTemperature()
        let state = ThermalCollector.currentThermalState()
        return AppleSiliconStats(
            pCoreCount: cpuCollector.pCoreCount,
            eCoreCount: cpuCollector.eCoreCount,
            pCoreUsageFraction: coreInfo.pUsage,
            eCoreUsageFraction: coreInfo.eUsage,
            perCoreUsage: coreInfo.perCore,
            socTemperatureCelsius: temp,
            thermalStateDescription: state
        )
    }

    public func sampleTopProcesses(limit: Int) -> [ProcessSnapshot] {
        processCollector.sampleTopProcesses(limit: limit)
    }
}
