# 04: Live Memory Breakdown & System Memory Pressure

**What to build:** Real-time RAM statistics (Used, Active, Wired, Compressed, Free, and Swap) and system memory pressure level (Normal, Warning, Critical) displayed in the menu bar pill and popover dashboard card.

**Blocked by:** 01: Project Foundation, Sandboxed Menu Bar Pill & Telemetry Seam

**Status:** ready-for-agent

- [ ] Virtual memory page statistics are retrieved via Mach VM host statistics
- [ ] Memory pressure level is queried via BSD sysctl and categorized into Normal (Green), Warning (Yellow), and Critical (Red)
- [ ] Swap usage (total, used, free) is queried via BSD sysctl
- [ ] Popover dashboard displays a memory card breakdown with clear category bars
- [ ] Menu bar pill optionally shows formatted RAM usage (e.g. `6.4G`)
- [ ] Unit tests verify memory page multiplication, used memory formulas, and pressure level mapping
