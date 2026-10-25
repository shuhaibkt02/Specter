# 01: Project Foundation, Sandboxed Menu Bar Pill & Telemetry Seam

**What to build:** An executable macOS menu bar application that launches strictly within an offline App Sandbox, displays a unified status pill in the menu bar with tabular monospaced digits, and connects to a central telemetry coordinator via a high-level testable provider interface.

**Blocked by:** None (can start immediately)

**Status:** completed

- [x] Application compiles as a native macOS app targeting Apple Silicon macOS 14+
- [x] Entitlements enforce an offline App Sandbox without network client entitlements
- [x] Single menu bar status item renders cleanly beside the camera notch using monospaced digits
- [x] Central Telemetry Coordinator executes a master timer tick on a background thread
- [x] High-level Telemetry Provider seam is in place and verified by automated unit tests with synthetic data
