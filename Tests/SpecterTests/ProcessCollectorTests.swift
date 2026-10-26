import Testing
import Foundation
import Darwin
@testable import SpecterCore

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

    @Test("ProcessGroup aggregates CPU, RAM, and process count")
    func testProcessGroupAggregation() {
        let processes = [
            ProcessSnapshot(
                id: 410,
                name: "Browser",
                cpuFraction: 0.12,
                ramBytes: 100,
                groupIdentifier: "com.example.browser",
                groupName: "Browser"
            ),
            ProcessSnapshot(
                id: 411,
                name: "Browser Helper",
                cpuFraction: 0.08,
                ramBytes: 200,
                groupIdentifier: "com.example.browser",
                groupName: "Browser"
            )
        ]

        let group = ProcessGroup(processes: processes)

        #expect(group.id == "com.example.browser")
        #expect(group.name == "Browser")
        #expect(group.containsMultipleProcesses)
        #expect(group.processes.count == 2)
        #expect(abs(group.cpuFraction - 0.2) < 0.0001)
        #expect(group.ramBytes == 300)
        #expect(group.matches(searchQuery: "Browser Helper"))
        #expect(group.processes.count == 2)
        #expect(group.ramBytes == 300)
    }

    @Test("Single-process group is presented as an individual process")
    func testSingleProcessIsNotGrouped() {
        let group = ProcessGroup(processes: [
            ProcessSnapshot(
                id: 412,
                name: "Browser",
                cpuFraction: 0.02,
                groupIdentifier: "com.example.browser",
                groupName: "Browser"
            )
        ])

        #expect(!group.containsMultipleProcesses)
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

    @Test("Apple system component paths are classified as system daemons")
    func testAppleSystemComponentClassification() {
        #expect(
            ProcessCollector.isUserProcess(
                uid: 501,
                executablePath: "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/PlugIns/XProtectPluginService.xpc/Contents/MacOS/XProtectPluginService"
            ) == false
        )
        #expect(ProcessCollector.isUserProcess(uid: 501, executablePath: "/Applications/Editor.app/Contents/MacOS/Editor"))
        #expect(ProcessCollector.isUserProcess(uid: 499, executablePath: "/Applications/Editor.app/Contents/MacOS/Editor") == false)
    }
}
