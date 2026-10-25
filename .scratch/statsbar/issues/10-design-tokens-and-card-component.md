# 10: Design Tokens & Reusable Card Component Architecture

**What to build:** Establish `DesignTokens.swift` defining the design system geometry (8pt grid, 320pt popover width, 10pt corner radii, 11/13/15pt typography scale, semantic colors) and unified `CardView` with standardized slots (title, live monospaced value, sparkline, breakdown, detail list) and track bar views.

**Blocked by:** 01 to 09 (Telemetry engine and models)

**Status:** completed

- [x] Create `Sources/StatsBar/Design/DesignTokens.swift` with typography, materials, spacing, and semantic colors
- [x] Create `Sources/StatsBar/Views/Components/CardView.swift` enforcing uniform 5-slot Gestalt grouping
- [x] Create `Sources/StatsBar/Views/Components/TrackBarView.swift` rendering total capacity track and filled usage
- [x] Refine `SparklineView.swift` to render smooth continuous 1pt path with latest-point highlight
- [x] Unit tests verifying design token constraints and card component data rendering
