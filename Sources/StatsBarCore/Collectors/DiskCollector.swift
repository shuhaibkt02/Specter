import Foundation
import Darwin
import IOKit
import IOKit.storage

/// Queries live APFS volume capacity and real-time block storage I/O throughput in-process via IOKit and Darwin APIs.
public final class DiskCollector: @unchecked Sendable {
    private var previousReadBytes: UInt64?
    private var previousWriteBytes: UInt64?
    private var previousTimestamp: UInt64?
    private let volumePath: String

    public init(volumePath: String = "/") {
        self.volumePath = volumePath
    }

    /// Samples aggregate disk capacity and calculates real-time read/write throughput.
    public func sample() -> DiskStats {
        sample(
            currentTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            counters: Self.readBlockStorageCounters(),
            capacity: Self.readVolumeCapacity(path: volumePath)
        )
    }

    /// Overload for deterministic unit testing with synthetic inputs.
    public func sample(
        currentTimeNanoseconds: UInt64,
        counters: (readBytes: UInt64, writeBytes: UInt64)?,
        capacity: (totalBytes: UInt64, freeBytes: UInt64, usedBytes: UInt64)? = nil
    ) -> DiskStats {
        let cap = capacity ?? Self.readVolumeCapacity(path: volumePath)
        guard let counters else {
            return DiskStats(
                totalBytes: cap.totalBytes,
                freeBytes: cap.freeBytes,
                usedBytes: cap.usedBytes,
                readBytesPerSecond: 0.0,
                writeBytesPerSecond: 0.0
            )
        }

        guard let prevRead = previousReadBytes,
              let prevWrite = previousWriteBytes,
              let prevTime = previousTimestamp,
              currentTimeNanoseconds > prevTime else {
            previousReadBytes = counters.readBytes
            previousWriteBytes = counters.writeBytes
            previousTimestamp = currentTimeNanoseconds
            return DiskStats(
                totalBytes: cap.totalBytes,
                freeBytes: cap.freeBytes,
                usedBytes: cap.usedBytes,
                readBytesPerSecond: 0.0,
                writeBytesPerSecond: 0.0
            )
        }

        let timeDelta = currentTimeNanoseconds - prevTime
        let readRate = Self.calculateRate(
            currentBytes: counters.readBytes,
            previousBytes: prevRead,
            timeDeltaNanoseconds: timeDelta
        )
        let writeRate = Self.calculateRate(
            currentBytes: counters.writeBytes,
            previousBytes: prevWrite,
            timeDeltaNanoseconds: timeDelta
        )

        previousReadBytes = counters.readBytes
        previousWriteBytes = counters.writeBytes
        previousTimestamp = currentTimeNanoseconds

        return DiskStats(
            totalBytes: cap.totalBytes,
            freeBytes: cap.freeBytes,
            usedBytes: cap.usedBytes,
            readBytesPerSecond: readRate,
            writeBytesPerSecond: writeRate
        )
    }

    /// Calculates transfer rate in bytes per second from cumulative byte counters and time delta in nanoseconds.
    public static func calculateRate(
        currentBytes: UInt64,
        previousBytes: UInt64,
        timeDeltaNanoseconds: UInt64
    ) -> Double {
        guard timeDeltaNanoseconds > 0 else { return 0.0 }
        guard currentBytes >= previousBytes else { return 0.0 }
        let deltaBytes = Double(currentBytes - previousBytes)
        let elapsedSeconds = Double(timeDeltaNanoseconds) / 1_000_000_000.0
        guard elapsedSeconds > 0 else { return 0.0 }
        let rate = deltaBytes / elapsedSeconds
        guard rate.isFinite && !rate.isNaN else { return 0.0 }
        return max(rate, 0.0)
    }

    /// Queries volume storage capacity (total, free, used bytes) using Foundation volume URL keys with statfs fallback.
    public static func readVolumeCapacity(path: String = "/") -> (totalBytes: UInt64, freeBytes: UInt64, usedBytes: UInt64) {
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) {
            let total = UInt64(max(values.volumeTotalCapacity ?? 0, 0))
            let free: UInt64
            if let importantUsage = values.volumeAvailableCapacityForImportantUsage, importantUsage > 0 {
                free = UInt64(importantUsage)
            } else if let available = values.volumeAvailableCapacity, available > 0 {
                free = UInt64(available)
            } else {
                free = 0
            }
            if total > 0 {
                let used = total >= free ? total - free : 0
                return (totalBytes: total, freeBytes: free, usedBytes: used)
            }
        }

        var fs = statfs()
        if statfs(path, &fs) == 0 {
            let blockSize = UInt64(fs.f_bsize)
            let total = UInt64(fs.f_blocks) * blockSize
            let free = UInt64(fs.f_bavail) * blockSize
            let used = total >= free ? total - free : 0
            return (totalBytes: total, freeBytes: free, usedBytes: used)
        }

        return (totalBytes: 0, freeBytes: 0, usedBytes: 0)
    }

    /// Queries the IOKit registry for cumulative bytes read and written across all matching block storage drivers.
    public static func readBlockStorageCounters() -> (readBytes: UInt64, writeBytes: UInt64)? {
        var iterator: io_iterator_t = 0
        guard let matchDict = IOServiceMatching(kIOBlockStorageDriverClass) else {
            return nil
        }
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard result == KERN_SUCCESS else {
            return nil
        }
        defer {
            IOObjectRelease(iterator)
        }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var foundAny = false

        var service = IOIteratorNext(iterator)
        while service != 0 {
            let currentService = service
            service = IOIteratorNext(iterator)
            defer {
                IOObjectRelease(currentService)
            }

            let property = IORegistryEntryCreateCFProperty(
                currentService,
                kIOBlockStorageDriverStatisticsKey as CFString,
                kCFAllocatorDefault,
                0
            )
            guard let prop = property else { continue }
            let dict = prop.takeRetainedValue() as? NSDictionary
            if let readNum = dict?[kIOBlockStorageDriverStatisticsBytesReadKey] as? NSNumber {
                totalRead &+= readNum.uint64Value
                foundAny = true
            }
            if let writeNum = dict?[kIOBlockStorageDriverStatisticsBytesWrittenKey] as? NSNumber {
                totalWrite &+= writeNum.uint64Value
                foundAny = true
            }
        }

        return foundAny ? (readBytes: totalRead, writeBytes: totalWrite) : nil
    }
}
