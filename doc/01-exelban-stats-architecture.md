# 01. Exelban Stats Architecture Analysis

An in-depth structural review of the [exelban/stats](https://github.com/exelban/stats) macOS system monitor codebase.

---

## 1. High-Level Project Structure

The repository is divided into four main layers:

```
reference_stats/
├── Stats/              # App entry, AppDelegate, application lifecycle, main window/menu bar
├── Kit/                # Common core framework (Reader protocol, Store, DB, base widgets)
├── Modules/            # Discrete monitoring modules (CPU, RAM, Disk, Net, Battery, GPU, etc.)
└── SMC/                # System Management Controller reader & privileged helper tool daemon
```

---

## 2. Core Design Patterns

### The Module-Reader-Widget Pattern

`Stats` enforces strict separation of concerns across every hardware metric:

```
[ Hardware / Kernel ]
        │
        ▼ (Mach, IOKit, BSD sysctl)
  [ Reader<T> ] ───(Timer / RunLoop)───▶ Emits parsed struct T
        │
        ▼
   [ Module ] ─── Controls state, settings, and widget coordination
        │
 ┌──────┴──────────────┐
 ▼                     ▼
[ Menubar Widget ]    [ Popup Popover View ]
(Mini graph / text)   (Detailed breakdown & processes)
```

### 1. `Module` Protocol (`Kit/module/module.swift`)
Every feature (CPU, RAM, Battery, etc.) implements or subclasses `Module`:
* **Lifecycle**: `mount()`, `unmount()`, `terminate()`.
* **State**: `enabled`, `available`, `interval`.
* **UI Hosting**: Maintains an `NSStatusItem` in the macOS menu bar and a popup window (`NSPopover` or custom `NSWindow`).
* **Settings**: Exposes customizable preferences (e.g., color thresholds, widget styles, refresh frequency).

### 2. `Reader<T>` Base Class (`Kit/module/reader.swift`)
The base telemetry worker:
* Runs on a background `DispatchQueue`.
* Can be scheduled via a `Repeater` timer with customizable intervals (default: 1–5 seconds).
* Supports **dynamic idling**:
  * Certain readers (e.g., `ProcessReader` for top CPU/RAM processes) have `self.popup = true`, meaning they **pause** when the menu bar popover is closed and only run while the user is actively viewing details.
* Automatically records snapshots to `DB.shared` (LevelDB) on each reading tick.

### 3. `Widget` System (`Kit/Widgets/`)
Widgets are responsible for drawing into the menu bar's `NSStatusItem`:
* **Mini**: Compact two-line metric view (e.g., label + percentage).
* **LineChart**: Dynamic sparkline drawing historical data points using CoreGraphics (`NSBezierPath`).
* **BarChart**: Vertical/horizontal capacity bar.
* **Speed**: Formatted network/disk transfer rates (KB/s, MB/s).
* **Battery**: Custom battery glyph with fill level and charging lightning bolt.

---

## 3. Directory Breakdown

### `Stats/` (Application Lifecycle)
* **`AppDelegate.swift`**:
  * Main entry point (`@main`).
  * Instantiates the array of modules: `[CPU(), GPU(), RAM(), Disk(), Sensors(), Network(), Battery(), Bluetooth(), Clock(), Remote()]`.
  * Calls `module.mount()` to register each active module with `NSStatusBar.system`.
  * Handles sleep/wake notifications (`NSWorkspace.didWakeNotification`) to reset hardware listeners.
  * Manages global keyboard monitors and update checkers.

### `Kit/` (Shared Core Engine)
* **`plugins/Store.swift`**: Thread-safe wrapper around `UserDefaults.standard` with an in-memory dictionary cache to reduce disk reads.
* **`plugins/DB.swift`**: Bridge to LevelDB (`libleveldb.a`) storing timeseries telemetry data.
* **`module/popup.swift`**: Container view displayed when clicking a status item, handling tab views, headers, and process tables.
* **`helpers.swift` & `process.swift`**: Utility routines for running external processes, formatting bytes/temperatures, and parsing regexes.

### `Modules/` (The Metrics Layer)
Each folder in `Modules/` is a self-contained feature containing:
* `main.swift`: The module entry point coordinating readers, settings, and widgets.
* `readers.swift`: Low-level data querying logic.
* `widget.swift`: Menu bar rendering code.
* `popup.swift`: Expanded detail view shown when clicked.
* `settings.swift`: User preferences panel for that specific metric.
* `notifications.swift`: System notification alerts when user-defined thresholds (e.g. CPU > 90% for 60s) are met.

### `SMC/` (Hardware Controller)
* `smc.swift`: Swift wrapper around `AppleSMC` IOKit service. Reads SMC keys (`FourCharCode`) for fan speeds, voltages, and thermal states.
* `Helper/`: Privileged XPC daemon installed to `/Library/PrivilegedHelperTools` to allow writing fan speed overrides.
