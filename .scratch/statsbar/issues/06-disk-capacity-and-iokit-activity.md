# 06: Storage Capacity & Real-Time Disk I/O via IOKit

**What to build:** Real-time APFS volume capacity (Total, Used, Free) and active disk read/write throughput (MB/s) in the popover dashboard, queried using native Foundation volume keys and IOKit storage driver counters.

**Blocked by:** 01: Project Foundation, Sandboxed Menu Bar Pill & Telemetry Seam

**Status:** ready-for-agent

- [ ] Mounted volume capacity and available space are retrieved via standard volume resource keys
- [ ] Read and write bytes are queried from the block storage driver via IOKit registry statistics
- [ ] Disk I/O throughput rates (MB/s) are derived from byte count deltas over elapsed time
- [ ] Popover card visualizes storage usage and live read/write activity
- [ ] Unit tests verify storage byte formatting and read/write rate calculations
