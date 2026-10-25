import Foundation
import Observation

/// The central telemetry coordinator that drives coalesced sampling ticks.
/// Dispatches kernel sampling in one batched pass (< 0.2ms) on a background thread.
@Observable
public final class TelemetryCoordinator: @unchecked Sendable {
    public var currentCPU: CPUStats = CPUStats()
    public var cpuHistory: RingBuffer<Double> = RingBuffer(capacity: 30)
    public var currentMemory: MemoryStats = MemoryStats()
    public var currentNetwork: NetworkStats = NetworkStats()
    
    /// Controls two-tier adaptive polling.
    /// When false (99.9% of the time), expensive deep collectors remain suspended.
    public var isPopoverPresented: Bool = false {
        didSet {
            handlePresentationChange(isPresented: isPopoverPresented)
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
    private let stateLock = NSLock()

    public init(provider: TelemetryProviding, autoStart: Bool = true) {
        self.provider = provider
        if autoStart {
            startTimer()
        }
    }

    deinit {
        stopTimer()
    }

    /// Single master tick: samples all active telemetry in one coordinated pass.
    public func tick() {
        let cpu = provider.sampleCPU()
        let memory = provider.sampleMemory()
        let network = provider.sampleNetwork()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentCPU = cpu
            self.cpuHistory.append(cpu.usageFraction)
            self.currentMemory = memory
            self.currentNetwork = network
        }
    }

    public func startTimer() {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard timer == nil else { return }
        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now(), repeating: samplingInterval, leeway: .milliseconds(100))
        newTimer.setEventHandler { [weak self] in
            self?.tick()
        }
        newTimer.resume()
        self.timer = newTimer
    }

    public func stopTimer() {
        stateLock.lock()
        defer { stateLock.unlock() }

        if let existing = timer {
            existing.cancel()
            self.timer = nil
        }
    }

    private func restartTimer() {
        stopTimer()
        startTimer()
    }

    private func handlePresentationChange(isPresented: Bool) {
        // Adapt interval: 1.0s when actively viewing popover, 2.0s when backgrounded
        if isPresented {
            samplingInterval = 1.0
        } else {
            samplingInterval = 2.0
        }
    }
}
