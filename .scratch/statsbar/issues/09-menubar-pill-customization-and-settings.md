# 09: Menu Bar Pill Customization & Preference Persistence

**What to build:** A lightweight settings interface within the popover allowing the user to customize which metrics appear in the menu bar pill (toggle CPU, RAM, Network speeds, Battery) and adjust the background update interval, persisted in standard user defaults.

**Blocked by:** 02: Live In-Process CPU Telemetry & Sparkline, 04: Live Memory Breakdown & System Memory Pressure, 05: Real-Time Network Throughput via BSD Routing Sockets

**Status:** completed

- [x] Popover includes an intuitive settings view (strict 5-control anti-settings panel per Doc 07)
- [x] User can reorder and toggle visibility of individual pill segments (CPU, Mem, Net default)
- [x] User can select background polling interval (1s, 2s, 3s; default 2s)
- [x] Preferences persist across application launches using `UserDefaults`
- [x] Menu bar pill updates layout reactively with zero-jitter fixed reserved widths
- [x] Unit tests verify preference serialization, deserialization, and reactive state publication
