import Testing
import Foundation
@testable import SpecterCore

@Suite("SettingsModel Tests")
@MainActor
struct SettingsModelTests {

    private func createIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.statsbar.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Loads default configuration when no saved preferences exist")
    func testDefaultValues() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)

        #expect(settings.showCPU == true)
        #expect(settings.showMemory == true)
        #expect(settings.showNetwork == true)
        #expect(settings.showDisk == false)
        #expect(settings.showBattery == false)
        #expect(settings.backgroundInterval == 2.0)
        #expect(settings.temperatureUnit == .celsius)
        #expect(settings.showPerCoreBreakdown == true)
        #expect(settings.launchAtLogin == true)
    }

    @Test("Property changes persist to UserDefaults and restore on initialization")
    func testPersistence() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)

        settings.showCPU = false
        settings.showMemory = false
        settings.showNetwork = true
        settings.showDisk = true
        settings.showBattery = true
        settings.backgroundInterval = 3.0
        settings.temperatureUnit = .fahrenheit
        settings.showPerCoreBreakdown = false
        settings.launchAtLogin = false

        // Load into a new instance with the same UserDefaults suite
        let restored = SettingsModel(defaults: defaults)

        #expect(restored.showCPU == false)
        #expect(restored.showMemory == false)
        #expect(restored.showNetwork == true)
        #expect(restored.showDisk == true)
        #expect(restored.showBattery == true)
        #expect(restored.backgroundInterval == 3.0)
        #expect(restored.temperatureUnit == .fahrenheit)
        #expect(restored.showPerCoreBreakdown == false)
        #expect(restored.launchAtLogin == false)
    }

    @Test("TelemetryCoordinator integrates custom background intervals and two-tier adaptive polling")
    func testCoordinatorIntervalIntegration() {
        let mock = MockTelemetryProvider()
        let coordinator = TelemetryCoordinator(provider: mock, backgroundInterval: 3.0, autoStart: false)

        #expect(coordinator.samplingInterval == 3.0)

        // Opening popover triggers Tier 2 (1.0s)
        coordinator.isPopoverPresented = true
        #expect(coordinator.samplingInterval == 1.0)

        // Closing popover restores custom background interval (3.0s)
        coordinator.isPopoverPresented = false
        #expect(coordinator.samplingInterval == 3.0)

        // Modifying backgroundInterval while popover is closed adjusts samplingInterval immediately
        coordinator.backgroundInterval = 1.0
        #expect(coordinator.samplingInterval == 1.0)

        // Modifying backgroundInterval while popover is open preserves 1.0s active rate
        coordinator.isPopoverPresented = true
        #expect(coordinator.samplingInterval == 1.0)
        coordinator.backgroundInterval = 2.0
        #expect(coordinator.samplingInterval == 1.0)

        coordinator.isPopoverPresented = false
        #expect(coordinator.samplingInterval == 2.0)
    }
}
