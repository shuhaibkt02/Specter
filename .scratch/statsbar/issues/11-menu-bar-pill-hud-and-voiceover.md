# 11: Menu Bar Pill HUD & VoiceOver Accessibility

**What to build:** Build the high-legibility, zero-jitter, unified `MenuBarPillView` adhering to Doc 07: 22pt hit target, leading health status dot (dim at idle, bright on open), tabular monospaced digits, fixed segment widths, monochrome tint with Von Restorff warning exceptions (memory pressure, low battery), and full VoiceOver accessibility speech descriptions.

**Blocked by:** 10: Design Tokens & Reusable Card Component Architecture

**Status:** completed

- [x] Status dot indicating telemetry heartbeat / popover state
- [x] Strict fixed-width tabular monospaced layout preventing notch collisions and jitter
- [x] Subtle 1px dividers between segments
- [x] Color-as-exception: amber/red tint applied ONLY on memory pressure warning/critical or battery < 10%
- [x] Complete VoiceOver accessibility label reading unabbreviated metric speech strings
- [x] Unit tests testing VoiceOver string generation and warning state tint resolution
