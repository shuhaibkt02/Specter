import Foundation
import Darwin

/// In-process process inspector querying kernel task info via Darwin libproc.
/// Runs in < 1ms across all active system PIDs without spawning child processes.
public final class ProcessCollector: @unchecked Sendable {
    private var previousSamples: [pid_t: (cpuNanos: UInt64, timestamp: UInt64)] = [:]

    public init() {
        // Prime initial sample so subsequent queries have baseline deltas
        _ = sampleTopProcesses(limit: 5)
    }

    /// Samples all active processes and returns top N by CPU consumption.
    public func sampleTopProcesses(limit: Int = 5) -> [ProcessSnapshot] {
        autoreleasepool {
            let count = proc_listallpids(nil, 0)
            guard count > 0 else { return [] }

            var pids = [pid_t](repeating: 0, count: Int(count))
            let actualCount = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
            guard actualCount > 0 else { return [] }

            let now = DispatchTime.now().uptimeNanoseconds
            var deltas: [(pid: pid_t, fraction: Double)] = []
            var currentSamples: [pid_t: (cpuNanos: UInt64, timestamp: UInt64)] = [:]
            currentSamples.reserveCapacity(Int(actualCount))

            for pid in pids.prefix(Int(actualCount)) where pid > 0 {
                var taskInfo = proc_taskinfo()
                let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
                guard size == MemoryLayout<proc_taskinfo>.size else { continue }

                let totalCpu = taskInfo.pti_total_user &+ taskInfo.pti_total_system
                currentSamples[pid] = (cpuNanos: totalCpu, timestamp: now)

                if let prev = previousSamples[pid], now > prev.timestamp {
                    let cpuDelta = Double(totalCpu &- prev.cpuNanos)
                    let timeDelta = Double(now - prev.timestamp)
                    if timeDelta > 0 {
                        let fraction = cpuDelta / timeDelta
                        if fraction >= 0.0 {
                            deltas.append((pid: pid, fraction: fraction))
                        }
                    }
                }
            }

            previousSamples = currentSamples
            deltas.sort { $0.fraction > $1.fraction }

            if !deltas.isEmpty {
                return deltas.prefix(limit).map { item in
                    ProcessSnapshot(
                        id: item.pid,
                        name: Self.nameForPID(item.pid),
                        cpuFraction: item.fraction
                    )
                }
            }

            // Fallback for baseline tick: display top running processes by cumulative CPU time
            let fallback = currentSamples.sorted { $0.value.cpuNanos > $1.value.cpuNanos }.prefix(limit)
            return fallback.map { item in
                ProcessSnapshot(
                    id: item.key,
                    name: Self.nameForPID(item.key),
                    cpuFraction: 0.0
                )
            }
        }
    }

    /// Resolves human-readable process name without shelling out.
    public static func nameForPID(_ pid: pid_t) -> String {
        var nameBuffer = [CChar](repeating: 0, count: 256)
        let len = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if len > 0 {
            let name = nameBuffer.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return "" }
                return String(cString: base)
            }
            if !name.isEmpty { return name }
        }
        return "PID \(pid)"
    }
}
