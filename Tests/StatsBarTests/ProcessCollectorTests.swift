import Testing
import Foundation
import Darwin
import StatsBarCore

@Suite("ProcessCollector Tests")
struct ProcessCollectorTests {

    @Test("Resolves current process name via Darwin proc_name")
    func testCurrentProcessName() {
        let name = ProcessCollector.nameForPID(getpid())
        #expect(!name.isEmpty)
        #expect(!name.starts(with: "PID"))
    }

    @Test("Fallback name formatting for invalid PID")
    func testFallbackName() {
        let name = ProcessCollector.nameForPID(-999)
        #expect(name == "PID -999")
    }

    @Test("Samples top processes within requested limit in under 20ms")
    func testSampleTopProcessesPerformanceAndLimit() {
        let collector = ProcessCollector()
        let start = DispatchTime.now().uptimeNanoseconds
        let results = collector.sampleTopProcesses(limit: 5)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0

        #expect(results.count <= 5)
        #expect(elapsedMs < 20.0) // Must run in-process in milliseconds
    }
}
