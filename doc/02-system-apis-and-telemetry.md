# 02. macOS Low-Level Telemetry APIs

This document catalogs the exact low-level C, Mach, BSD, and IOKit APIs leveraged by macOS system monitors, detailing their mechanisms, structures, and usage.

---

## 1. CPU Telemetry

### A. Per-Core Utilization (`host_processor_info`)
* **Framework**: Mach Kernel API (`<mach/mach_host.h>`)
* **Call**: `host_processor_info(machHostPort, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &infoCount)`
* **Data Structure**: `processor_cpu_load_info_data_t` array containing 4 tick states per core:
  * `CPU_STATE_USER`
  * `CPU_STATE_SYSTEM`
  * `CPU_STATE_NICE`
  * `CPU_STATE_IDLE`
* **Calculation**:
  $$\text{inUse} = \Delta\text{user} + \Delta\text{system} + \Delta\text{nice}$$
  $$\text{total} = \text{inUse} + \Delta\text{idle}$$
  $$\text{Usage} = \frac{\text{inUse}}{\text{total}}$$
* **Critical Rule**: Memory allocated by the Mach kernel (`cpuInfo`) **must** be explicitly freed via `vm_deallocate(mach_task_self_, vm_address_t, vm_size_t)` on every iteration to prevent unbounded memory leaks.

### B. Aggregate System CPU Load (`host_statistics`)
* **Call**: `host_statistics(machHostPort, HOST_CPU_LOAD_INFO, pointer, &size)`
* **Data Structure**: `host_cpu_load_info` providing global system-wide tick counts.

---

## 2. Memory (RAM) & Swap Telemetry

### A. Virtual Memory Statistics (`host_statistics64`)
* **Framework**: Mach Kernel API
* **Call**: `host_statistics64(machHostPort, HOST_VM_INFO64, pointer, &count)`
* **Data Structure**: `vm_statistics64`
* **Metric Extraction**:
  * Multiply page counts by `vm_page_size` (typically 16,384 bytes / 16 KB on Apple Silicon):
    * `active_bytes = stats.active_count * vm_page_size`
    * `inactive_bytes = stats.inactive_count * vm_page_size`
    * `wired_bytes = stats.wire_count * vm_page_size`
    * `compressed_bytes = stats.compressor_page_count * vm_page_size`
    * `purgeable_bytes = stats.purgeable_count * vm_page_size`
    * `external_bytes = stats.external_page_count * vm_page_size`
  * Used memory formula:
    $$\text{Used} = \text{Active} + \text{Inactive} + \text{Speculative} + \text{Wired} + \text{Compressed} - \text{Purgeable} - \text{External}$$

### B. Memory Pressure (`kern.memorystatus_vm_pressure_level`)
* **Framework**: BSD `sysctlbyname`
* **Call**: `sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0)`
* **Values**:
  * `1`: Normal (Green)
  * `2`: Warning (Yellow)
  * `4`: Critical (Red)

### C. Swap Usage (`vm.swapusage`)
* **Call**: `sysctlbyname("vm.swapusage", &swap, &size, nil, 0)`
* **Data Structure**: `struct xsw_usage`:
  * `xsu_total`: Total swap disk allocation (bytes)
  * `xsu_used`: Used swap space (bytes)
  * `xsu_avail`: Free swap space (bytes)

---

## 3. Storage (Disk) Telemetry

### A. Mounted Volumes & Free Capacity
* **Framework**: `Foundation` & `CoreServices`
* **Call**: `FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])`
* Provides reliable used/free space across all APFS and external volumes without running shell commands.

### B. Real-Time Read/Write Throughput (IOKit)
* **Framework**: `IOKit.storage` & `DiskArbitration`
* **Mechanism**:
  1. Retrieve BSD disk device from volume mount URL via `DADiskCreateFromVolumePath`.
  2. Access the parent `IOMedia` entry via `DADiskCopyIOMedia`.
  3. Traverse IORegistry hierarchy to find the block storage driver.
  4. Query driver property `kIOBlockStorageDriverStatisticsKey`.
* **Output**:
  * `kIOBlockStorageDriverStatisticsBytesReadKey`: Cumulative bytes read.
  * `kIOBlockStorageDriverStatisticsBytesWrittenKey`: Cumulative bytes written.
  * Rate calculation:
    $$\text{Rate (bytes/s)} = \frac{\text{Bytes}_{t} - \text{Bytes}_{t-1}}{\Delta t}$$

---

## 4. Network Telemetry

### A. Network Interface Throughput (`sysctl` Routing Table)
* **Framework**: BSD Sockets & Routing Table (`<sys/sysctl.h>`, `<net/if.h>`)
* **Call**: `sysctl([CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, if_index])`
* **Mechanism**:
  * Does **not** invoke any shell tool.
  * Retrieves `if_msghdr2` message records directly from the kernel network stack.
  * Extracted fields:
    * `header2.ifm_data.ifi_ibytes`: Total inbound bytes.
    * `header2.ifm_data.ifi_obytes`: Total outbound bytes.
  * Compute upload/download rate:
    $$\text{Download Speed} = \frac{\text{ifi\_ibytes}_{t} - \text{ifi\_ibytes}_{t-1}}{\Delta t}$$

### B. Network State & Active Interface
* **Framework**: `SystemConfiguration`
* **Call**: `SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString)`
* Identifies primary physical network interface (e.g., `en0`).

---

## 5. Battery & Power Telemetry

### A. Power Sources Status
* **Framework**: `IOKit.ps` (`<IOKit/ps/IOPowerSources.h>`)
* **Calls**:
  * `IOPSCopyPowerSourcesInfo()`
  * `IOPSCopyPowerSourcesList()`
  * `IOPSGetPowerSourceDescription()`
* **Information Available**:
  * `kIOPSCurrentCapacityKey` / `kIOPSMaxCapacityKey` (Current percentage).
  * `kIOPSPowerSourceStateKey` ("AC Power" vs "Battery Power").
  * `kIOPSIsChargingKey` (Boolean charging state).
  * `kIOPSTimeToEmptyKey` / `kIOPSTimeToFullChargeKey`.

### B. Event-Driven Wakeups
* **Call**: `IOPSNotificationCreateRunLoopSource(callback, context)`
* Allows the app to sleep and only update power status when the OS broadcasts a power state event (charger connected, battery percentage step), resulting in 0% CPU usage while idle.

---

## 6. GPU & Thermal Sensors (Apple Silicon)

### A. Apple Silicon GPU Utilization
* **Framework**: `IOKit` (`IOAccelerator`)
* **Matching**: `IOServiceMatching(kIOAcceleratorClassName)`
* **Data**: `PerformanceStatistics` dictionary:
  * `"Device Utilization %"`: Overall graphics processor activity (0–100%).
  * `"Renderer Utilization %"`: 3D render pipeline activity.
  * `"Tiler Utilization %"`: Tiling pipeline activity.

### B. Apple Silicon Thermal Sensors (IOHID)
* **Framework**: `IOKit.hid` (`IOHIDEventSystemClient`)
* On Apple Silicon, SMC temperature keys are largely replaced or shadowed by HID event services:
  * Service created with `IOHIDEventSystemClientCreate(kCFAllocatorDefault)`.
  * Matching filter set to `PrimaryUsagePage = 0xff00` (Apple Vendor Page) and `PrimaryUsage = 5` (Thermal).
  * Temperature queried per sensor channel using `IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(type))`.
  * Provides per-core temperature readings for M-series SoCs without needing root privileges.
