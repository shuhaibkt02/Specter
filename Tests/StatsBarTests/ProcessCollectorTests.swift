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

    @Test("Samples top processes across two ticks returns active processes")
    func testSampleTopProcessesConsecutiveTicks() {
        let collector = ProcessCollector()
        _ = collector.sampleTopProcesses(limit: 5)
        Thread.sleep(forTimeInterval: 0.1)
        let results = collector.sampleTopProcesses(limit: 5)
        #expect(!results.isEmpty, "Should find at least 1 process using CPU across two samples")
    }
}
