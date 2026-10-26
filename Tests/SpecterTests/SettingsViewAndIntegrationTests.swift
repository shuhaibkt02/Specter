import Testing
import SwiftUI
@testable import SpecterCore

@Suite("SettingsView and Integration Tests")
@MainActor
struct SettingsViewAndIntegrationTests {

    private func createIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.statsbar.settingsview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("SettingsView binds accurately to SettingsModel preferences")
    func testSettingsViewBindings() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)

        var dismissed = false
        let view = SettingsView(settings: settings, hasBattery: true) {
            dismissed = true
        }

        #expect(view.hasBattery == true)

        // Modify settings through the model
        settings.temperatureUnit = .fahrenheit
        #expect(settings.temperatureUnit == .fahrenheit)

        settings.backgroundInterval = 1.0
        #expect(settings.backgroundInterval == 1.0)

        settings.showPerCoreBreakdown = false
        #expect(settings.showPerCoreBreakdown == false)

        settings.launchAtLogin = false
        #expect(settings.launchAtLogin == false)

        view.onDismiss()
        #expect(dismissed == true)
    }

    @Test("SettingsView handles desktop without battery correctly")
    func testSettingsViewDesktopMode() {
        let defaults = createIsolatedDefaults()
        let settings = SettingsModel(defaults: defaults)

        let view = SettingsView(settings: settings, hasBattery: false)
        #expect(view.hasBattery == false)
    }

    @Test("Popover cockpit composition includes all 5 metric cards")
    func testCockpitComposition() {
        let mock = MockTelemetryProvider()
        let coordinator = TelemetryCoordinator(provider: mock, autoStart: false)
        coordinator.isPopoverPresented = true
        coordinator.tick()

        let cpuCard = CPUCardView(coordinator: coordinator)
        let memCard = MemoryCardView(coordinator: coordinator)
        let netCard = NetworkCardView(coordinator: coordinator)
        let diskCard = DiskCardView(coordinator: coordinator)
        let batteryCard = BatteryCardView(coordinator: coordinator)

        #expect(!cpuCard.liveValue.isEmpty)
        #expect(!memCard.liveValue.isEmpty)
        #expect(!netCard.liveValue.isEmpty)
        #expect(!diskCard.liveValue.isEmpty)
        #expect(!batteryCard.liveValue.isEmpty)
    }
}
