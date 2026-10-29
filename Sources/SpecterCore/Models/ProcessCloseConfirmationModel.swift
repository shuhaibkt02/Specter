import Foundation
import Observation

@Observable
@MainActor
public final class ProcessCloseConfirmationModel {
    public enum Target: Equatable, Sendable {
        case app(bundleIdentifier: String)
        case process(pid: Int32)
    }

    public struct Request: Identifiable, Equatable, Sendable {
        public let target: Target
        public let appName: String
        public var id: String {
            switch target {
            case .app(let bundleIdentifier): return bundleIdentifier
            case .process(let pid): return "pid:\(pid)"
            }
        }

        public init(target: Target, appName: String) {
            self.target = target
            self.appName = appName
        }
    }

    public private(set) var request: Request?
    public private(set) var closingGroupIdentifiers: Set<String> = []
    public private(set) var closingPIDs: Set<pid_t> = []

    public init() {}

    public func markGroupClosing(_ identifier: String) {
        closingGroupIdentifiers.insert(identifier)
    }

    public func clearGroupClosing(_ identifier: String) {
        closingGroupIdentifiers.remove(identifier)
    }

    public func markPIDClosing(_ pid: pid_t) {
        closingPIDs.insert(pid)
    }

    public func clearPIDClosing(_ pid: pid_t) {
        closingPIDs.remove(pid)
    }

    public func isGroupClosing(_ identifier: String) -> Bool {
        closingGroupIdentifiers.contains(identifier)
    }

    public func isPIDClosing(_ pid: pid_t) -> Bool {
        closingPIDs.contains(pid)
    }

    public func present(bundleIdentifier: String, appName: String) {
        request = Request(target: .app(bundleIdentifier: bundleIdentifier), appName: appName)
    }

    public func requestClose(bundleIdentifier: String, appName: String) {
        present(bundleIdentifier: bundleIdentifier, appName: appName)
    }

    public func requestEndProcess(pid: Int32, processName: String) {
        request = Request(target: .process(pid: pid), appName: processName)
    }

    public func cancel() {
        request = nil
    }

    @discardableResult
    public func confirm(onConfirm: (Request) -> Void) -> Bool {
        guard let request else { return false }
        self.request = nil
        onConfirm(request)
        return true
    }
}
