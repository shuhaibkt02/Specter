# Specification: Ultra-Lightweight macOS System Monitor (StatsBar)

## Problem Statement

As a MacBook user, I want to monitor my Mac's real-time hardware performance (CPU, Memory, Network, Disk, Battery, and Temperatures) directly from my menu bar without compromising my laptop's security, privacy, battery life, or screen real estate.

Existing open-source monitors (such as `exelban/stats`) have accumulated significant bloat and serious security vulnerabilities:
1. **Security Vulnerabilities & Attack Surface**: They install privileged root helper daemons (`SMCHelper` with CVE-2025-21606 / GHSA-qwhf-px96-7f6v Local Privilege Escalation), communicate with external remote cloud servers, run unconstrained network updaters, and monitor global keystrokes.
2. **Resource & Battery Drain**: They frequently fork child CLI processes (`/bin/ps`, `/usr/bin/top`, `/usr/bin/nettop`) and execute uncoordinated independent timers for each module, waking Apple Silicon CPU cores from deep power-saving states and draining laptop battery.
3. **SSD Storage Wear**: They continuously write metrics to an embedded disk database (LevelDB) on soldered, non-replaceable MacBook SSDs.
4. **Menu Bar Jitter & Notch Clutter**: They create multiple separate menu bar icons that crowd the MacBook camera notch and use variable-width proportional fonts that constantly jitter horizontally as numbers change.

I want a personal, standalone, ultra-lightweight system monitor built natively for Apple Silicon that runs strictly offline, with zero root daemons, zero disk writes, zero subprocess forks, and a unified, jitter-free menu bar UI.

---

## Solution

A native, sandboxed Apple Silicon macOS menu bar application built with modern Swift and SwiftUI:
1. **100% Offline & Private**: Sandboxed without network client entitlements. Completely incapable of inbound or outbound network transmission. Zero root daemons or privileged helper tools.
2. **Ultra-Lightweight In-Process Engine**: Zero subprocess spawning. All process queries and telemetry use direct C/Mach APIs (`libproc`, `mach_host`, `sysctl`, `IOKit`, `IOHID`).
3. **Coordinated Master Tick**: A single central timer coalesces all metric sampling into one batch cycle (< 0.2ms runtime), allowing CPU cores to remain in deep C-state sleep.
4. **Two-Tier Adaptive Polling**: When the dropdown popover is closed (99.9% of the time), expensive collectors (such as per-core breakdowns and process lists) are completely paused. They only activate while the user actively inspects the popover.
5. **Zero SSD Wear**: All historical chart data is maintained purely in volatile in-memory ring buffers (`RingBuffer`). Zero bytes written to disk.
6. **Unified, Jitter-Free UI**: A single, elegant status pill in the menu bar beside the camera notch displaying essential metrics, styled with monospaced tabular digits so text width never jumps or shifts. Clicking reveals a clean SwiftUI dashboard with live sparklines and top processes.

---

## User Stories

1. As a MacBook user, I want to see my aggregate CPU utilization percentage in the menu bar, so that I can immediately tell when an application is consuming excessive processor capacity.
2. As a MacBook user, I want the menu bar text to use monospaced digits, so that the numbers do not jump or twitch horizontally when values change.
3. As a MacBook user, I want all key metrics combined into a single unified menu bar item, so that my menu bar remains organized and never collides with the camera notch.
4. As a privacy-conscious user, I want the application to operate completely offline without network entitlements, so that my system telemetry and running process names can never leave my machine.
5. As a security-conscious user, I want the application to run entirely in standard user space without privileged helper tools or root daemons, so that it cannot expose my Mac to local privilege escalation attacks.
6. As a battery-conscious user, I want the application to query process telemetry directly in-process via kernel APIs rather than spawning `/bin/ps` or `/usr/bin/top`, so that it does not waste battery or trigger process creation overhead.
7. As a MacBook owner, I want telemetry history stored strictly in volatile RAM ring buffers rather than on disk, so that it does not cause continuous SSD write wear on my soldered storage.
8. As a MacBook user, I want the app to sample all metrics within a single coordinated master tick, so that my Apple Silicon CPU cores can remain in deep sleep states for over 99% of the time.
9. As a MacBook user, I want intensive process and per-core queries to pause whenever the popover is closed, so that background CPU usage remains under 0.1%.
10. As a MacBook user, I want to click the menu bar pill to open a detailed popover dashboard, so that I can inspect deep diagnostic metrics only when I choose to.
11. As a MacBook user, I want to see a live sparkline graph of CPU history in the popover, so that I can track recent activity trends over the last 30 to 60 seconds.
12. As an Apple Silicon user, I want to see a breakdown of CPU utilization across Performance and Efficiency cores in the popover, so that I understand how macOS is scheduling my workload.
13. As a MacBook user, I want to view the top 5 CPU-consuming processes in the popover, so that I can identify and terminate unresponsive or runaway tasks.
14. As a MacBook user, I want to see real-time RAM usage (Used, Cached, Free, and Swap) in the popover, so that I can monitor my system memory footprint accurately.
15. As a MacBook user, I want to see system memory pressure categorized as Normal (Green), Warning (Yellow), or Critical (Red), so that I know when my Mac is running out of physical RAM.
16. As a MacBook user, I want to view the top 5 memory-consuming applications in the popover, so that I can identify memory-hungry programs or leaks.
17. As a MacBook user, I want to see live network upload and download throughput in the menu bar, so that I know when large file transfers or network syncs are active.
18. As a MacBook user, I want to see my current local IP address and primary active network interface in the popover, so that I can troubleshoot network configuration issues.
19. As a MacBook user, I want network throughput measurements to query kernel routing statistics directly via `sysctl`, so that the measurement runs in microseconds without shell pipes.
20. As a VPN user, I want network metrics to monitor the physical hardware interface rather than virtual tunnel interfaces, so that throughput counters are not doubled or dropped to zero.
21. As a MacBook user, I want to view disk free space and total storage capacity for my primary APFS volume in the popover, so that I can avoid running out of disk space.
22. As a MacBook user, I want to see real-time disk read and write speeds (MB/s) in the popover, so that I can detect heavy disk I/O operations.
23. As a MacBook user, I want battery state and percentage updates to be event-driven via power source notifications, so that the app consumes 0% CPU while on steady battery or AC power.
24. As a MacBook user, I want to see battery health, charging state, and estimated time remaining in the popover, so that I can manage my mobile work sessions effectively.
25. As an Apple Silicon user, I want to see chip thermal readings queried via IOHID thermal events, so that I can monitor temperatures safely without kernel extensions.
26. As an Apple Silicon user, I want to see integrated GPU utilization in the popover, so that I can observe graphics workload intensity.
27. As a user, I want to customize which metrics appear in the menu bar pill (e.g. toggle CPU, RAM, or Network), so that I only see the information relevant to me.
28. As a user, I want to configure the background sampling interval (e.g. 1s, 2s, 3s), so that I can balance real-time responsiveness with battery preservation.
29. As a user, I want the popover to dismiss automatically when clicking outside or pressing Escape, so that it integrates seamlessly with macOS desktop behavior.
30. As a user, I want the application to automatically adapt to macOS Dark Mode and Light Mode, so that it visually matches native Apple menu bar accessories.

---

## Implementation Decisions

### 1. Architectural Model & Core Modules
* The application is structured into four functional layers:
  * **Domain Models**: Immutable value types representing telemetry snapshots (CPU snapshot, Memory snapshot, Disk snapshot, Network snapshot, Battery snapshot, Process snapshot).
  * **Telemetry Collectors**: Specialized, stateless or minimal-state collector engines that interact with specific low-level system APIs.
  * **Telemetry Coordinator**: A centralized actor/observable object that manages the master timer, schedules collectors, coordinates two-tier polling (idle vs active), and publishes state updates.
  * **User Interface**: Declarative SwiftUI views rendering the menu bar pill (`MenuBarExtra` / `NSStatusItem`) and the interactive popover dashboard.

### 2. Zero-Subprocess Telemetry Engines
* **Process Inspection**: Implemented via direct Darwin C `libproc` routines (`proc_listallpids`, `proc_pidinfo` with `PROC_PIDTASKINFO`, and `proc_name`). No shell processes or external binaries will be executed.
* **CPU Sampling**: Uses Mach kernel `host_processor_info` with `PROCESSOR_CPU_LOAD_INFO` and `host_statistics` with `HOST_CPU_LOAD_INFO`.
* **Memory & Swap Sampling**: Uses Mach kernel `host_statistics64` with `HOST_VM_INFO64`, BSD `sysctlbyname("kern.memorystatus_vm_pressure_level")`, and `sysctlbyname("vm.swapusage")`.
* **Network Throughput**: Uses BSD routing socket `sysctl` with `NET_RT_IFLIST2` to read `ifi_ibytes` and `ifi_obytes`.
* **Disk I/O Throughput**: Uses IOKit registry property `kIOBlockStorageDriverStatisticsKey` queried via DiskArbitration and IOMedia.
* **Battery & Power**: Uses IOKit `IOPSCopyPowerSourcesInfo` combined with run-loop notifications (`IOPSNotificationCreateRunLoopSource`).
* **Thermals & GPU**: Uses `IOHIDEventSystemClient` for thermal sensors and `IOAccelerator` registry entries for Apple Silicon GPU utilization.

### 3. Master Coordinated Tick & Adaptive Two-Tier Polling
* A single `DispatchSourceTimer` drives telemetry updates on a private background queue.
* **Tier 1 (Background Mode)**: When the popover is closed, the coordinator executes only the lightweight menu bar collectors (aggregate CPU, RAM pressure level, and network throughput deltas). Per-core statistics, disk volume directory scans, and `libproc` process tables are suspended.
* **Tier 2 (Active Dashboard Mode)**: When the user opens the popover, the coordinator activates all deep collectors and increases timer frequency to 1.0s. Once closed, Tier 1 is restored.

### 4. In-Memory Ring Buffer Strategy
* Historical sparkline data is stored in fixed-size circular ring buffers.
* Ring buffers hold a maximum of 30 to 60 floating-point numbers.
* Zero data is persisted to disk, avoiding LevelDB or SQLite dependencies and eliminating SSD write cycles.

### 5. UI Presentation & Layout Stability (Detailed in [07. UI/UX Design Direction](07-ui-ux-design-and-laws.md))
* **Menu Bar Pill**: Rendered as a single consolidated `NSStatusItem` pill with 3 default segments (CPU, Memory, Network). Fixed segment width reservation computed at launch from worst-case localized strings eliminates horizontal layout jitter. Numbers use SF Mono / SF Pro `.monospacedDigit()`.
* **Zero Color at Rest**: Template tint (`.primary`) for idle telemetry. Color (amber/red) is strictly reserved as an exception for critical/warning states (Von Restorff effect).
* **The Popover Cockpit**: Fixed 320pt width, native `.regularMaterial` / `.thickMaterial`, 5 structured cards (CPU, Memory, Network, Disk, Battery) following an identical 5-slot composition (title, live value, sparkline, breakdown, top processes).
* **Zero-Reflow Tier-2 Escalation**: Skeleton rows for per-core bars and process lists are pre-allocated with 0 opacity and fade in (150ms ease-out) so the popover geometry never pops or shifts.
* **Sparklines**: Single continuous 1px `Path` rendered from `RingBuffer<Float>` (60s history), crossfading only the newest point (200ms) with zero whole-graph shifting.
* **Process Termination Guard**: Hover-revealed 20×20pt `✕` affordance with single-tap inline confirmation to prevent accidental SIGTERM actions.
* **Anti-Settings Panel**: Opinionated 5-control panel (segments selection, interval, temperature unit, launch-at-login, per-core toggle).
* **Accessibility**: Full VoiceOver integration reading complete semantic descriptions and pressure levels. Honors Increase Contrast and Reduce Transparency.

### 6. Sandbox & Security Configuration
* Configured with strict App Sandbox.
* `com.apple.security.network.client` and `com.apple.security.network.server` are explicitly omitted or set to `false`.
* No privileged helper tools, XPC launch daemons, or accessibility event taps are included.

---

## Testing Decisions

### What Makes a Good Test
* Tests must verify **external behavior and calculations**, not private kernel implementation details.
* Tests should not make live kernel syscalls or depend on running hardware state (which is nondeterministic across CI environments).
* Test suites should verify metric transformations, ring buffer mechanics, rate calculations (delta bytes / delta time), threshold categorizations, and view-model state transitions.

### Testing Seam
* **The Telemetry Provider Protocol (`TelemetryProviding`)**:
  * All low-level data collectors conform to a high-level provider interface.
  * The `TelemetryCoordinator` consumes this protocol.
  * In unit tests, a `MockTelemetryProvider` injects controlled synthetic tick snapshots (e.g. simulated user/system/idle CPU ticks, memory page counts, network byte counters).
  * Tests assert that:
    1. CPU percentage deltas are mathematically correct, bounded between 0.0 and 1.0, and handle counter wraparound gracefully.
    2. Network transfer rates accurately reflect bytes divided by elapsed time and format correctly.
    3. Memory pressure values correctly map numeric levels to `.normal`, `.warning`, and `.critical`.
    4. Two-tier throttling correctly suspends expensive collectors when the popover state is inactive.
    5. Ring buffers maintain exact fixed capacities and maintain FIFO ordering.

### Modules Tested
1. **`RingBufferTests`**: Capacity bounds, eviction of oldest elements, FIFO sequence ordering, array conversion.
2. **`RateCalculatorTests`**: Elapsed-time rate derivations for network bytes and disk I/O, counter reset handling.
3. **`MemoryCalculatorTests`**: Proper multiplication of page counts by page size, used/cache/free formulas, pressure mapping.
4. **`TelemetryCoordinatorTests`**: State publication, master tick execution, transition between Tier 1 (idle) and Tier 2 (active) modes.

---

## Out of Scope

1. **Fan Speed Control & Writing to SMC**: Writing to hardware registers or installing root helper daemons is strictly excluded to prevent security vulnerabilities and hardware stress.
2. **Cloud Synchronization / Remote Monitoring**: No web sockets, external APIs, or remote machine tracking.
3. **Outbound Update Checking**: No auto-downloaders or background network checks. Updates will be handled manually by the user.
4. **WidgetKit Notification Center / Desktop Extensions**: No auxiliary app extensions, avoiding CPU render loops in `NotificationCenter`.
5. **Legacy Intel x86 Optimizations**: The app is purpose-built for modern Apple Silicon Macs (`arm64`).

---

## Further Notes

* Target Environment: Apple Silicon Mac (Apple M5 / M-series), macOS 14+ (Sonoma, Sequoia, and later).
* The project will be built natively in Swift using standard Xcode / Swift Package tooling.
