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

    @Test("ProcessSnapshot formats RAM values and detects user/system classification")
    func testProcessSnapshotRAMFormatting() {
        let gigabyteProc = ProcessSnapshot(
            id: 100,
            name: "Xcode",
            cpuFraction: 0.25,
            ramBytes: 1_610_612_736, // 1.5 GB
            isUserApp: true
        )
        #expect(gigabyteProc.percentageString == "25%")
        #expect(gigabyteProc.formattedRAM == "1.5 GB")
        #expect(gigabyteProc.isUserApp == true)

        let megabyteProc = ProcessSnapshot(
            id: 200,
            name: "Terminal",
            cpuFraction: 0.05,
            ramBytes: 157_286_400, // 150 MB
            isUserApp: true
        )
        #expect(megabyteProc.formattedRAM == "150 MB")

        let tinyProc = ProcessSnapshot(
            id: 300,
            name: "daemon",
            cpuFraction: 0.0,
            ramBytes: 500_000,
            isUserApp: false
        )
        #expect(tinyProc.formattedRAM == "< 1 MB")
        #expect(tinyProc.isUserApp == false)
    }

    @Test("SampleProcesses yields both CPU and Memory batches without error")
    func testSampleProcessesBatch() {
        let collector = ProcessCollector()
        let batch = collector.sampleProcesses(limit: 5)
        #expect(!batch.topCPU.isEmpty || !batch.topMemory.isEmpty)
        #expect(batch.topMemory.count <= 5)
        #expect(batch.topCPU.count <= 5)
    }

    @Test("Current process is identified as user process")
    func testCurrentProcessUserClassification() {
        let isUser = ProcessCollector.isUserProcess(pid: getpid())
        #expect(isUser == true)
    }
}
