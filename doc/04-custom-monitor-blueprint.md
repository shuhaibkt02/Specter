# 04. Custom Lightweight Monitor Blueprint

An implementation blueprint for a personal, safe, and ultra-lightweight macOS menu bar monitor optimized specifically for Apple Silicon (Mac17,3 - Apple M5, 10 CPU cores).

---

## 1. Core Principles

1. **Safety First**:
   * **100% Offline**: Completely sandboxed without the `com.apple.security.network.client` entitlement.
   * **Zero Root/Elevated Daemons**: Pure user-space execution. No kernel extensions, no LaunchDaemons, no SMJobBless helper tools.
   * **No Global Event Sniffing**: No accessibility permissions, no keyboard monitoring.

2. **Ultra-Lightweight & Zero SSD Wear**:
   * **Zero Subprocesses**: No spawning of `/bin/ps`, `/usr/bin/top`, or `/usr/bin/nettop`. All process and system data fetched in-process via C `libproc` and Mach APIs.
   * **In-Memory Ring Buffers**: Historical chart data stored in volatile circular buffers (`RingBuffer<T>`). Zero SSD write wear.
   * **Dynamic Polling & Energy Throttling**:
     * Menu bar status items update on a slow, configurable timer (e.g. 2–3s).
     * High-frequency telemetry (top process lists, per-core breakdowns) **only** polls when the popover is actively open (`isPresented == true`).
     * Event-driven wakeups for battery status using `IOPSNotificationCreateRunLoopSource`.

3. **Apple Silicon M5 Specialization**:
   * Native `arm64` architecture.
   * 10-core telemetry breakdown (Efficiency vs. Performance cores).
   * Direct Apple Silicon GPU utilization via `IOAccelerator`.
   * Direct thermal monitoring via `IOHIDEventSystemClient`.

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Menubar Application                      │
│                  (SwiftUI / MenuBarExtra)                   │
└──────────────────────────────┬──────────────────────────────┘
                               │ Observes (@Published / @Observable)
┌──────────────────────────────▼──────────────────────────────┐
│                    Telemetry Coordinator                    │
│      - Manages sampling timers (Active vs. Idle rate)       │
│      - Coordinates metric collectors                        │
└───────┬──────────────┬──────────────┬─────────────┬─────────┘
        │              │              │             │
┌───────▼──────┐┌──────▼──────┐┌──────▼─────┐┌──────▼──────┐
│  CPU & Proc  ││  RAM & Swap ││ Network/Disk││  Battery   │
│  Collector   ││  Collector  ││ Collector  ││  Collector  │
└───────┬──────┘└──────┬──────┘└──────┬─────┘└──────┬──────┘
        │              │              │             │
        ▼              ▼              ▼             ▼
   [Mach Kernel] [Mach VM/sysctl][sysctl/IOKit] [IOPS Event]
   [  libproc  ]
```

---

## 3. Recommended Source Tree

```
StatsBar/
├── App/
│   ├── StatsBarApp.swift         # @main entry using SwiftUI MenuBarExtra
│   └── AppState.swift            # Global coordinator and settings
├── Collectors/
│   ├── CPUCollector.swift        # Mach host_processor_info & aggregate ticks
│   ├── ProcessCollector.swift    # libproc in-process top processes
│   ├── MemoryCollector.swift     # host_statistics64 & memorystatus pressure
│   ├── DiskCollector.swift       # FileManager & IOKit storage stats
│   ├── NetworkCollector.swift    # sysctl NET_RT_IFLIST2 interface speeds
│   ├── BatteryCollector.swift    # IOPS run loop event observer
│   └── ThermalCollector.swift    # IOHID Apple Silicon core temperatures
├── Models/
│   ├── CPUStats.swift            # Core metrics & per-core arrays
│   ├── MemoryStats.swift         # Active/Wired/Compressed/Pressure
│   ├── DiskStats.swift           # Volume usage & read/write MB/s
│   ├── NetworkStats.swift        # Up/Down bytes & formatted rates
│   └── RingBuffer.swift          # Fixed-size circular buffer for sparklines
├── Views/
│   ├── Menubar/
│   │   ├── MenubarItemView.swift # Compact menu bar display
│   │   └── SparklineView.swift   # Minimalist SwiftUI Canvas / Path sparkline
│   └── Popover/
│       ├── PopoverView.swift     # Expanded dropdown dashboard
│       ├── CPUSectionView.swift
│       ├── MemorySectionView.swift
│       └── ProcessListView.swift # Top process table
└── Supporting/
    ├── Bridging-Header.h         # Headers for libproc, mach, and IOKit
    └── StatsBar.entitlements     # Sandboxed entitlements (NO network)
```

---

## 4. Key Implementation Primitives

### A. Zero-Subprocess Process Collector (`libproc.h`)
```swift
import Darwin

struct ProcessInfo: Identifiable {
    let id: pid_t
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64
}

func getTopProcesses(limit: Int = 5) -> [ProcessInfo] {
    let count = proc_listallpids(nil, 0)
    guard count > 0 else { return [] }
    
    var pids = [pid_t](repeating: 0, count: Int(count))
    let actualCount = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
    guard actualCount > 0 else { return [] }
    
    var results: [ProcessInfo] = []
    
    for pid in pids.prefix(Int(actualCount)) where pid > 0 {
        var taskInfo = proc_taskinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
        guard size == MemoryLayout<proc_taskinfo>.size else { continue }
        
        var nameBuffer = [CChar](repeating: 0, count: 256)
        _ = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        let name = String(cString: nameBuffer)
        
        results.append(ProcessInfo(
            id: pid,
            name: name.isEmpty ? "PID \(pid)" : name,
            cpuPercent: 0.0, // Calculated via delta(total_user + total_system) / delta_t
            memoryBytes: taskInfo.pti_resident_size
        ))
    }
    
    return Array(results.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(limit))
}
```

### B. In-Memory Ring Buffer (`RingBuffer.swift`)
```swift
public struct RingBuffer<T> {
    private var buffer: [T?]
    private var writeIndex: Int = 0
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.buffer = [T?](repeating: nil, count: capacity)
    }

    public mutating func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
    }

    public var values: [T] {
        var ordered: [T] = []
        for i in 0..<capacity {
            let index = (writeIndex + i) % capacity
            if let item = buffer[index] {
                ordered.append(item)
            }
        }
        return ordered
    }
}
```

### C. Offline Sandbox Configuration (`StatsBar.entitlements`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <!-- Explicitly NO network client entitlement -->
    <key>com.apple.security.network.client</key>
    <false/>
</dict>
</plist>
```

---

## 5. Summary

With this blueprint:
* The monitor runs as an **unprivileged sandboxed application**.
* Resource usage is virtually zero when the menu bar popover is closed.
* Your SSD is completely protected from continuous write cycles.
* Privacy and security are guaranteed by design.
