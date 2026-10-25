import SwiftUI
import AppKit
import StatsBarCore

@main
struct StatsBarApp: App {
    @State private var coordinator: TelemetryCoordinator

    init() {
        // Ticket 01 uses MockTelemetryProvider as the high-level seam baseline.
        // Subsequent tickets will wire up the live in-process collectors.
        let initialCPU = CPUStats(usageFraction: 0.12, logicalCoreCount: 10)
        let initialMemory = MemoryStats(usedBytes: 6_871_947_673, totalBytes: 17_179_869_184, pressure: .normal)
        let provider = MockTelemetryProvider(cpu: initialCPU, memory: initialMemory)
        _coordinator = State(initialValue: TelemetryCoordinator(provider: provider))
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("StatsBar (Engine Placeholder)")
                    .font(.headline)
                
                Divider()

                Text("CPU: \(coordinator.currentCPU.percentageString)")
                    .monospacedDigit()
                Text("Memory: \(coordinator.currentMemory.formattedUsedGB)")
                    .monospacedDigit()
                
                Divider()

                Button("Quit StatsBar") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 220)
        } label: {
            MenuBarPillView(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
