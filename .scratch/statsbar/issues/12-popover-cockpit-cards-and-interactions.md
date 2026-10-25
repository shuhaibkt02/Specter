# 12: Popover Cockpit Cards & Interactive Hover Surfaces

**What to build:** Build the 5 cockpit cards in `Sources/StatsBar/Views/Cards/` (CPU, Memory, Network, Disk, Battery) inside a fixed 320pt popover container with `.regularMaterial`, 16pt card padding, 12pt inter-card gaps, P/E core breakdown bars, top 5 process list with hover PID/path tooltips and safe quit confirmation, and zero-flicker skeleton transitions.

**Blocked by:** 10: Design Tokens & Reusable Card Component Architecture

**Status:** completed

- [x] CPU Card: title, live %, sparkline, P-core and E-core track bars, top 5 process rows with hover selection
- [x] Memory Card: title, used / total GB, sparkline, Wired/Active/Compressed breakdown, Swap usage, pressure level indicator dot + text
- [x] Network Card: title, upload/download live rates, sparkline, active interface name and local IP
- [x] Disk Card: title, used / total GB, storage capacity track bar, read / write activity throughput
- [x] Battery Card: title, percentage, charging glyph, health percentage, time to full/empty
- [x] Unit tests verifying card layout metrics and process row hover / formatting
