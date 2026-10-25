# Custom macOS Stats Monitor - Research & Documentation

This folder documents the analysis and reverse-engineering of [exelban/stats](https://github.com/exelban/stats), along with the architecture specification for building a personal, safe, secure, and ultra-lightweight menu bar system monitor for Apple Silicon MacBooks.

---

## Target Machine Context
* **Hardware Model**: `Mac17,3`
* **SoC / Architecture**: Apple M5 (`arm64`), 10 CPU cores (Performance + Efficiency cores)
* **Operating System**: macOS Sequoia+ (Darwin kernel)

---

## Documentation Index

1. **[01. Exelban Stats Architecture Analysis](01-exelban-stats-architecture.md)**
   * Deep-dive into the architectural components of `exelban/stats` (`Stats`, `Kit`, `Modules`, `SMC`).
   * Breakdown of the Reader-Module-Widget design pattern.
   * Lifecycle management and popover presentation.

2. **[02. macOS Low-Level Telemetry APIs](02-system-apis-and-telemetry.md)**
   * In-depth documentation of the C, Mach, BSD, and IOKit system APIs used to retrieve telemetry data.
   * CPU per-core Mach ticks, RAM VM stats & memory pressure levels, Disk I/O storage driver counters, BSD network routing tables, and IOHID thermal sensors on Apple Silicon.

3. **[03. Security, Privacy & Performance Audit](03-security-and-performance-audit.md)**
   * Detailed evaluation of `exelban/stats` resource consumption and security trade-offs.
   * Why spawning subprocesses (`/bin/ps`, `/usr/bin/top`, `/usr/bin/nettop`) hurts battery life and performance.
   * Risks of privileged root helper daemons (`SMCHelper`), disk wear from LevelDB history logging, outbound cloud sync (`Remote`), and global event taps.

4. **[04. Custom Lightweight Monitor Blueprint](04-custom-monitor-blueprint.md)**
   * Architectural specifications for the new personal monitor.
   * Zero-network sandbox policy, zero-root privilege model.
   * Direct in-process telemetry via `libproc` and Mach APIs (sub-millisecond overhead).
   * In-memory ring buffers (`RingBuffer<T>`) for zero disk writes.
   * Modern Swift & SwiftUI menu bar implementation plan.

5. **[05. Security Vulnerabilities & Known Issues Analysis](05-security-vulnerabilities-and-repo-issues.md)**
   * Deep-dive into CVE-2025-21606 / GHSA-qwhf-px96-7f6v (Local Privilege Escalation via XPC root helper daemon).
   * Common operational bugs from GitHub Issues: menu bar width jitter, camera notch overcrowding, NotificationCenter 50% CPU render loops, memory/port leaks, and VPN bandwidth doubling.
   * Direct UI/UX critiques and improvements for our personal custom monitor.

6. **[06. Ultra-Lightweight Engineering Strategy](06-ultra-lightweight-engineering-strategy.md)**
   * The 6 technical pillars to make the monitor ultra-lightweight and objectively better than `Stats`.
   * Timer coalescing, two-tier adaptive polling (closed vs open popover), in-process `libproc` vs subprocess forks, and zero-SSD-wear ring buffers.
   * Side-by-side performance, memory, and energy comparison matrix.
