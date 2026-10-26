import Testing
import SpecterCore
import SwiftUI

@Suite("Process Close Confirmation Tests")
@MainActor
struct ProcessCloseConfirmationTests {
    @Test("Presenting close request exposes app identity for confirmation")
    func presentsRequest() {
        let model = ProcessCloseConfirmationModel()

        model.present(bundleIdentifier: "com.example.editor", appName: "Editor")

        #expect(model.request == .init(target: .app(bundleIdentifier: "com.example.editor"), appName: "Editor"))
    }

    @Test("Requesting group close exposes the inline confirmation request")
    func requestClosePresentsRequest() {
        let model = ProcessCloseConfirmationModel()
        model.requestClose(bundleIdentifier: "com.example.editor", appName: "Editor")

        #expect(model.request == .init(target: .app(bundleIdentifier: "com.example.editor"), appName: "Editor"))
    }

    @Test("A new group-close request replaces a previous app request")
    func latestRequestIsShown() {
        let model = ProcessCloseConfirmationModel()
        model.requestClose(bundleIdentifier: "com.example.editor", appName: "Editor")
        model.requestClose(bundleIdentifier: "com.example.browser", appName: "Browser")

        #expect(model.request == .init(target: .app(bundleIdentifier: "com.example.browser"), appName: "Browser"))
    }

    @Test("Cancel clears close request without invoking close action")
    func cancelDoesNotCloseApp() {
        let model = ProcessCloseConfirmationModel()
        model.present(bundleIdentifier: "com.example.editor", appName: "Editor")
        var closedBundleIdentifiers: [String] = []

        model.cancel()
        let confirmed = model.confirm { request in
            if case .app(let bundleIdentifier) = request.target {
                closedBundleIdentifiers.append(bundleIdentifier)
            }
        }

        #expect(!confirmed)
        #expect(closedBundleIdentifiers.isEmpty)
        #expect(model.request == nil)
    }

    @Test("Confirm closes only the requested app once")
    func confirmClosesRequestedApp() {
        let model = ProcessCloseConfirmationModel()
        model.present(bundleIdentifier: "com.example.editor", appName: "Editor")
        var closedBundleIdentifiers: [String] = []

        let confirmed = model.confirm { request in
            if case .app(let bundleIdentifier) = request.target {
                closedBundleIdentifiers.append(bundleIdentifier)
            }
        }
        let confirmedAgain = model.confirm { request in
            if case .app(let bundleIdentifier) = request.target {
                closedBundleIdentifiers.append(bundleIdentifier)
            }
        }

        #expect(confirmed)
        #expect(!confirmedAgain)
        #expect(closedBundleIdentifiers == ["com.example.editor"])
        #expect(model.request == nil)
    }

    @Test("Ending an individual process requires confirmation and targets only its PID")
    func endProcessRequiresConfirmation() {
        var closedPIDs: [Int32] = []
        let model = ProcessCloseConfirmationModel()
        let row = ProcessItemRow(
            process: ProcessSnapshot(id: 512, name: "Editor Helper", cpuFraction: 0.1),
            metricType: .cpu,
            onEnd: { pid in
                closedPIDs.append(pid)
                return true
            },
            onRequestEnd: { process in
                model.requestEndProcess(pid: process.id, processName: process.name)
            }
        )

        row.requestEnd()

        #expect(closedPIDs.isEmpty)
        #expect(model.request == .init(target: .process(pid: 512), appName: "Editor Helper"))

        let confirmed = model.confirm { request in
            if case .process(let pid) = request.target {
                closedPIDs.append(pid)
            }
        }

        #expect(confirmed)
        #expect(closedPIDs == [512])
    }
}
