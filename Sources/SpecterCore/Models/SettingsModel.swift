import Foundation
import Observation

public enum TemperatureUnit: String, CaseIterable, Sendable {
    case celsius = "C"
    case fahrenheit = "F"
}

/// User preferences for visible menu bar pill segments and background polling interval.
@Observable
@MainActor
public final class SettingsModel {
    public static let shared = SettingsModel()

    public var showCPU: Bool {
        didSet { defaults.set(showCPU, forKey: "Specter_showCPU") }
    }
    public var showMemory: Bool {
        didSet { defaults.set(showMemory, forKey: "Specter_showMemory") }
    }
    public var showNetwork: Bool {
        didSet { defaults.set(showNetwork, forKey: "Specter_showNetwork") }
    }
    public var showDisk: Bool {
        didSet { defaults.set(showDisk, forKey: "Specter_showDisk") }
    }
    public var showBattery: Bool {
        didSet { defaults.set(showBattery, forKey: "Specter_showBattery") }
    }
    public var backgroundInterval: Double {
        didSet { defaults.set(backgroundInterval, forKey: "Specter_backgroundInterval") }
    }
    public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "Specter_temperatureUnit") }
    }
    public var showPerCoreBreakdown: Bool {
        didSet { defaults.set(showPerCoreBreakdown, forKey: "Specter_showPerCoreBreakdown") }
    }
    public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "Specter_launchAtLogin") }
    }
    public var isTroubleshootingMode: Bool {
        didSet { defaults.set(isTroubleshootingMode, forKey: "Specter_isTroubleshootingMode") }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showCPU = (defaults.object(forKey: "Specter_showCPU") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_showCPU") as? Bool) ?? true
        self.showMemory = (defaults.object(forKey: "Specter_showMemory") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_showMemory") as? Bool) ?? true
        self.showNetwork = (defaults.object(forKey: "Specter_showNetwork") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_showNetwork") as? Bool) ?? true
        self.showDisk = (defaults.object(forKey: "Specter_showDisk") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_showDisk") as? Bool) ?? false
        self.showBattery = (defaults.object(forKey: "Specter_showBattery") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_showBattery") as? Bool) ?? false
        self.backgroundInterval = (defaults.object(forKey: "Specter_backgroundInterval") as? Double)
            ?? (defaults.object(forKey: "StatsBar_backgroundInterval") as? Double) ?? 2.0
        let tempRaw = defaults.string(forKey: "Specter_temperatureUnit")
            ?? defaults.string(forKey: "StatsBar_temperatureUnit") ?? "C"
        self.temperatureUnit = TemperatureUnit(rawValue: tempRaw) ?? .celsius
        self.showPerCoreBreakdown = (defaults.object(forKey: "Specter_showPerCoreBreakdown") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_showPerCoreBreakdown") as? Bool) ?? true
        self.launchAtLogin = (defaults.object(forKey: "Specter_launchAtLogin") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_launchAtLogin") as? Bool) ?? true
        self.isTroubleshootingMode = (defaults.object(forKey: "Specter_isTroubleshootingMode") as? Bool)
            ?? (defaults.object(forKey: "StatsBar_isTroubleshootingMode") as? Bool) ?? true
    }
}
