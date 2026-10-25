# 09: Menu Bar Pill Customization & Preference Persistence

**What to build:** A lightweight settings interface within the popover allowing the user to customize which metrics appear in the menu bar pill (toggle CPU, RAM, Network speeds, Battery) and adjust the background update interval, persisted in standard user defaults.

**Blocked by:** 02: Live In-Process CPU Telemetry & Sparkline, 04: Live Memory Breakdown & System Memory Pressure, 05: Real-Time Network Throughput via BSD Routing Sockets

**Status:** ready-for-agent

- [ ] Popover includes an intuitive settings view (strict 5-control anti-settings panel per Doc 07)
- [ ] User can reorder and toggle visibility of individual pill segments (CPU, Mem, Net default)
- [ ] User can select background polling interval (1s, 2s, 3s; default 2s)
- [ ] Preferences persist across application launches using `UserDefaults`
- [ ] Menu bar pill updates layout reactively with zero-jitter fixed reserved widths
- [ ] Unit tests verify preference serialization, deserialization, and reactive state publication
