import Foundation
import IOKit

/// Collects SoC thermal readings via Darwin IOHIDEventSystemClient.
/// Operates without root privileges, kernel extensions, or elevated daemons.
public final class ThermalCollector: @unchecked Sendable {
    private typealias IOHIDCreate = @convention(c) (CFAllocator?) -> AnyObject?
    private typealias IOHIDSetMatching = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias IOHIDCopyServices = @convention(c) (AnyObject) -> CFArray?
    private typealias IOHIDCopyEvent = @convention(c) (AnyObject, Int64, Int32, Int64) -> AnyObject?
    private typealias IOHIDGetFloat = @convention(c) (AnyObject, Int32) -> Double
    private typealias IOHIDCopyProperty = @convention(c) (AnyObject, CFString) -> AnyObject?

    private let symCreate: IOHIDCreate?
    private let symSetMatching: IOHIDSetMatching?
    private let symCopyServices: IOHIDCopyServices?
    private let symCopyEvent: IOHIDCopyEvent?
    private let symGetFloat: IOHIDGetFloat?
    private let symCopyProperty: IOHIDCopyProperty?
    private var client: AnyObject?

    public init() {
        let handle = dlopen(nil, RTLD_NOW)
        if let sCreate = dlsym(handle, "IOHIDEventSystemClientCreate"),
           let sSet = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
           let sCopy = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
           let sEvent = dlsym(handle, "IOHIDServiceClientCopyEvent"),
           let sFloat = dlsym(handle, "IOHIDEventGetFloatValue"),
           let sProp = dlsym(handle, "IOHIDServiceClientCopyProperty") {
            self.symCreate = unsafeBitCast(sCreate, to: IOHIDCreate.self)
            self.symSetMatching = unsafeBitCast(sSet, to: IOHIDSetMatching.self)
            self.symCopyServices = unsafeBitCast(sCopy, to: IOHIDCopyServices.self)
            self.symCopyEvent = unsafeBitCast(sEvent, to: IOHIDCopyEvent.self)
            self.symGetFloat = unsafeBitCast(sFloat, to: IOHIDGetFloat.self)
            self.symCopyProperty = unsafeBitCast(sProp, to: IOHIDCopyProperty.self)
            
            if let client = self.symCreate?(kCFAllocatorDefault) {
                let matching: [String: Any] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]
                self.symSetMatching?(client, matching as CFDictionary)
                self.client = client
            }
        } else {
            self.symCreate = nil
            self.symSetMatching = nil
            self.symCopyServices = nil
            self.symCopyEvent = nil
            self.symGetFloat = nil
            self.symCopyProperty = nil
            self.client = nil
        }
    }

    /// Samples the average temperature across SoC core thermal sensors.
    public func sampleTemperature() -> Double? {
        guard let client,
              let copyServices = symCopyServices,
              let copyEvent = symCopyEvent,
              let getFloat = symGetFloat,
              let copyProperty = symCopyProperty,
              let services = copyServices(client) as? [AnyObject] else {
            return nil
        }

        var totalTemp = 0.0
        var count = 0

        for service in services {
            guard let name = copyProperty(service, "Product" as CFString) as? String else { continue }
            // Filter to CPU / PMU / SoC die thermal sensors
            let lower = name.lowercased()
            if lower.contains("die") || lower.contains("tdie") || lower.contains("cpu") || lower.contains("soc") {
                if let event = copyEvent(service, 15, 0, 0) { // 15 = kIOHIDEventTypeTemperature
                    let temp = getFloat(event, 15 << 16)
                    if temp > 15.0 && temp < 125.0 { // Valid operational temperature range
                        totalTemp += temp
                        count += 1
                    }
                }
            }
        }

        guard count > 0 else { return nil }
        return totalTemp / Double(count)
    }

    /// Formats the current system thermal throttling state.
    public static func currentThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Nominal"
        }
    }
}
