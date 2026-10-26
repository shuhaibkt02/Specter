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

    public init() {}

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
