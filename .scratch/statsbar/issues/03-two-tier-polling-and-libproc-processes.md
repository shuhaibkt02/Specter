# 03: Two-Tier Adaptive Polling & In-Process `libproc` Top Processes

**What to build:** An interactive popover dashboard that opens upon clicking the menu bar pill, displaying the top 5 CPU-consuming processes fetched directly in-process via C `libproc`, while ensuring that process queries completely pause whenever the popover is closed.

**Blocked by:** 02: Live In-Process CPU Telemetry & Sparkline

**Status:** completed

- [x] Clicking the menu bar pill displays an interactive popover dashboard
- [x] Top 5 CPU-consuming processes are enumerated using `libproc` without spawning `/bin/ps` or `/usr/bin/top`
- [x] Background mode (popover closed) completely suspends process list polling to conserve battery (< 0.1% CPU)
- [x] Active mode (popover open) polls process telemetry at responsive 1-second intervals
- [x] Popover dismisses cleanly on external clicks or pressing Escape
- [x] Unit tests verify that two-tier polling triggers and pauses collectors according to presentation state
