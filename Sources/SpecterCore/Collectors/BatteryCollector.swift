import Foundation
import IOKit.ps

/// Collector for hardware battery telemetry and power source state via macOS IOKit.
/// Employs event-driven run loop notifications (`IOPSNotificationCreateRunLoopSource`)
/// to achieve zero CPU polling while idle.
public final class BatteryCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var updateHandler: (@Sendable (BatteryStats) -> Void)?
    public private(set) var latestStats: BatteryStats

    public init() {
        self.latestStats = Self.readCurrentStats()
    }

    deinit {
        stopObserving()
    }

    /// Queries live power sources synchronously and returns the latest snapshot.
    @discardableResult
    public func sample() -> BatteryStats {
        let stats = Self.readCurrentStats()
        lock.lock()
        self.latestStats = stats
        lock.unlock()
        return stats
    }

    /// Registers an event-driven run loop notification source for zero-CPU idle power monitoring.
    ///
    /// When power status changes (e.g. charger plugged/unplugged, percentage stepped),
    /// the operating system triggers the run loop source, updating `latestStats` and
    /// calling `onUpdate`.
    public func startObserving(
        runLoop: CFRunLoop = CFRunLoopGetMain(),
        runLoopMode: CFRunLoopMode = .defaultMode,
        onUpdate: (@Sendable (BatteryStats) -> Void)? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }

        if let existing = runLoopSource, let rl = self.runLoop {
            CFRunLoopRemoveSource(rl, existing, runLoopMode)
            self.runLoopSource = nil
            self.runLoop = nil
        }

        self.updateHandler = onUpdate

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let collector = Unmanaged<BatteryCollector>.fromOpaque(ctx).takeUnretainedValue()
            collector.handlePowerSourceNotification()
        }, context)?.takeRetainedValue() else {
            return
        }

        CFRunLoopAddSource(runLoop, source, runLoopMode)
        self.runLoopSource = source
        self.runLoop = runLoop
    }

    /// Unregisters the event-driven run loop notification source.
    public func stopObserving(runLoopMode: CFRunLoopMode = .defaultMode) {
        lock.lock()
        defer { lock.unlock() }

        if let source = runLoopSource, let rl = runLoop {
            CFRunLoopRemoveSource(rl, source, runLoopMode)
            self.runLoopSource = nil
            self.runLoop = nil
        }
        self.updateHandler = nil
    }

    /// Returns whether the event-driven run loop source is currently registered.
    public var isObserving: Bool {
        lock.lock()
        defer { lock.unlock() }
        return runLoopSource != nil
    }

    private func handlePowerSourceNotification() {
        let updated = sample()
        let handler: (@Sendable (BatteryStats) -> Void)?
        lock.lock()
        handler = self.updateHandler
        lock.unlock()
        handler?(updated)
    }

    /// Reads live battery and power state directly from IOKit power source APIs.
    public static func readCurrentStats() -> BatteryStats {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatteryStats.noBattery
        }

        let snapshotPowerType = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as? String
        let isACProviding = (snapshotPowerType == (kIOPSACPowerValue as String))

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef], !sources.isEmpty else {
            // Desktop Macs without internal battery
            return BatteryStats(
                capacityFraction: 0.0,
                isCharging: false,
                isACPower: isACProviding || snapshotPowerType == nil,
                timeRemainingMinutes: nil,
                percentageString: "0%",
                hasBattery: false
            )
        }

        var bestDescription: [String: Any]?
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let isPresent = parseBool(desc[kIOPSIsPresentKey as String], default: true)
            guard isPresent else { continue }

            let type = desc[kIOPSTypeKey as String] as? String
            if type == (kIOPSInternalBatteryType as String) {
                bestDescription = desc
                break
            } else if bestDescription == nil {
                bestDescription = desc
            }
        }

        guard let description = bestDescription else {
            return BatteryStats(
                capacityFraction: 0.0,
                isCharging: false,
                isACPower: isACProviding || snapshotPowerType == nil,
                timeRemainingMinutes: nil,
                percentageString: "0%",
                hasBattery: false
            )
        }

        return parse(description: description, snapshotPowerType: snapshotPowerType)
    }

    /// Pure parsing function converting an IOKit power source description dictionary
    /// into a domain `BatteryStats` snapshot.
    public static func parse(
        description: [String: Any],
        snapshotPowerType: String? = nil
    ) -> BatteryStats {
        guard !description.isEmpty else {
            let isAC = snapshotPowerType == (kIOPSACPowerValue as String) || snapshotPowerType == nil
            return BatteryStats(
                capacityFraction: 0.0,
                isCharging: false,
                isACPower: isAC,
                timeRemainingMinutes: nil,
                percentageString: "0%",
                hasBattery: false
            )
        }

        // Check explicit presence flag
        let isPresent = parseBool(description[kIOPSIsPresentKey as String] ?? description["hasBattery"], default: true)
        if !isPresent {
            let isAC = snapshotPowerType == (kIOPSACPowerValue as String) || snapshotPowerType == nil
            return BatteryStats(
                capacityFraction: 0.0,
                isCharging: false,
                isACPower: isAC,
                timeRemainingMinutes: nil,
                percentageString: "0%",
                hasBattery: false
            )
        }

        // Validate power source type
        if let type = description[kIOPSTypeKey as String] as? String {
            if type != (kIOPSInternalBatteryType as String) && !type.localizedCaseInsensitiveContains("battery") {
                let isAC = snapshotPowerType == (kIOPSACPowerValue as String) || snapshotPowerType == nil
                return BatteryStats(
                    capacityFraction: 0.0,
                    isCharging: false,
                    isACPower: isAC,
                    timeRemainingMinutes: nil,
                    percentageString: "0%",
                    hasBattery: false
                )
            }
        }

        // Charging state
        let isCharging = parseBool(description[kIOPSIsChargingKey as String] ?? description["isCharging"], default: false)

        // AC power connection state
        let isACPower: Bool
        if let powerState = description[kIOPSPowerSourceStateKey as String] as? String {
            isACPower = (powerState == (kIOPSACPowerValue as String))
        } else if let acVal = description["isACPower"] {
            isACPower = parseBool(acVal, default: isCharging)
        } else if isCharging {
            isACPower = true
        } else if let type = snapshotPowerType {
            isACPower = (type == (kIOPSACPowerValue as String))
        } else {
            isACPower = false
        }

        // Capacity fraction calculation
        let currentCapacity = parseDouble(description[kIOPSCurrentCapacityKey as String] ?? description["currentCapacity"])
        let maxCapacity = parseDouble(description[kIOPSMaxCapacityKey as String] ?? description["maxCapacity"]) ?? 100.0

        let capacityFraction: Double
        if let current = currentCapacity, maxCapacity > 0 {
            capacityFraction = min(max(current / maxCapacity, 0.0), 1.0)
        } else if let fraction = parseDouble(description["capacityFraction"]) {
            capacityFraction = min(max(fraction, 0.0), 1.0)
        } else {
            capacityFraction = 0.0
        }

        // Estimated minutes remaining:
        // - While charging, kIOPSTimeToFullChargeKey indicates time to full
        // - While discharging, kIOPSTimeToEmptyKey indicates time to empty
        // - Negative values (-1) indicate estimating / unavailable
        let timeRemainingMinutes: Int?
        let timeToEmpty = parseInt(description[kIOPSTimeToEmptyKey as String])
        let timeToFullCharge = parseInt(description[kIOPSTimeToFullChargeKey as String])
        let directTime = parseInt(description["timeRemainingMinutes"])

        if let directTime, directTime > 0 {
            timeRemainingMinutes = directTime
        } else if isCharging {
            if let timeToFullCharge, timeToFullCharge > 0 {
                timeRemainingMinutes = timeToFullCharge
            } else {
                timeRemainingMinutes = nil
            }
        } else {
            if let timeToEmpty, timeToEmpty > 0 {
                timeRemainingMinutes = timeToEmpty
            } else {
                timeRemainingMinutes = nil
            }
        }

        let explicitPercentage = description["percentageString"] as? String
        let healthPercentage = parseInt(description["healthPercentage"]) ?? parseInt(description["batteryHealth"]) ?? 100
        let condition = (description["condition"] as? String) ?? "Normal"

        return BatteryStats(
            capacityFraction: capacityFraction,
            isCharging: isCharging,
            isACPower: isACPower,
            timeRemainingMinutes: timeRemainingMinutes,
            percentageString: explicitPercentage,
            hasBattery: true,
            healthPercentage: healthPercentage,
            condition: condition
        )
    }

    // MARK: - Internal Parsing Helpers

    private static func parseBool(_ value: Any?, default defaultValue: Bool = false) -> Bool {
        guard let value else { return defaultValue }
        if let boolVal = value as? Bool {
            return boolVal
        }
        if let num = value as? NSNumber {
            return num.boolValue
        }
        if let intVal = value as? Int {
            return intVal != 0
        }
        return defaultValue
    }

    private static func parseInt(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let intVal = value as? Int {
            return intVal
        }
        if let num = value as? NSNumber {
            return num.intValue
        }
        return nil
    }

    private static func parseDouble(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let dblVal = value as? Double {
            return dblVal
        }
        if let num = value as? NSNumber {
            return num.doubleValue
        }
        if let intVal = value as? Int {
            return Double(intVal)
        }
        return nil
    }
}
