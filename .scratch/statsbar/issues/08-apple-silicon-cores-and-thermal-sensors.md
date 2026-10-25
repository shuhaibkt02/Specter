# 08: Apple Silicon M-Series Per-Core Breakdown & Thermal Sensors

**What to build:** An Apple Silicon hardware detail section in the popover dashboard showing per-core CPU utilization split across Performance (P) and Efficiency (E) cores, alongside chip thermal readings obtained safely via unprivileged IOHID thermal events.

**Blocked by:** 02: Live In-Process CPU Telemetry & Sparkline, 03: Two-Tier Adaptive Polling & In-Process `libproc` Top Processes

**Status:** ready-for-agent

- [ ] Per-core Mach tick data is mapped to Apple Silicon Performance and Efficiency core clusters
- [ ] Popover displays mini per-core utilization bars
- [ ] SoC temperatures are queried via user-space IOHIDEventSystemClient without root privileges or kernel extensions
- [ ] Thermals and per-core queries are active only when the popover is open
- [ ] Unit tests verify core topology partitioning and core load percentage calculations
