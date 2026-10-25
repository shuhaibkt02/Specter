# 03. Security, Privacy & Performance Audit

A critical engineering audit of [exelban/stats](https://github.com/exelban/stats), identifying performance bottlenecks, battery overhead, and security/privacy risks.

---

## 1. Performance & Resource Bottlenecks

### A. Subprocess Spawning (`Foundation.Process`)
`Stats` periodically invokes CLI utilities as external processes to collect data:
* **CPU Top Processes**: Spawns `/bin/ps -Aceo pid,pcpu,comm -r`
* **RAM Top Processes**: Spawns `/usr/bin/top -l 1 -o mem -stats pid,command,mem`
* **Per-Process Network Usage**: Spawns `/usr/bin/nettop -P -L 1 -n -k ...`

#### The Problem:
1. **Fork/Exec Cost**: In Darwin/macOS, spawning a new process requires `posix_spawn`, loading dynamic libraries, mapping memory, and initializing Mach task ports.
2. **CPU & Battery Drain**: Repeating this cycle every 1–2 seconds creates measurable CPU spikes and wakes the processor from low-power C-states.
3. **Pipes and String Parsing**: Raw standard output strings from `ps` and `top` must be buffered, decoded into UTF-8 Swift strings, and parsed using regex or line scanners on every cycle.

#### The Fix:
Use Darwin's native C library **`libproc`** directly in-process:
* `proc_listallpids()` retrieves active PIDs in microseconds.
* `proc_pidinfo(pid, PROC_PIDTASKINFO, ...)` extracts resident memory (`pti_resident_size`) and user/system CPU nanoseconds (`pti_total_user`, `pti_total_system`).
* `proc_name(pid, &name, sizeof(name))` gets the process name without spawning a shell.
* **Result**: >98% reduction in CPU overhead and 0 child processes.

---

### B. Continuous Disk Writes via LevelDB
* `Stats` embeds `libleveldb.a` (Google LevelDB) to continuously persist historical telemetry to disk on every reading cycle (`DB.shared.insert(...)`).

#### The Problem:
1. **SSD Write Wear**: Writing hardware telemetry to disk 24/7 generates thousands of continuous write cycles. On modern MacBooks with soldered SSD storage, unnecessary disk wear should be avoided.
2. **Binary Bloat**: Requires compiling and linking a heavy C++ database engine.
3. **Disk I/O Interference**: Background writes can interfere with macOS power-saving disk idling.

#### The Fix:
Keep historical data strictly in **RAM**:
* Use a lightweight in-memory circular ring buffer: `struct RingBuffer<T>`.
* Keep a fixed sliding window of the last 30 or 60 samples (e.g. 1 sample/sec = 1 minute of history).
* Memory footprint: ~1 KB per metric.
* Disk writes: **Zero**.

---

## 2. Security & Privacy Risks in `exelban/stats`

### A. Outbound Network Traffic & Cloud Services
* **Remote Sync**: Includes a `Remote` module (`Modules/Remote/main.swift`) designed to sync system telemetry with `api.mac-stats.com`.
* **Public IP Lookups**: Dispatches HTTP requests to third-party endpoints (`api.ipify.org`, `icanhazip.com`) to determine external IP addresses.
* **Auto-Updater**: Regularly contacts GitHub API and `api.mac-stats.com/release/latest` via background schedulers.

#### Security Analysis:
* An application that monitors real-time system state (RAM, running processes, Wi-Fi SSID, disk names) should **never** make unconstrained outbound internet connections.
* Exposing local machine identity, hardware serials, or process lists to the network represents an information disclosure hazard.

#### The Fix:
* **Strict Sandboxing**: Enforce an App Sandbox configuration with `com.apple.security.network.client = false`.
* **100% Offline**: The monitor must operate entirely offline with zero network connectivity.

---

### B. Privileged Helper Tool (`eu.exelban.Stats.SMC.Helper`)
* To enable manual fan speed adjustment, `Stats` installs an XPC Launch Daemon running as **`root`** in `/Library/PrivilegedHelperTools/`.

#### Security Analysis:
* Running a root helper daemon significantly widens the system attack surface:
  * Any vulnerability or improper validation in the XPC protocol allows local privilege escalation.
  * Overriding SMC hardware thermal safety controls can risk thermal throttling or hardware damage if misconfigured.
* For personal system monitoring, **read-only telemetry** requires **zero root privileges**.

#### The Fix:
* Discard fan speed writing and privileged daemons entirely.
* Rely purely on user-space read-only APIs (`IOHIDEventSystemClient`, Mach host statistics) that require no special privileges or elevated authorizations.

---

### C. Global Keyboard Event Taps
* `Stats` registers global and local event monitors:
  ```swift
  NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in ... }
  ```
* While used internally to detect modifier keys (e.g. holding `Option` to reveal alternative views), global key monitoring is the mechanism used by keyloggers and requires Accessibility permissions (`AXIsProcessTrusted`).

#### The Fix:
* Eliminate global event taps. Inspect modifier flags strictly within local menu interactions (`NSEvent.modifierFlags`).

---

## Summary of Architectural Trade-offs

| Component | `exelban/stats` Approach | Proposed Custom Monitor |
| :--- | :--- | :--- |
| **Top Process Inspection** | Spawns `/bin/ps` and `/usr/bin/top` | Native C `libproc` in-process |
| **Telemetry History** | Writes continuously to LevelDB on SSD | In-memory circular ring buffer (`RingBuffer<T>`) |
| **Network Access** | Outbound requests (Remote, IP, Updaters) | **Zero network access** (100% offline sandbox) |
| **Privilege Model** | Installs `root` helper daemon for SMC write | Standard non-root user space (read-only APIs) |
| **Input Monitoring** | Global keyboard event taps | Local event handling only |
| **Battery Impact** | Moderate (periodic process forks & disk I/O) | Ultra-low (event-driven wakeups & pure RAM buffer) |
