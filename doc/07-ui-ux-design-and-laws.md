# 07. UI/UX Design Direction & Applied Cognitive Laws

*Acting as Staff Product Designer. This document establishes the complete product, visual, and interaction design specification for StatsBar, translating low-level engineering constraints (Docs 01–06) into disciplined UX heuristics and concrete design contracts.*

---

## Part 1: Clean Design Direction for StatsBar

---

### 1. The Design Thesis

> **A system monitor should be the quietest thing on your screen, until you ask it a question.**

Every existing monitor (Stats included) fails this test. They shout: six icons, twitching numbers, colored badges, a settings window with 200 toggles. The product opportunity here is not "more metrics" — it's **restraint as a feature**. The engineering docs already commit to <0.1% idle CPU and zero disk writes; the design must be equally disciplined. **The UI is the visible proof of the engineering.**

Three design principles fall out of this:

1. **Silence by default.** The menu bar pill shows the minimum viable truth. Detail is a deliberate act of inquiry, never an ambient broadcast.
2. **Stability is legibility.** Numbers must never move their own position. If the user's eye catches motion in the menu bar, we've failed.
3. **The popover is a cockpit, not a dashboard.** A dashboard shows everything; a cockpit shows what you need to act on, grouped by the decision you're making.

---

### 2. Information Architecture

#### 2.1 The Menu Bar Pill (the entire idle experience)

One `NSStatusItem`. One pill. Fixed width per segment. This is the whole product 99.9% of the time.

```
┌──────────────────────────────┐
│  ● CPU 12%  ⬡ 6.4G  ⇅ 1.2M  │
└──────────────────────────────┘
```

**Design rules:**

- **Segment order is fixed and user-reorderable, never auto-reordering.** Predictability beats "smart" ordering.
- **Three segments max visible by default** (CPU, Memory, Network). Disk and Battery live in the popover unless explicitly pinned. This is the notch-defense rule — three short segments fit beside any notch on a 14"/16" MacBook.
- **Each segment has a fixed minimum width** derived from its widest realistic value string. The layout engine reserves it. Numbers change; geometry does not. This is the single biggest fix vs. Stats.
- **No color in idle state.** The pill renders in the system's monochrome menu bar tint (template image / `.primary`). Color is reserved for *warnings only* — a memory-pressure critical state or a battery below 10% is the only time a segment tints (amber/red). Color as exception, not decoration.
- **Units are abbreviated and stable:** `12%`, `6.4G`, `1.2M`, `↓1.2M ↑340K`. Never `1.2 MB/s` in the pill — that string's width changes with the unit. Units are fixed per segment.
- **The status glyph is a dot, not an icon set.** A single 6pt leading dot indicates health (dim = idle, bright = popover open). No rotating fan icons, no battery glyphs in the bar.

**Accessibility:** pill text is `.monospacedDigit()`, minimum 11pt, honors Increase Contrast and Reduce Transparency. When VoiceOver focuses the item, it reads the full values, not the abbreviations.

#### 2.2 The Popover (the inquiry experience)

One popover, **five cards, fixed order**, vertical scroll on small screens. No tabs. Tabs hide information and force a click to discover; a single scrollable cockpit lets the eye scan.

```
┌─────────────────────────────────────────┐
│  StatsBar                     ⚙  ✕      │  ← header: name, settings, close
├─────────────────────────────────────────┤
│  CPU                                     │  ← card: title + live value
│  ▁▂▃▅▆▇▆▅▃▂▁▂▃▅ 32%                    │  ← sparkline (60s, in-RAM)
│  P-cores  ████░░░░  38%                  │  ← per-core bars (Tier 2 only)
│  E-cores  ██░░░░░░  21%                  │
│  ── Top processes ──                     │
│  Safari            18.2%                 │
│  Xcode             9.4%                  │
├─────────────────────────────────────────┤
│  Memory          6.4 / 16 GB   ● Normal │
│  ▁▂▃▃▄▅▅▆▆▅▄▃▃▂▂                       │
│  Wired 1.2G · Active 3.1G · Cached 2.1G  │
│  Swap 0 B                                │
├─────────────────────────────────────────┤
│  Network              ↓ 1.2M  ↑ 340K    │
│  ▁▁▂▁▃▂▁▁▂▄▂▁▁▂                        │
│  en0 · 192.168.1.42                      │
├─────────────────────────────────────────┤
│  Disk                 412 / 994 GB  ▓▓▓░ │
│  Read 12 M/s · Write 3 M/s               │
├─────────────────────────────────────────┤
│  Battery                 87% · Charging  │
│  ▁▂▃▄▅▆▇█ (health 94%) · 1h 12m to full │
└─────────────────────────────────────────┘
```

**Design rules:**

- **Card = one question.** CPU card answers "what's eating my CPU?" Memory card answers "am I out of RAM?" Each card has: title, live value (right-aligned, monospaced), one sparkline, one breakdown line, one "top 5" list. Nothing else.
- **Sparklines are 60 seconds, 1px stroke, no fill, no gridlines, no axis labels.** They communicate *shape*, not values. The number beside them communicates value. Two visual channels, one job each.
- **Per-core and top-process lists are Tier 2 only.** They appear/disappear based on popover state — but visually they should *fade in* (150ms) on open, so the layout doesn't pop. Reserve their height in the card layout even when collapsed (skeleton), so the popover never reflows on open.
- **Top process lists are 5 rows, no scroll, no PID column in the default view.** Name (truncated with ellipsis) + value. PID and full path appear on hover tooltip. Action (quit process) is a hover-revealed `✕` — destructive actions must never be one accidental click away.
- **No tabs, no accordions, no nested menus.** If a metric doesn't fit in a card, it doesn't belong in the popover. This is the anti-bloat contract.

#### 2.3 Settings (the anti-settings)

The Stats settings window is the archetype of feature-bloat-as-settings. Our settings surface should be **one panel, under 10 controls**, reached from the popover's gear icon:

| Control | Type | Default |
|---|---|---|
| Menu bar segments | reorderable checkbox list (CPU, Mem, Net, Disk, Battery) | CPU, Mem, Net |
| Sampling interval | segmented: 1s / 2s / 3s | 2s |
| Temperature unit | °C / °F | °C |
| Launch at login | toggle | on |
| Show per-core breakdown | toggle (Tier 2 only, always) | on |

That's it. No color pickers, no per-widget styles, no notification thresholds (v1). Every omitted setting is a design decision we make *for* the user — a clean product is opinionated. When a user asks for a setting, the answer is usually "our default was wrong," not "add a toggle."

---

### 3. Visual Language

#### 3.1 Type & numerics

- **SF Pro Text** for labels, **SF Mono / SF Pro `.monospacedDigit()`** for every number. Non-negotiable. This is the jitter fix.
- Scale: 11pt pill, 13pt card body, 15pt card values (semibold), 11pt captions. Three sizes, that's it.
- **Right-align all numeric columns.** Humans compare right-aligned numbers; left-aligned numeric columns are a known legibility sin.

#### 3.2 Color

- **One accent color, system-derived** (`.accentColor`), used only for sparklines and active-state highlights.
- **Semantic colors reserved:** green = normal/healthy, amber = warning, red = critical. These appear only when the state *is* that state — never as a "theme."
- **No gradients, no shadows on cards, no colored backgrounds.** Cards are defined by a 1px separator and generous padding, exactly like native macOS System Settings groups.
- Dark mode: cards use `.background(.regularMaterial)` over the desktop; light mode: `.background(.thickMaterial)`. Materials make the popover feel native and translucent without blurring legibility.

#### 3.3 Spacing & geometry

- **8pt grid.** Card padding 16pt, inter-card gap 12pt, popover width fixed at **320pt**, max height 560pt (scrolls beyond). Fixed width is a design commitment: the popover never resizes as content changes, so the eye never has to re-anchor.
- **Corner radius 10pt** on cards (matches macOS 14+ grouped-content idiom), 8pt on the popover. No pill-shaped cards.
- **1px hairline separators** at 20% opacity, matching `NSBox` separators in native apps.

#### 3.4 Iconography

- **No custom icon set.** Use SF Symbols for settings, close, warning, and the process-quit affordance. Custom glyphs (battery, network arrows) are drawn as 1pt-stroke template shapes that inherit menu bar tint.
- The app icon: a single monospaced `%` glyph on a rounded-rect, monochrome, adaptive to dark/light. Recognizable at 16×16. If it doesn't read at 16pt, it's wrong.

---

### 4. Motion & Interaction

- **Popover open: 120ms scale-fade from the menu bar item** (native `NSPopover` behavior). No custom animation — native feels correct.
- **Sparkline updates: crossfade the newest point only**, 200ms. Never animate the whole line — a sweeping line graph is visually noisy and implies motion that isn't happening.
- **Tier-1 → Tier-2 transition:** values and sparklines are already present; only the per-core bars and process lists fade in (150ms, ease-out). The popover never "loads."
- **Hover states:** rows highlight with `.selection` at 8% opacity; the quit-process affordance appears on row hover with a 100ms fade. No bounce, no spring, no scale.
- **Escape and click-outside dismiss**, as native. No "pin" button, no "keep open" toggle — that's a settings-shaped solution to an interaction problem.

---

### 5. The Anti-Patterns We Explicitly Reject (from the audit)

| Stats flaw (doc 05) | Our design answer |
|---|---|
| 6+ menu bar icons crowding the notch | One pill, three segments default, notch-safe width budget |
| Horizontal jitter from proportional fonts | Monospaced tabular digits + reserved fixed segment widths |
| 200-toggle settings window | 5-control single panel, opinionated defaults |
| NotificationCenter widget loops | No WidgetKit extension, no app extensions |
| Color as decoration | Color only as semantic exception (warning/critical) |
| Dense tabbed popover | Single scrollable cockpit, five cards, fixed order |
| Destructive actions in one click | Hover-revealed quit with confirmation on the process row |
| "Remote" cloud sync UI surfaces | No network UI exists at all — nothing to display |

---

### 6. Handoff Checklist for Engineering

To make this design *implementable* against the SPEC and docs:

1. **Design tokens as a single Swift file** (`DesignTokens.swift`): spacing (4/8/12/16/24), radii (8/10), type scale (11/13/15), one accent, three semantic colors, materials. No magic numbers in views.
2. **Segment width reservation** computed at launch from localized worst-case strings, stored per-segment, never recomputed per tick. This is the jitter contract.
3. **`CardView` component** with fixed slots: title, value, sparkline, breakdown, list. Cards compose from slots; no card invents its own layout.
4. **`SparklineView`** takes `[Float]` from the `RingBuffer`, renders with a single `Path`, no per-point views, no animation on data change except newest-point crossfade.
5. **Popover height reservation** for Tier-2 content so the popover never reflows on open — render skeleton rows at 0 opacity and fade to 1.
6. **VoiceOver labels** on the pill composed from segment values, and on every card (title + value + pressure state). Accessibility is a design deliverable, not a QA pass.
7. **Localization-ready strings** with reserved-width accounting for longer locales (German `Speicher`, French `Réseau`) — the pill width budget must be tested against the three longest supported locales.

---

### 7. The One-Sentence Design Brief

**StatsBar is a single, monospaced, monochrome pill that says three true things at rest, and unfolds — only when asked — into five calm cards that each answer exactly one question, with zero motion, zero color decoration, and zero settings to configure.**

---
---

## Part 2: UI/UX Laws Applied to StatsBar

*Staff-level treatment. Laws are heuristics, not commandments — and the mark of a senior designer is knowing which laws conflict, which are inapplicable, and how to resolve the tension. So this document applies every relevant law, flags the ones that don't apply, and resolves the conflicts explicitly.*

---

### 0. The Meta-Rule

Every UX law below is a **trade-off lens**, not a checklist item. Two laws will often pull in opposite directions (e.g., Hick's Law wants fewer options; Fitts's Law wants bigger targets). The job isn't to satisfy all laws — it's to **choose the conflict resolution and defend it.** That resolution is stated in Section 9.

---

### 1. Perception & Gestalt (how the eye groups and parses)

#### Law of Proximity
Elements near each other are perceived as related.
- **StatsBar rule:** Everything belonging to one metric lives inside one card, bounded by generous internal padding (16pt) and a clear inter-card gap (12pt). The gap between cards must be **visibly larger** than the gap between elements within a card — otherwise CPU and Memory visually merge.
- **Concrete:** inter-card gap ≥ 1.5× intra-card gap.

#### Law of Common Region
Elements sharing a bounded area are perceived as a group.
- **StatsBar rule:** This is why the popover uses **card containers with a 1px separator and material background** rather than raw text blocks. The card boundary *is* the grouping affordance. Without it, five metrics would read as one dense paragraph.
- **Rejected alternative:** a flat list with dividers only. Dividers group nothing; containers group definitively.

#### Law of Similarity
Elements sharing visual traits are perceived as functionally similar.
- **StatsBar rule:** Every card must use the *identical* slot layout: title → value (right-aligned, monospaced) → sparkline → breakdown → list. If one card invents a different arrangement, the user's eye must re-learn the scan pattern for that card. Uniformity here is legibility, not laziness.

#### Law of Continuity
The eye follows lines and continuous paths.
- **StatsBar rule:** Sparklines are single continuous 1pt paths, no gaps, no dots except the newest point. A discontinuous line reads as "broken data," which erodes trust in the telemetry itself.

#### Law of Closure
The mind completes incomplete shapes.
- **StatsBar rule:** Per-core bars use a filled-track-within-outline pattern (`████░░░░`), so the eye reads the *total* 8-slot capacity even when the value is 3/8. Without the empty track, the user can't judge proportion — they only see an unanchored filled bar.

#### Law of Figure-Ground
The eye separates a focal object from its background.
- **StatsBar rule:** The popover uses `.regularMaterial`/`.thickMaterial`, so the card content is figure and the desktop is ground. Never a fully opaque background — that destroys the figure-ground relationship and makes the popover feel like a modal window rather than a floating accessory. Native macOS idiom is transparency.

#### Law of Prägnanz (Simplicity)
The eye interprets ambiguous images in the simplest form possible.
- **StatsBar rule:** No decorative elements — no gradients, no shadows on cards, no icons beside every label, no background colors. Every added glyph forces the eye to interpret it. The simplest form of a card is: text + number + line. That's what we ship.

#### Law of Uniform Connectedness
Elements connected by a visual line/shape are perceived as strongly related than by proximity alone.
- **StatsBar rule:** The menu bar **pill** is a single connected shape — not three separate text runs floating in the menu bar. The pill's unified outline makes the three segments read as one product, not three separate monitors.

---

### 2. Memory & Cognition

#### Miller's Law (7 ± 2)
Working memory holds ~7 chunks.
- **StatsBar rule:** The menu bar shows **3 segments max by default** — well within the chunk budget, and the popover has **5 cards**, each with **one primary question**. We stay under 7 not because the user can't hold 7, but because *at-a-glance* parsing has a much smaller budget than focused reading. The menu bar is glanced at, not read.
- **Concrete:** 3 pill segments, 5 popover cards, 5 process rows. Never 7+ of anything in one viewport.

#### Recognition over Recall
Users should not have to remember information across contexts.
- **StatsBar rule:** Every metric in the popover shows **value + unit + state in the same card**. The pill shows `6.4G`; the popover shows `6.4 / 16 GB · Normal`. The user never has to remember "what does 6.4G mean in context" — the context is always adjacent.
- **Concrete:** the memory-pressure color dot is always paired with a text label (`● Normal`), never color alone. Color alone forces recall of the color mapping.

#### Serial Position Effect (Primacy & Recency)
People remember the first and last items in a list best.
- **StatsBar rule:** The pill's **first segment is CPU** (the most-glanced metric — primacy), and the **last segment is Network** (the second-most-glanced — recency). Memory sits in the middle where it's least urgent. This ordering is deliberate, not alphabetical.
- **Popover:** first card = CPU (top of scan), last card = Battery (least urgent, but remembered). Settings icon is at the far right of the header (recency anchor for "where do I configure this").

#### Zeigarnik Effect
Incomplete tasks are remembered better than completed ones.
- **StatsBar rule:** **Inapplicable by design.** A system monitor has no tasks to complete — every card is a live read-only snapshot. We do *not* introduce progress bars, "checked" states, or task-like affordances. Forcing Zeigarnik into a telemetry app would be manipulative gamification.

#### Peak-End Rule
People judge an experience by its peak and its end, not the average.
- **StatsBar rule:** The popover's **close moment is the peak.** The fade-out is instant (native `NSPopover`), no confirmation, no "are you sure," no summary flash. The *end* must be frictionless — this is why we don't animate the close. A smooth open is good; a zero-friction close is what users remember.

---

### 3. Decision & Action

#### Hick's Law
Decision time grows with the number of choices.
- **StatsBar rule:** This is the single most important law for our **anti-settings** philosophy. Five settings controls, not fifty. Every additional toggle is a Hick's-law tax on every user who ever opens Settings.
- **Concrete:** if a setting isn't in the 5-control panel (Section 2.3 of the prior brief), it doesn't ship. The "correct" default is the design decision; the toggle is a failure to make it.
- **Popover:** five cards, no tabs, no accordions — the user makes **zero navigation decisions**. The eye scans top-to-bottom. Tabs would multiply choices by the tab count.

#### Fitts's Law
Acquisition time depends on target size and distance.
- **StatsBar rule:** The menu bar pill is a **tall, wide hit target** — the entire pill rect is clickable, not just the text glyphs. Minimum 22pt height. The close `✕` is 24×24pt minimum (not a 10pt glyph). The process-quit `✕` on hover is 20×20pt.
- **Concrete:** no hit target under 20×20pt. This is why we rejected inline `✕` icons at 10pt — precise clicking is a Fitts's-law cost the user shouldn't pay for a destructive action.
- **Popover settings gear:** 24pt, top-right corner (short distance from the natural click origin at the popover top).

#### Von Restorff Effect (Isolation Effect)
The item that stands out is remembered.
- **StatsBar rule:** This is the **entire color strategy.** Because the popover is monochrome by default, *one* red memory-pressure dot or *one* amber battery segment becomes unmissable. If we colored everything, nothing would stand out. Von Restorff is why color-as-exception works and color-as-decoration fails.
- **Concrete:** maximum **one** semantic color visible at a time. If two warnings fire simultaneously, that's a legitimately bad state — but even then, the two dots share the same hue family so they read as "one warning system," not two competing signals.

#### Goal-Gradient Effect
Effort accelerates near a goal.
- **StatsBar rule:** **N/A.** No goals, no progress, no targets. A monitor doesn't have a "you're 80% done" state. Introducing goal-like visuals (e.g., "CPU target 50%") would violate the read-only, non-judgmental telemetry contract.

#### Parkinson's Law
Work expands to fill the time available.
- **StatsBar rule:** Inapplicable to the *user*, but decisive for the *engineer*: the popover's fixed 320pt width is the "time budget." Cards must fit their slots — they cannot grow to consume extra space. The fixed width is the design constraint that prevents card bloat.

---

### 4. Time & Feedback

#### Doherty Threshold (<400ms)
Productivity soars when system response feels instantaneous.
- **StatsBar rule:** Popover **must open in <100ms** (native `NSPopover` — zero custom work). Tier-2 content (process lists, per-core bars) must render within the **same frame** as the popover, using **reserved skeleton space** that fades in, so the user never sees a "loading" state. If Tier-2 data takes 200ms to fetch, the skeleton occupies the space at 0 opacity and fades to 1 — the popover is *never* seen empty.
- **Concrete:** no spinner, no shimmer, no "Loading…" text. Ever. Skeleton-or-nothing.

#### Aesthetic-Usability Effect
Users perceive attractive design as more usable, and forgive minor flaws.
- **StatsBar rule:** This is a real effect, not a license to ship broken UX. Our aesthetic (monochrome pill, native materials, monospaced digits) *must* be backed by actual correctness — the sparkline must reflect real data, the pressure dot must reflect real pressure. Attractiveness buys **trust**; the engineering docs (zero disk writes, no network, no root daemon) are what **earns** it. Aesthetic-Usability is the *surface*; the SPEC is the *substance*.

#### Feedback (Nielsen #1)
Every action must produce a visible response.
- **StatsBar rule:** 
  - Click pill → popover opens (visible).
  - Hover row → selection highlight (visible, 100ms).
  - Hover process row → quit `✕` appears (visible, 100ms).
  - Change setting → immediate visual update in pill/popover (no "save" button, no restart).
  - **The ticking numbers themselves are feedback** — every 2s, values update. That *is* the system's heartbeat. If the app hangs, the user sees it freeze. This is honest feedback.

---

### 5. Complexity & Structure

#### Tesler's Law (Conservation of Complexity)
Every system has irreducible complexity; you can only move it, not destroy it.
- **StatsBar rule:** This is the **strategic backbone** of the whole design. Our complexity budget:
  - **Moved to engineering:** zero subprocesses, zero disk writes, no root daemon, no network — the *hard* complexity is absorbed by C/Mach/IOKit code, invisible to the user.
  - **Moved to defaults:** 5 opinionated settings, not 50. Complexity absorbed by our decisions.
  - **Moved to the popover:** the menu bar pill absorbs *nothing* complex. Detail lives one click away.
  - **Surface complexity remaining for the user:** ~zero. This is the point.

#### Progressive Disclosure
Show only what's needed now; reveal more on demand.
- **StatsBar rule:** This *is* the Tier-1 / Tier-2 architecture, expressed as UX:
  - **Tier 1** (menu bar, always visible): 3 aggregate numbers.
  - **Tier 2** (popover open): per-core breakdown, top processes, disk detail, battery health.
  - **Tier 3** (hover / tooltip): full process path, PID, precise byte counts.
  - Each tier gates the next. The user never sees Tier 3 without first asking for Tier 2.

#### Pareto Principle (80/20)
80% of value comes from 20% of features.
- **StatsBar rule:** 80% of monitoring value is **CPU + Memory + Network in the pill**, and **top-process lists** in the popover. We optimize these to sub-millisecond cost and pixel-perfect legibility. Disk, Battery, Thermals, GPU are present but **deliberately secondary** — correct, but not where we spend design effort. This is why Battery is the *last* card, not the first.

#### Occam's Razor
Prefer the simplest explanation/solution.
- **StatsBar rule:** If two designs achieve the same goal, ship the one with fewer elements. Concrete applications:
  - One pill vs. 6 icons.
  - Five cards vs. tabbed interface.
  - Monospaced digits vs. custom animated number rollers (we **rejected** number-rolling animations — they're not simpler, they're flashier).
  - Native `NSPopover` vs. custom floating window (rejected — more code, more bugs, less native).

#### KISS
Keep it simple.
- **StatsBar rule:** The settings panel has **5 controls**. If a proposed feature would add a 6th control, it must displace one of the existing 5 — otherwise it doesn't ship. The fixed budget is enforcement, not aspiration.

---

### 6. Platform & Convention

#### Jakob's Law
Users spend most of their time on *other* apps; they expect yours to work like those.
- **StatsBar rule:** **This is the most load-bearing law for StatsBar.** Every native macOS convention we violate is a tax on every user who ever used any other Mac app:
  - Popover dismisses on click-outside and Escape (native).
  - Settings reached from a gear icon (native).
  - Materials, not opaque backgrounds (native).
  - Template rendering follows menu bar tint, dark/light (native).
  - Keyboard shortcuts: `⌘,` for settings (native), `⌘Q` to quit (native).
  - No custom window chrome, no custom scroll physics, no custom tooltip.
- **Concrete:** if the design deviates from a macOS HIG convention, the deviation must be **justified in one sentence**. Otherwise, we follow the platform.

#### Principle of Least Astonishment
The system should behave the way the user expects.
- **StatsBar rule:** 
  - The pill **never reorders segments** on its own. If the user enabled Network second, Network stays second — even if CPU traffic suddenly spikes. Auto-reordering by "importance" is a classic astonishment trap (Stats does this).
  - Numbers **update in place**, never flash or reposition.
  - The popover **opens from the pill**, not from a random screen corner.
  - Quitting a process via the popover **confirms once** (destructive action guard), then exits the row — no delayed undo flash, which would astonish.

#### Fitts's Law (revisited under conventions)
- Covered in Section 3. Cross-reference: native menu bar item heights, native popover arrow anchoring to the pill, native safe-area for the notch.

---

### 7. Nielsen's 10 Heuristics — Explicit Mapping

| # | Heuristic | StatsBar application |
|---|---|---|
| 1 | **Visibility of system status** | Live ticking numbers; pressure color + text label; charging state text; popover open/closed state. |
| 2 | **Match between system and real world** | "Used / 16 GB", "Charging", "to full" — plain language, not "MEM_PRESSURE_LVL=2". Units use `KB/MB/GB` (user-meaningful), never raw bytes. |
| 3 | **User control and freedom** | Escape closes popover; click-outside dismisses; **no forced state**. Process-quit requires confirmation. No auto-reordering of pill segments. |
| 4 | **Consistency and standards** | Identical card slot layout; macOS HIG conventions; monospaced numerics; SF Symbols for standard affordances. |
| 5 | **Error prevention** | Destructive quit is hover-revealed + confirmed. No "apply" without cancel. Sandbox means **there is no network error state** — the error class is designed out, not handled. |
| 6 | **Recognition rather than recall** | Value + unit + state always co-located. Color never alone (always with a text label). Segment order fixed and memorable. |
| 7 | **Flexibility and efficiency of use** | Tier-1 fast glance for everyone; Tier-2 deep detail for power users. `⌘,` opens settings. No hidden power-user modes that break the beginner mental model. |
| 8 | **Aesthetic and minimalist design** | The entire prior brief. Monochrome by default, color as exception, no decorative chrome. |
| 9 | **Help users recognize, diagnose, recover from errors** | Errors are **designed out**, not recovered from. No network → no network errors. No root → no privilege errors. The only recoverable state is "a process is hung" → hover + quit + confirm. |
| 10 | **Help and documentation** | **N/A in-app by design.** A 5-control settings panel and a 5-card popover need no onboarding. The absence of help is a design result, not a gap. A single README on the repo is the entire documentation surface. |

#### Postel's Law (Robustness Principle — as applied to UI)
"Be conservative in what you send, liberal in what you accept."
- **StatsBar rule (UI reading):** Accept any reasonable user input **without negotiating**: click-anywhere on the pill opens the popover (not just the dot); any scroll position in the popover works; any modifier-click on a process row does the obvious thing. Be conservative in what we *show*: only validated, real telemetry, never a stale-value placeholder that could mislead. Honest numbers or nothing.

---

### 8. Laws That Argue *Against* StatsBar's Restraint — Steel-Manned

A senior designer steel-mans the opposition before shipping. Three laws could be read as demanding *more*, not less:

| Law | The argument *for* more UI | Our rebuttal |
|---|---|---|
| **Aesthetic-Usability Effect** | "Rich visuals build trust; a bare pill looks unfinished." | Trust comes from *honesty and responsiveness*, not visual density. A monochrome pill that updates exactly every 2s, with a popover that opens in <100ms and never shows a spinner, signals confidence. Density signals uncertainty. |
| **Peak-End Rule** | "Make the popover close with a satisfying flourish to anchor the memory." | The *end* of a glance is "return to work." A flourish is friction. Zero-friction close is the highest-peak end. Native `NSPopover` close is already instant. |
| **Doherty Threshold** | "Animate values so the user perceives responsiveness." | Animating numbers *slows* perceived responsiveness and *destroys* layout stability (our jitter contract). Data updates should be *seen*, not *watched*. Crossfade only the newest sparkline point, 200ms, and nothing else. |

And three laws we deliberately **do not** apply because they'd violate the product's read-only contract:

- **Goal-Gradient Effect** — no goals.
- **Zeigarnik Effect** — no tasks.
- **Parkinson's Law (user-facing)** — no deadlines.

Applying them would gamify telemetry, which is a category error: the user isn't *doing* anything, they're *observing* something.

---

### 9. The Conflict Resolution Matrix

When laws collide, the winner is stated up front so engineering and design don't relitigate per-screen:

| Conflict | Resolution | Why |
|---|---|---|
| **Hick's Law** (fewer choices) vs. **Flexibility** (power-user options) | **Hick wins in the default path; Flexibility lives only behind a hover or a single settings control.** | The median user never needs the extra options; the power user pays a small discovery cost, not a permanent cognitive tax on everyone. |
| **Fitts's Law** (bigger targets) vs. **Minimalist density** (more content per screen) | **Fitts wins for interactive elements; minimalism wins for read-only content.** | Buttons must be big; data must be compact. They're orthogonal — no real conflict once separated. |
| **Aesthetic-Usability** (rich visuals) vs. **Von Restorff** (color must be rare to mean anything) | **Von Restorff wins.** Monochrome default; color reserved for warning/critical. | Aesthetic-Usability is served by *typography, spacing, and material*, not by color. We get both. |
| **Progressive Disclosure** (hide complexity) vs. **Recognition over Recall** (show context) | **Disclosure wins for *interaction surfaces*; recognition wins for *data context*.** | Hide per-core breakdown until asked (disclosure); but when shown, always show the full context (recognition). The user asks once; the system answers completely. |
| **Jakob's Law** (follow platform convention) vs. **Least Astonishment** (do what the user *expects* even if unconventional) | **They agree in practice for StatsBar.** | macOS conventions *are* what users expect. We have no legitimate case for custom chrome, so the conflict is moot. |
| **Miller's Law** (3–5 chunks) vs. **Pareto** (the 20% that matters includes 6 metrics) | **Miller wins in the pill (3 segments); Pareto wins in the popover (5 cards).** | The pill is glanced (tiny budget). The popover is read (larger budget). Different modes, different chunk limits. |
| **Tesler's Law** (complexity is conserved) vs. **KISS** (keep it simple) | **Tesler wins strategically; KISS wins tactically.** | We *move* complexity into engineering (Tesler); we don't *add* it to the UI (KISS). They're two views of the same strategy. |

**The tiebreaker, always:** *"Does this decision make the pill quieter, or the popover clearer?"* If neither, it doesn't ship.

---

### 10. Consolidated Design-Law Checklist for Handoff

Give this to engineering. If a build violates a line, it's a design bug, not a polish item.

#### Perception
- [ ] Inter-card gap ≥ 1.5× intra-card gap *(Proximity)*
- [ ] Every card uses the identical 5-slot layout *(Similarity)*
- [ ] Sparklines are single continuous paths, newest point highlighted only *(Continuity)*
- [ ] Progress bars show the empty track, not just the fill *(Closure)*
- [ ] Popover uses material, never opaque *(Figure-Ground)*
- [ ] The pill is one connected shape, not separate text runs *(Uniform Connectedness)*

#### Cognition
- [ ] 3 pill segments max default; 5 cards; 5 process rows *(Miller)*
- [ ] Every value paired with unit + state; color never alone *(Recognition)*
- [ ] Pill order CPU → Mem → Net; popover order CPU first, Battery last *(Serial Position)*
- [ ] Popover close is instant, no confirmation *(Peak-End)*

#### Action
- [ ] ≤5 settings controls; adding a 6th displaces one *(Hick)*
- [ ] All hit targets ≥ 20×20pt; pill rect fully clickable; `✕` ≥ 24pt *(Fitts)*
- [ ] ≤1 semantic color visible at a time *(Von Restorff)*
- [ ] No goals, progress bars, or "task" affordances *(Zeigarnik/Goal-Gradient — deliberately excluded)*

#### Time
- [ ] Popover opens <100ms; Tier-2 content uses reserved skeletons, never spinners *(Doherty)*
- [ ] Numbers update in place with zero layout shift *(Doherty + Least Astonishment)*
- [ ] Every interaction produces visible feedback within 100ms *(Nielsen #1)*

#### Structure
- [ ] Complexity lives in C/Mach code or in defaults — never in the UI *(Tesler)*
- [ ] Tier 1 / Tier 2 / Tier 3 gating is enforced *(Progressive Disclosure)*
- [ ] CPU/Mem/Net optimized first; Disk/Battery correct but secondary *(Pareto)*
- [ ] If two designs tie, ship the one with fewer elements *(Occam)*

#### Convention
- [ ] Escape dismisses; click-outside dismisses; `⌘,` opens settings; `⌘Q` quits *(Jakob)*
- [ ] Pill segments never auto-reorder; numbers never flash *(Least Astonishment)*
- [ ] All 10 Nielsen heuristics pass, with #5 and #9 satisfied by *designing errors out* *(Nielsen)*
- [ ] Every deviation from macOS HIG justified in one written sentence *(Jakob — enforcement)*

**The one-line gate:** *Every element either keeps the pill quiet or makes the popover clearer. Anything that does neither is not StatsBar.*
