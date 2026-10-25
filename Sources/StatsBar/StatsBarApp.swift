import SwiftUI
import AppKit
import StatsBarCore

@main
struct StatsBarApp: App {
    @State private var coordinator: TelemetryCoordinator

    init() {
        // Uses production SystemTelemetryProvider with live Mach CPUCollector
        let provider = SystemTelemetryProvider()
        _coordinator = State(initialValue: TelemetryCoordinator(provider: provider))
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("StatsBar (Engine Placeholder)")
                    .font(.headline)
                
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CPU Usage:")
                            .font(.subheadline)
                        Spacer()
                        Text(coordinator.currentCPU.percentageString)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    
                    SparklineView(values: coordinator.cpuHistory)
                        .frame(height: 36)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Divider()

                Text("Memory: \(coordinator.currentMemory.formattedUsedGB)")
                    .monospacedDigit()
                
                Divider()

                Button("Quit StatsBar") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 240)
            .onAppear {
                coordinator.isPopoverPresented = true
            }
            .onDisappear {
                coordinator.isPopoverPresented = false
            }
        } label: {
            MenuBarPillView(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
