# App Store Screenshots — yaht

## Requirements
- New apps need the **6.9" iPhone** set (1290×2796 or **1320×2868**). Your device captures are
  1320×2868 → already valid; a single 6.9" set covers all modern iPhones.
- Up to 10 per set; ship **5–6**. First 2–3 are what most people see in search — make them count.
- Always dark, so screenshots look native to the app (no light-mode surprises).

## Framing
Two options:
1. **Raw device screenshots** (allowed) — fastest, but no captions = weaker conversion.
2. **Framed with a caption band** (recommended) — put each screenshot on the Cyberdream background
   (`#12141A`) with one short headline above it. Keep the band identical across all shots (same type,
   same position) so the set reads as one system. Headline = display face, sentence case, ~28–36pt.

Captions are copy, not decoration: each says what the screen does, in the app's voice.

## The set (order matters — best first)

| # | Screen | Source | Caption |
|---|--------|--------|---------|
| 1 | Home: global grid + habit list | `IMG_6607` | **Every habit, one quiet grid** |
| 2 | Habit detail: streaks + activity | `IMG_6606` | **Watch your days fill in** |
| 3 | New habit sheet | `IMG_6605` | **Track anything — yes/no or count** |
| 4 | A **count** habit (e.g. water 5/8) | *capture needed* | **Tally it. Eight glasses, thirty pushups.** |
| 5 | Schedule + reminders expanded | *capture needed* | **Reminders that respect you** |
| 6 | Empty state (optional closer) | `IMG_6608` | **yet another habit tracker** |

> Sub-captions (optional, smaller line under the headline) can add a concrete detail, e.g. under #2:
> "Current streak, best streak, and every day since you started."

## Captures still needed (on device/simulator)
- **Count habit** mid-progress (create a "water" count habit, target 8, log ~5) → shows the count UI + partial grid fill.
- **Schedule/reminders** with a reminder row expanded and a week/weekend scope visible.
- Re-take #1 and #2 **after** the activity-grid polish merges (MR !6) so the grids show the new vivid fills + legend.

## Housekeeping
Raw device captures moved to `docs/screenshots/` (were at repo root). Treat these as the "before"
reference; the store set should use post-polish captures.

## Tooling note
No image compositor on the Linux box (no Pillow/ImageMagick), so framed PNGs can't be generated here.
Options: (a) build them on the Mac with a tiny SwiftUI/HTML template at 1320×2868, or (b) install
`imagemagick` on the box and I'll script the frame+caption compositing. Say which and I'll set it up.
