# 07: Event-Driven Battery Telemetry & Power State

**What to build:** Event-driven battery monitoring that wakes only on power source events, displaying charge percentage, power source (AC/Battery), charging state, and estimated time remaining in the popover with zero idle polling overhead.

**Blocked by:** 01: Project Foundation, Sandboxed Menu Bar Pill & Telemetry Seam

**Status:** completed

- [x] Power source information is read via IOKit Power Sources API
- [x] Run-loop observer source triggers updates only when battery state changes (0% idle polling CPU)
- [x] Charge percentage, charging state, and time remaining are extracted
- [x] Popover card displays clean battery gauge and power status
- [x] Optional compact battery glyph rendered in the menu bar pill
- [x] Unit tests verify power source dictionary parsing and time-remaining formatting
