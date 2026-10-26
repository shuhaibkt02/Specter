import Foundation

public struct ProcessGroup: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let processes: [ProcessSnapshot]
    public var containsMultipleProcesses: Bool { processes.count > 1 }

    public init(processes: [ProcessSnapshot]) {
        precondition(!processes.isEmpty, "A process group must contain at least one process.")
        let first = processes[0]
        self.id = first.groupIdentifier ?? "pid:\(first.id)"
        self.name = first.groupName ?? first.name
        self.processes = processes
    }

    public var cpuFraction: Double {
        processes.reduce(0) { $0 + $1.cpuFraction }
    }

    public var ramBytes: UInt64 {
        processes.reduce(0) { $0 &+ $1.ramBytes }
    }

    public var formattedCPU: String {
        "\(Int((cpuFraction * 100).rounded()))%"
    }

    public func matches(searchQuery: String) -> Bool {
        searchQuery.isEmpty
            || name.localizedCaseInsensitiveContains(searchQuery)
            || processes.contains {
                $0.name.localizedCaseInsensitiveContains(searchQuery)
                    || String($0.id).contains(searchQuery)
            }
    }

    public var formattedRAM: String {
        ProcessSnapshot(
            id: processes[0].id,
            name: name,
            cpuFraction: cpuFraction,
            ramBytes: ramBytes
        ).formattedRAM
    }
}
