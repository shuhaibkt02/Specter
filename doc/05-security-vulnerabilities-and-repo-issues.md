# 05. Security Vulnerabilities & Known Issues Analysis

A detailed study of the security advisories and recurring operational issues affecting [exelban/stats](https://github.com/exelban/stats).

---

## 1. Security Advisory Deep-Dive: GHSA-qwhf-px96-7f6v (CVE-2025-21606)

* **Advisory ID**: [GHSA-qwhf-px96-7f6v](https://github.com/exelban/stats/security/advisories/GHSA-qwhf-px96-7f6v) / **CVE-2025-21606**
* **Severity**: **High / Critical** (Local Privilege Escalation - LPE)
* **Date Published**: January 17, 2025
* **Affected Versions**: `Stats` up to `v2.11.20`
* **Vulnerable Component**: `eu.exelban.Stats.SMC.Helper` (Privileged Mach XPC Service running as `root`)

### Root Cause Analysis
To allow fan speed overrides, `Stats` installs a privileged helper tool in `/Library/PrivilegedHelperTools/eu.exelban.Stats.SMC.Helper` managed by `launchd` running with **root (UID 0)** privileges.

In vulnerable versions, the XPC listener delegate implemented `shouldAcceptNewConnection` without client authentication:

```objc
// VULNERABLE PATTERN:
func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
    // Missing: Codesign audit token validation!
    // Missing: Client entitlement verification!
    return true // Unconditionally accepts connection from ANY local process
}
```

Furthermore, the exposed XPC protocol (`HelperProtocol`) provided methods including:
```swift
func setSMCPath(_ path: String)
func setFanSpeed(id: Int, value: Int, ...)
```

The helper tool took the file path passed across the connection and executed it via `Process()` with `root` privileges.

### Exploit Vector & Impact
1. **Arbitrary Root Execution**: Any untrusted local application, unprivileged user, or malware on the Mac could connect to the Mach service `eu.exelban.Stats.SMC.Helper` via standard `NSXPCConnection`.
2. Because the connection was accepted without validation, the attacker could pass an arbitrary binary path or manipulate helper parameters, achieving **instant local privilege escalation to `root`**.
3. **Physical / Thermal Destabilization**: Attackers could lock fan speeds to 0% or disable thermal throttling logic, risking thermal shutdowns or hardware stress under load.

### Key Lesson for Our Custom Monitor
* **Never use root helper daemons or privileged XPC services.**
* System monitoring is fundamentally a **read-only** task. All metrics (CPU, RAM, Disk, Net, Battery, Temperatures) can be obtained via user-space APIs (`mach_host`, `IOHIDEventSystemClient`, BSD `sysctl`, `IOPSCopyPowerSourcesInfo`).
* Omitting privileged helper tools eliminates this attack vector entirely.

---

## 2. Common Issues & Failure Modes (from GitHub Issues)

Reviewing [exelban/stats issues](https://github.com/exelban/stats/issues) reveals recurring architectural and design flaws:

### A. Menu Bar Jitter & Width Shifting (Issue #3708 & others)
* **Problem**: Text widgets (e.g. `CPU: 9%` $\rightarrow$ `CPU: 10%`, or `12 KB/s` $\rightarrow$ `1.2 MB/s`) use proportional system fonts. As character counts and digit glyph widths change, the status item's width constantly resizes.
* **Effect**: Adjacent menu bar items twitch and jump horizontally every second, creating significant visual annoyance.
* **Our Solution**:
  1. Use **monospaced numeric styling** (`.monospacedDigit()`) so every number has identical horizontal advance.
  2. Maintain a fixed container width for text widgets or use fixed-size compact mini-gauges.

### B. Camera Notch Overcrowding
* **Problem**: On modern MacBooks (M1–M5), the screen has a physical camera notch. `Stats` creates separate `NSStatusItem`s for CPU, RAM, Disk, Network, Battery, etc. Having 5–8 items quickly collides with the notch, causing macOS to hide items silently.
* **Our Solution**:
  * Unify all metrics into **one compact, cohesive menu bar item** (e.g., a single minimalist pill or mini combined gauge: `C:12% R:64% ↓2.1M`).
  * One single status item never crowds the notch.

### C. Background CPU Spikes & NotificationCenter Loops (Issue #2901)
* **Problem**: `Stats` includes a `WidgetsExtension.appex` (for macOS Notification Center / Desktop widgets). Buggy layout constraints in SwiftUI widgets caused `NotificationCenter` to get trapped in continuous 30%–50% CPU render loops.
* **Our Solution**:
  * Keep the application focused strictly as a **native menu bar tool**.
  * No unnecessary app extensions, WidgetKit daemons, or background helper extensions.

### D. Memory Bloat & Mach Port Leaks
* **Problem**: Some users observe `Stats` growing from ~40 MB to 400–700 MB of RAM.
* **Cause**:
  * Missing `vm_deallocate` on Mach processor info pointers.
  * Incomplete deallocation of IOKit iterator objects (`IOObjectRelease`).
  * Heavy in-memory LevelDB caches.
* **Our Solution**:
  * Strict memory management: wrap Mach calls with `defer { vm_deallocate(...) }` and `defer { IOObjectRelease(...) }`.
  * Total memory footprint target: **under 15–25 MB RAM total**.

### E. VPN Virtual Interface Confusion (`utun` vs Physical)
* **Problem**: When a VPN connects, macOS creates a virtual interface (`utun0`, `utun1`). `Stats` often locks onto `utun` or double-counts traffic (e.g. dividing by 2 as a workaround in `Net/readers.swift:331`).
* **Our Solution**:
  * Query interface stats strictly on physical hardware adapters (`en0`, `en1`) or the active default route interface via `SCDynamicStoreCopyValue`.
  * Avoid arbitrary numeric division hacks.

---

## 3. UI/UX Critiques & Design Goals for Our Monitor

| `exelban/stats` UI Flaws | Our Custom Design Direction |
| :--- | :--- |
| **Cluttered & Fragmented**: 6+ separate icons crowding the menu bar. | **Unified Single Status Item**: One clean, compact, elegant pill. |
| **Horizontal Jitter**: Numbers bouncing around due to proportional fonts. | **Monospaced Fixed-Width Glyphs**: Rock-solid layout stability. |
| **Bloated Settings Window**: Hundreds of configuration toggles and sub-menus. | **Zero-Fuss Minimalism**: Sensible defaults, clean popover dashboard. |
| **Inconsistent Dark/Light Mode Dimming**: Third-party icons look un-native on multi-monitor setups. | **Native SwiftUI Template Rendering**: Follows macOS system appearance dynamically. |
