# 02: Live In-Process CPU Telemetry & Sparkline

**What to build:** Real-time aggregate CPU utilization displayed in the menu bar pill (`C: XX%`), driven by in-process Mach kernel ticks, coupled with an in-memory ring buffer providing live sparkline chart data without any disk writes.

**Blocked by:** 01: Project Foundation, Sandboxed Menu Bar Pill & Telemetry Seam

**Status:** ready-for-agent

- [ ] Aggregate CPU utilization percentage is retrieved via Mach kernel statistics
- [ ] Memory allocated by kernel calls is cleanly deallocated on every tick
- [ ] Menu bar item updates dynamically using fixed-width monospaced numbers with zero horizontal jitter
- [ ] Historical values are stored in a fixed-size in-memory circular buffer with zero SSD writes
- [ ] Sparkline curve renders the recent CPU history smoothly
- [ ] Unit tests verify tick delta math, counter wraparound, and ring buffer FIFO capacity guarantees
