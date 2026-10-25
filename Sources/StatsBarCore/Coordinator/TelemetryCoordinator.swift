import Foundation
import Observation

/// The central telemetry coordinator that drives coalesced sampling ticks.
@Observable
@MainActor
public final class TelemetryCoordinator {
    public var currentCPU: CPUStats = CPUStats()
    public var cpuHistory: [Double] = []
    public var currentMemory: MemoryStats = MemoryStats()
    public var currentNetwork: NetworkStats = NetworkStats()
    
    /// Controls two-tier adaptive polling.
    public var isPopoverPresented: Bool = false {
        didSet {
            samplingInterval = isPopoverPresented ? 1.0 : 2.0
        }
    }

    public var samplingInterval: TimeInterval = 2.0 {
        didSet {
            restartTimer()
        }
    }

    private let provider: TelemetryProviding
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.personal.StatsBar.timerQueue", qos: .utility)

    public init(provider: TelemetryProviding, autoStart: Bool = true) {
        self.provider = provider
        if autoStart {
            startTimer()
        }
    }

    isolated deinit {
        timer?.cancel()
    }

    /// Single master tick: samples telemetry and publishes to the MainActor.
    public func tick() {
        let provider = self.provider
        queue.async { [weak self] in
            let cpu = provider.sampleCPU()
            let memory = provider.sampleMemory()
            let network = provider.sampleNetwork()

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentCPU = cpu
                self.cpuHistory.append(cpu.usageFraction)
                if self.cpuHistory.count > 30 {
                    self.cpuHistory.removeFirst()
                }
                self.currentMemory = memory
                self.currentNetwork = network
            }
        }
    }

    public func startTimer() {
        guard timer == nil else { return }
        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now(), repeating: samplingInterval, leeway: .milliseconds(100))
        newTimer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        newTimer.resume()
        self.timer = newTimer
    }

    public func stopTimer() {
        if let existing = timer {
            existing.cancel()
            self.timer = nil
        }
    }

    private func restartTimer() {
        stopTimer()
        startTimer()
    }
}
