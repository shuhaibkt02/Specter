# StatsBar

StatsBar is a lightweight macOS menu bar system monitor built with Swift and
SwiftUI.

## Requirements

- macOS 26.0 or later
- Swift 6.0 or later (included with Xcode)

## Build and test

```sh
swift build
swift test
```

## Run

Run from the repository with:

```sh
swift run StatsBar
```

To assemble and install a release app bundle in `/Applications`:

```sh
make install
```

The installer builds a release binary, creates an ad-hoc-signed `StatsBar.app`,
and copies it to `/Applications/StatsBar.app`. Launch it with:

```sh
open /Applications/StatsBar.app
```

## License

StatsBar is released under the [MIT License](./LICENSE).
