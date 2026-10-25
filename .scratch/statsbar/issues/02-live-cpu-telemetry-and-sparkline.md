# 02: Live In-Process CPU Telemetry & Sparkline

**What to build:** Real-time aggregate CPU utilization displayed in the menu bar pill (`C: XX%`), driven by in-process Mach kernel ticks, coupled with an in-memory ring buffer providing live sparkline chart data without any disk writes.

**Blocked by:** 01: Project Foundation, Sandboxed Menu Bar Pill & Telemetry Seam

**Status:** completed

- [x] Aggregate CPU utilization percentage is retrieved via Mach kernel statistics
- [x] Memory allocated by kernel calls is cleanly deallocated on every tick
- [x] Menu bar item updates dynamically using fixed-width monospaced numbers with zero horizontal jitter
- [x] Historical values are stored in a fixed-size in-memory circular buffer with zero SSD writes
- [x] Sparkline curve renders the recent CPU history smoothly
- [x] Unit tests verify tick delta math, counter wraparound, and ring buffer FIFO capacity guarantees
