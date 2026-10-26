import Foundation
import Darwin

/// In-process process inspector querying kernel task info via Darwin libproc.
/// Runs in < 1ms across all active system PIDs without spawning child processes.
public final class ProcessCollector: @unchecked Sendable {
    private var previousSamples: [pid_t: (cpuNanos: UInt64, timestamp: UInt64)] = [:]
    private var appGroupCache: [String: (identifier: String, name: String)] = [:]

    public init() {}

    /// Samples all active processes and returns top N by CPU consumption.
    public func sampleTopProcesses(limit: Int = 5) -> [ProcessSnapshot] {
        sampleProcesses(limit: limit).topCPU
    }

    /// Samples all active processes and returns top N by resident memory (RAM).
    public func sampleTopMemoryProcesses(limit: Int = 5) -> [ProcessSnapshot] {
        sampleProcesses(limit: limit).topMemory
    }

    /// Samples every accessible process so callers can calculate complete group totals.
    public func sampleAllProcesses() -> [ProcessSnapshot] {
        collectSnapshots()
    }

    /// Samples all active processes in a single Darwin libproc pass and returns top items by CPU and Memory.
    public func sampleProcesses(limit: Int = 15) -> (topCPU: [ProcessSnapshot], topMemory: [ProcessSnapshot]) {
        let snapshots = collectSnapshots()
        let cpuSorted = snapshots.sorted { $0.cpuFraction > $1.cpuFraction }
        let memSorted = snapshots.sorted { $0.ramBytes > $1.ramBytes }

        return (
            topCPU: Array(cpuSorted.prefix(limit)),
            topMemory: Array(memSorted.prefix(limit))
        )
    }

    private func collectSnapshots() -> [ProcessSnapshot] {
        autoreleasepool {
            let count = proc_listallpids(nil, 0)
            guard count > 0 else { return [] }

            var pids = [pid_t](repeating: 0, count: Int(count))
            let actualCount = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
            guard actualCount > 0 else { return [] }

            let now = DispatchTime.now().uptimeNanoseconds
            var currentSamples: [pid_t: (cpuNanos: UInt64, timestamp: UInt64)] = [:]
            currentSamples.reserveCapacity(Int(actualCount))

            var snapshots: [ProcessSnapshot] = []
            snapshots.reserveCapacity(Int(actualCount))

            for pid in pids.prefix(Int(actualCount)) where pid > 0 {
                var taskInfo = proc_taskinfo()
                let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
                guard size == MemoryLayout<proc_taskinfo>.size else { continue }

                let totalCpu = taskInfo.pti_total_user &+ taskInfo.pti_total_system
                currentSamples[pid] = (cpuNanos: totalCpu, timestamp: now)

                var fraction = 0.0
                if let prev = previousSamples[pid], now > prev.timestamp {
                    let cpuDelta = Double(totalCpu &- prev.cpuNanos)
                    let timeDelta = Double(now - prev.timestamp)
                    if timeDelta > 0 {
                        fraction = max(cpuDelta / timeDelta, 0.0)
                    }
                }

                let isUser = Self.isUserProcess(pid: pid)
                let name = Self.nameForPID(pid)
                let appGroup = appGroupForPID(pid)
                let snap = ProcessSnapshot(
                    id: pid,
                    name: name,
                    cpuFraction: fraction,
                    ramBytes: taskInfo.pti_resident_size,
                    isUserApp: isUser,
                    groupIdentifier: appGroup?.identifier,
                    groupName: appGroup?.name
                )
                snapshots.append(snap)
            }

            previousSamples = currentSamples
            return snapshots
        }
    }

    /// Determines whether the process is a user-space application vs a system daemon.
    public static func isUserProcess(pid: pid_t) -> Bool {
        var bsdInfo = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard size == MemoryLayout<proc_bsdinfo>.size else { return false }
        var pathBuffer = [CChar](repeating: 0, count: 1024)
        let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        let path = pathLen > 0 ? pathBuffer.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return "" }
            return String(cString: base)
        } : nil
        return isUserProcess(uid: bsdInfo.pbi_uid, executablePath: path)
    }

    static func isUserProcess(uid: uid_t, executablePath: String?) -> Bool {
        guard uid >= 500 else { return false }
        guard let executablePath else { return true }
        let systemPathPrefixes = [
            "/System/",
            "/usr/",
            "/sbin/",
            "/Library/Apple/",
            "/Library/System/"
        ]
        if systemPathPrefixes.contains(where: executablePath.hasPrefix) {
            return false
        }
        return true
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

    private func appGroupForPID(_ pid: pid_t) -> (identifier: String, name: String)? {
        var pathBuffer = [CChar](repeating: 0, count: 4_096)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard pathLength > 0 else { return nil }
        let path = pathBuffer.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return "" }
            return String(cString: base)
        }
        let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        let appPath = NSString.path(withComponents: Array(components.prefix(appIndex + 1)))
        if let cachedGroup = appGroupCache[appPath] {
            return cachedGroup
        }
        let appURL = URL(fileURLWithPath: appPath)
        let bundle = Bundle(url: appURL)
        let identifier = bundle?.bundleIdentifier ?? appURL.path
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        let appGroup = (identifier, name)
        appGroupCache[appPath] = appGroup
        return appGroup
    }
}
