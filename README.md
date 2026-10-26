# Specter

Specter is an ultra-lightweight macOS menu bar system telemetry cockpit built with Swift 6 and SwiftUI, tailored for Apple Silicon.

## Features

- **2-Column Desktop Cockpit**: High-frequency compute vitals on the left, unified process inspector on the right.
- **Direct Darwin Kernel Telemetry**: Queries Mach kernel host statistics, `libproc`, BSD sysctls, and IOKit in-process (< 1ms polling, zero child processes or external daemons).
- **Adaptive Two-Tier Polling**: 1s live sampling while the cockpit is open; drops to customizable background rates (1s–3s) when closed with process queries completely suspended.
- **Hardware Micro-Pills**: Glanceable storage and battery status directly in the header with rich hover tooltips.
- **Unified Process Inspector**: Filter between User Applications and System Daemons, sort by CPU or RAM, search in real-time, and safely terminate processes with 2-stage confirmation.
- **Native macOS Settings**: Configurable menu bar segments, refresh rate, temperature units, and startup preferences.

## Requirements

- macOS 14.0 or later (configured for macOS 26.0+)
- Swift 6.0 or later (included with Xcode)
- Apple Silicon Mac

## Build and Test

```sh
swift build
swift test
```

## Run

Run directly from the repository:

```sh
swift run Specter
```

To assemble, ad-hoc sign, and install into `/Applications`:

```sh
make install
```

Launch the installed app:

```sh
open /Applications/Specter.app
```

## License

Specter is released under the [MIT License](./LICENSE).
