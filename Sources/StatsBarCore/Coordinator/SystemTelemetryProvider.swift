import Foundation

/// Production telemetry provider that reads live hardware metrics directly from macOS kernel APIs.
public final class SystemTelemetryProvider: TelemetryProviding, @unchecked Sendable {
    private let cpuCollector: CPUCollector

    public init(cpuCollector: CPUCollector = CPUCollector()) {
        self.cpuCollector = cpuCollector
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
}
