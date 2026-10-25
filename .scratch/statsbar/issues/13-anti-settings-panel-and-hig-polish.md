# 13: 5-Control Anti-Settings Panel & macOS HIG Polish

**What to build:** Build the dedicated 5-control settings panel accessed via 24x24 gear icon, implement keyboard shortcuts (`⌘,` for settings, `⌘Q` to quit, `Escape` to close), ensure strict adherence to macOS HIG, and wire all components together in `StatsBarApp`.

**Blocked by:** 11: Menu Bar Pill HUD & VoiceOver Accessibility, 12: Popover Cockpit Cards & Interactive Hover Surfaces

**Status:** completed

- [x] Popover header with StatsBar title, gear icon (24×24 hit target), and close affordance
- [x] 5-control settings panel (menu bar segments, 1s/2s/3s interval, temperature unit, per-core toggle, launch at login)
- [x] Keyboard navigation and shortcuts (`⌘,`, `⌘Q`, `Escape`)
- [x] Visual polish: smooth materials, subtle 1px hairline borders (20% opacity), zero layout pop
- [x] End-to-end integration and verification tests
