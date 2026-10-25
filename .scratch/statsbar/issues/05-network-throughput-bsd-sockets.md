# 05: Real-Time Network Throughput via BSD Routing Sockets

**What to build:** Live network upload and download throughput (e.g. `↓1.2M ↑45K`) rendered in the menu bar pill and popover card by querying kernel routing table statistics directly via BSD `sysctl` on the active physical network interface.

**Blocked by:** 01: Project Foundation, Sandboxed Menu Bar Pill & Telemetry Seam

**Status:** completed

- [x] Network byte counters (`ifi_ibytes`, `ifi_obytes`) are read via BSD `sysctl` routing messages
- [x] Active physical interface (e.g. `en0`) is dynamically resolved, avoiding virtual VPN `utun` adapters
- [x] Upload and download speeds are derived from byte deltas divided by elapsed time
- [x] Menu bar pill formats speeds with fixed monospaced units (B/s, KB/s, MB/s) with zero jitter
- [x] Popover card displays live network transfer rates and local IP address
- [x] Unit tests verify rate derivation, handling of initial ticks, and network interface transitions
