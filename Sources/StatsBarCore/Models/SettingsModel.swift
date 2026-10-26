import Foundation
import Observation

public enum TemperatureUnit: String, CaseIterable, Sendable {
    case celsius = "C"
    case fahrenheit = "F"
}

/// User preferences for visible menu bar pill segments and background polling interval.
/// Strictly bounded 5-control configuration following Doc 07 anti-settings architecture.
@Observable
@MainActor
public final class SettingsModel {
    public static let shared = SettingsModel()

    public var showCPU: Bool {
        didSet { defaults.set(showCPU, forKey: "StatsBar_showCPU") }
    }
    public var showMemory: Bool {
        didSet { defaults.set(showMemory, forKey: "StatsBar_showMemory") }
    }
    public var showNetwork: Bool {
        didSet { defaults.set(showNetwork, forKey: "StatsBar_showNetwork") }
    }
    public var showDisk: Bool {
        didSet { defaults.set(showDisk, forKey: "StatsBar_showDisk") }
    }
    public var showBattery: Bool {
        didSet { defaults.set(showBattery, forKey: "StatsBar_showBattery") }
    }
    public var backgroundInterval: Double {
        didSet { defaults.set(backgroundInterval, forKey: "StatsBar_backgroundInterval") }
    }
    public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "StatsBar_temperatureUnit") }
    }
    public var showPerCoreBreakdown: Bool {
        didSet { defaults.set(showPerCoreBreakdown, forKey: "StatsBar_showPerCoreBreakdown") }
    }
    public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "StatsBar_launchAtLogin") }
    }
    public var isTroubleshootingMode: Bool {
        didSet { defaults.set(isTroubleshootingMode, forKey: "StatsBar_isTroubleshootingMode") }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showCPU = defaults.object(forKey: "StatsBar_showCPU") as? Bool ?? true
        self.showMemory = defaults.object(forKey: "StatsBar_showMemory") as? Bool ?? true
        self.showNetwork = defaults.object(forKey: "StatsBar_showNetwork") as? Bool ?? true
        self.showDisk = defaults.object(forKey: "StatsBar_showDisk") as? Bool ?? false
        self.showBattery = defaults.object(forKey: "StatsBar_showBattery") as? Bool ?? false
        self.backgroundInterval = defaults.object(forKey: "StatsBar_backgroundInterval") as? Double ?? 2.0
        let tempRaw = defaults.string(forKey: "StatsBar_temperatureUnit") ?? "C"
        self.temperatureUnit = TemperatureUnit(rawValue: tempRaw) ?? .celsius
        self.showPerCoreBreakdown = defaults.object(forKey: "StatsBar_showPerCoreBreakdown") as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: "StatsBar_launchAtLogin") as? Bool ?? true
        self.isTroubleshootingMode = defaults.object(forKey: "StatsBar_isTroubleshootingMode") as? Bool ?? true
    }
}
