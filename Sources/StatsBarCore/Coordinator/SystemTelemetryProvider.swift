import Foundation

/// Production telemetry provider reading live hardware and process metrics from Darwin kernel APIs.
public final class SystemTelemetryProvider: TelemetryProviding, @unchecked Sendable {
    private let cpuCollector: CPUCollector
    private let processCollector: ProcessCollector

    public init(
        cpuCollector: CPUCollector = CPUCollector(),
        processCollector: ProcessCollector = ProcessCollector()
    ) {
        self.cpuCollector = cpuCollector
        self.processCollector = processCollector
    }

    public func sampleCPU() -> CPUStats {
        cpuCollector.sample()
    }

    public func sampleMemory() -> MemoryStats {
        // Placeholder until Ticket 04
        MemoryStats(usedBytes: 8_589_934_592, totalBytes: 17_179_869_184, pressure: .normal)
    }

    public func sampleNetwork() -> NetworkStats {
        // Placeholder until Ticket 05
        NetworkStats(uploadBytesPerSecond: 0, downloadBytesPerSecond: 0)
    }

    public func sampleTopProcesses(limit: Int) -> [ProcessSnapshot] {
        processCollector.sampleTopProcesses(limit: limit)
    }
}
