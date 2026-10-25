import Testing
import Foundation
import IOKit.ps
import StatsBarCore

@Suite("BatteryCollector Tests")
struct BatteryCollectorTests {

    // MARK: - Synthetic Dictionary Parsing Tests

    @Test("Parses battery power source discharging on battery")
    func testDischargingOnBattery() {
        let dict: [String: Any] = [
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue as String,
            kIOPSCurrentCapacityKey as String: 85,
            kIOPSMaxCapacityKey as String: 100,
            kIOPSIsChargingKey as String: false,
            kIOPSTimeToEmptyKey as String: 180,
            kIOPSIsPresentKey as String: true,
            kIOPSTypeKey as String: kIOPSInternalBatteryType as String
        ]

        let stats = BatteryCollector.parse(description: dict)

        #expect(stats.hasBattery == true)
        #expect(stats.capacityFraction == 0.85)
        #expect(stats.percentageString == "85%")
        #expect(stats.isCharging == false)
        #expect(stats.isACPower == false)
        #expect(stats.timeRemainingMinutes == 180)
        #expect(stats.formattedTimeRemaining == "3h 0m")
    }

    @Test("Parses battery power source charging on AC power")
    func testChargingOnACPower() {
        let dict: [String: Any] = [
            kIOPSPowerSourceStateKey as String: kIOPSACPowerValue as String,
            kIOPSCurrentCapacityKey as String: 45,
            kIOPSMaxCapacityKey as String: 100,
            kIOPSIsChargingKey as String: true,
            kIOPSTimeToFullChargeKey as String: 55,
            kIOPSIsPresentKey as String: true,
            kIOPSTypeKey as String: kIOPSInternalBatteryType as String
        ]

        let stats = BatteryCollector.parse(description: dict)

        #expect(stats.hasBattery == true)
        #expect(stats.capacityFraction == 0.45)
        #expect(stats.percentageString == "45%")
        #expect(stats.isCharging == true)
        #expect(stats.isACPower == true)
        #expect(stats.timeRemainingMinutes == 55)
        #expect(stats.formattedTimeRemaining == "55m")
    }

    @Test("Parses battery power source fully charged on AC power")
    func testFullyChargedOnACPower() {
        let dict: [String: Any] = [
            kIOPSPowerSourceStateKey as String: kIOPSACPowerValue as String,
            kIOPSCurrentCapacityKey as String: 100,
            kIOPSMaxCapacityKey as String: 100,
            kIOPSIsChargingKey as String: false,
            kIOPSTimeToFullChargeKey as String: 0,
            kIOPSTimeToEmptyKey as String: -1,
            kIOPSIsPresentKey as String: true,
            kIOPSTypeKey as String: kIOPSInternalBatteryType as String
        ]

        let stats = BatteryCollector.parse(description: dict)

        #expect(stats.hasBattery == true)
        #expect(stats.capacityFraction == 1.0)
        #expect(stats.percentageString == "100%")
        #expect(stats.isCharging == false)
        #expect(stats.isACPower == true)
        #expect(stats.timeRemainingMinutes == nil)
        #expect(stats.formattedTimeRemaining == nil)
    }

    @Test("Handles desktops without battery gracefully")
    func testDesktopWithoutBattery() {
        // Empty dictionary (no power sources found)
        let emptyStats = BatteryCollector.parse(description: [:])
        #expect(emptyStats.hasBattery == false)
        #expect(emptyStats.isACPower == true)
        #expect(emptyStats.isCharging == false)
        #expect(emptyStats.capacityFraction == 0.0)
        #expect(emptyStats.percentageString == "0%")
        #expect(emptyStats.timeRemainingMinutes == nil)

        // Dictionary with explicit isPresent = false
        let notPresentDict: [String: Any] = [
            kIOPSIsPresentKey as String: false,
            kIOPSCurrentCapacityKey as String: 50
        ]
        let notPresentStats = BatteryCollector.parse(description: notPresentDict)
        #expect(notPresentStats.hasBattery == false)
        #expect(notPresentStats.isACPower == true)
        #expect(notPresentStats.isCharging == false)

        // Non-battery external power device (e.g. UPS)
        let upsDict: [String: Any] = [
            kIOPSTypeKey as String: "UPS",
            kIOPSCurrentCapacityKey as String: 100
        ]
        let upsStats = BatteryCollector.parse(description: upsDict)
        #expect(upsStats.hasBattery == false)
        #expect(upsStats.isACPower == true)
    }

    @Test("Handles calculating time remaining (-1) without crashing")
    func testCalculatingTimeRemaining() {
        let dict: [String: Any] = [
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue as String,
            kIOPSCurrentCapacityKey as String: 70,
            kIOPSMaxCapacityKey as String: 100,
            kIOPSIsChargingKey as String: false,
            kIOPSTimeToEmptyKey as String: -1,
            kIOPSIsPresentKey as String: true
        ]

        let stats = BatteryCollector.parse(description: dict)

        #expect(stats.hasBattery == true)
        #expect(stats.capacityFraction == 0.70)
        #expect(stats.percentageString == "70%")
        #expect(stats.timeRemainingMinutes == nil)
        #expect(stats.formattedTimeRemaining == nil)
    }

    @Test("Clamps capacity fractions and guards against division by zero")
    func testClampingAndDivisionByZero() {
        // Negative capacity
        let negativeDict: [String: Any] = [
            kIOPSCurrentCapacityKey as String: -15,
            kIOPSMaxCapacityKey as String: 100
        ]
        let negativeStats = BatteryCollector.parse(description: negativeDict)
        #expect(negativeStats.capacityFraction == 0.0)
        #expect(negativeStats.percentageString == "0%")

        // Excessive capacity
        let excessiveDict: [String: Any] = [
            kIOPSCurrentCapacityKey as String: 130,
            kIOPSMaxCapacityKey as String: 100
        ]
        let excessiveStats = BatteryCollector.parse(description: excessiveDict)
        #expect(excessiveStats.capacityFraction == 1.0)
        #expect(excessiveStats.percentageString == "100%")

        // Zero max capacity
        let zeroMaxDict: [String: Any] = [
            kIOPSCurrentCapacityKey as String: 50,
            kIOPSMaxCapacityKey as String: 0
        ]
        let zeroMaxStats = BatteryCollector.parse(description: zeroMaxDict)
        #expect(zeroMaxStats.capacityFraction == 0.0)
        #expect(!zeroMaxStats.capacityFraction.isNaN)
    }

    // MARK: - Live Host Snapshot Reading Tests

    @Test("Reads live power source snapshot on host Mac")
    func testLiveSnapshotRead() {
        let liveStats = BatteryCollector.readCurrentStats()

        #expect(liveStats.capacityFraction >= 0.0 && liveStats.capacityFraction <= 1.0)
        #expect(liveStats.percentageString.hasSuffix("%"))

        if liveStats.hasBattery {
            let expectedPct = "\(Int((liveStats.capacityFraction * 100).rounded()))%"
            #expect(liveStats.percentageString == expectedPct)
            // On a laptop, time remaining can be nil (calculating or fully charged) or positive minutes
            if let time = liveStats.timeRemainingMinutes {
                #expect(time > 0)
            }
        } else {
            // Desktops must always be on AC power
            #expect(liveStats.isACPower == true)
            #expect(liveStats.isCharging == false)
            #expect(liveStats.timeRemainingMinutes == nil)
        }
    }

    @Test("BatteryCollector sample method populates latestStats")
    func testCollectorSample() {
        let collector = BatteryCollector()
        let sampled = collector.sample()

        #expect(collector.latestStats == sampled)
        #expect(sampled.capacityFraction >= 0.0 && sampled.capacityFraction <= 1.0)
    }

    // MARK: - Lifecycle and Event Observer Tests

    @Test("Manages RunLoop notification observer lifecycle with zero CPU polling")
    func testObserverLifecycle() {
        let collector = BatteryCollector()
        #expect(!collector.isObserving)

        collector.startObserving()
        #expect(collector.isObserving)

        // Multiple calls to startObserving should be safe and idempotent
        collector.startObserving()
        #expect(collector.isObserving)

        collector.stopObserving()
        #expect(!collector.isObserving)

        // Multiple calls to stopObserving should be safe
        collector.stopObserving()
        #expect(!collector.isObserving)
    }

    // MARK: - BatteryStats Domain Model Tests

    @Test("BatteryStats model default initialization and noBattery preset")
    func testBatteryStatsModelDefaults() {
        let noBat = BatteryStats.noBattery
        #expect(noBat.hasBattery == false)
        #expect(noBat.isACPower == true)
        #expect(noBat.isCharging == false)
        #expect(noBat.capacityFraction == 0.0)
        #expect(noBat.percentageString == "0%")
        #expect(noBat.timeRemainingMinutes == nil)
        #expect(noBat.formattedTimeRemaining == nil)

        let custom = BatteryStats(
            capacityFraction: 0.954,
            isCharging: false,
            isACPower: false,
            timeRemainingMinutes: 135,
            hasBattery: true
        )
        #expect(custom.capacityFraction == 0.954)
        #expect(custom.percentageString == "95%")
        #expect(custom.formattedTimeRemaining == "2h 15m")
    }
}
