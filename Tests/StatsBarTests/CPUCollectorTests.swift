import Testing
import Darwin
import StatsBarCore

@Suite("CPUCollector Tests")
struct CPUCollectorTests {

    @Test("Calculates exact 50% CPU usage from tick deltas")
    func testCalculateUsageFiftyPercent() {
        // user: 50, sys: 50, idle: 100, nice: 0 -> (50 + 50) / (100 + 100) = 50%
        var prev = host_cpu_load_info()
        prev.cpu_ticks = (0, 0, 0, 0)

        var curr = host_cpu_load_info()
        curr.cpu_ticks = (50, 50, 100, 0)

        let usage = CPUCollector.calculateUsage(previous: prev, current: curr)
        #expect(usage == 0.5)
    }

    @Test("Calculates 100% and 0% CPU usage correctly")
    func testBoundaryCalculations() {
        var prev = host_cpu_load_info()
        prev.cpu_ticks = (1000, 1000, 1000, 1000)

        // 100% CPU: idle did not advance
        var allBusy = host_cpu_load_info()
        allBusy.cpu_ticks = (1500, 1500, 1000, 1000)
        #expect(CPUCollector.calculateUsage(previous: prev, current: allBusy) == 1.0)

        // 0% CPU: only idle advanced
        var allIdle = host_cpu_load_info()
        allIdle.cpu_ticks = (1000, 1000, 2000, 1000)
        #expect(CPUCollector.calculateUsage(previous: prev, current: allIdle) == 0.0)
    }

    @Test("Handles counter wraparound gracefully with wrapping subtraction")
    func testCounterWraparound() {
        var prev = host_cpu_load_info()
        prev.cpu_ticks = (UInt32.max - 50, 0, 0, 0)

        var curr = host_cpu_load_info()
        curr.cpu_ticks = (50, 0, 100, 0) // user wrapped around: delta is 101 ticks

        let usage = CPUCollector.calculateUsage(previous: prev, current: curr)
        #expect(usage > 0.0 && usage <= 1.0)
    }

    @Test("Returns zero when tick delta is zero to prevent division by zero")
    func testZeroDelta() {
        var prev = host_cpu_load_info()
        prev.cpu_ticks = (100, 100, 100, 100)

        let usage = CPUCollector.calculateUsage(previous: prev, current: prev)
        #expect(usage == 0.0)
    }

    @Test("Reads live host CPU load info from Mach kernel on host Mac")
    func testLiveKernelRead() {
        let info = CPUCollector.readHostCPULoadInfo()
        #expect(info != nil)
        if let ticks = info?.cpu_ticks {
            let total = ticks.0 + ticks.1 + ticks.2 + ticks.3
            #expect(total > 0)
        }
    }
}
