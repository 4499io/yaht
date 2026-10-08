# Yaht visual and interaction review

Reviewed the current `main` baseline `8f3ab4a` and implemented this pass on
`design/ui-ux-review` in `/workspace/yaht-ui-review`. The original checkout and
icon branch are separate. This is a source and historical-screenshot review;
Linux cannot render the current SwiftUI app. The screenshots under
`docs/screenshots` predate the Gruvbox redesign and cannot establish current
screen appearance. No synthetic screenshot is presented as an app capture.

## Direction

A calm, compact habit tracker: warm Gruvbox surfaces, an amber app accent,
individual habit colors, clear daily priorities, and generous touch targets.
Keep native navigation and sheet controls. Use cards for content; reserve
selection fills and stronger color for state and action. Preserve the stored
habit palette and existing persistence, scheduling, and migration behavior.

## Findings and changes

| Area | Finding | Change in this pass |
| --- | --- | --- |
| Typography | Fixed-point headings and values ignore Dynamic Type. | Added scaled rounded typography and larger ring controls. Dense calendar digits remain bounded for seven-column legibility and have spoken date/state labels. |
| Layout | Summary, statistics, tracking choices, and reminder settings stay side by side at large text sizes. | Shared adaptive stack switches to vertical layout from XXXL. Schedule choices become one column; week dates scroll when full-size targets no longer fit. |
| Home hierarchy | Habit names compete with notes on the same line; scheduled and off-day habits blend together. | Names and notes have separate lines; explicit On your list / Other habits sections retain the user's order. |
| Past-day context | Ring speaks "today" when another day is selected; rest days show 0/0. | Spoken summary includes the actual date; rest days show a dash and a rest-day label. Habits created after the selected day do not appear in that day's list or summary. |
| Check-in affordance | Empty rings have no visible action icon; count undo is hidden behind long press. | Added an unfilled check affordance, count undo/reset VoiceOver actions, and a visible Undo one control on count-habit detail. Count buttons continue to say Add one after the goal is reached. |
| Contrast | `Theme.background` on Plum is about 3.87:1, below normal-text contrast. | Black/white foreground selection uses sRGB relative luminance; all ten palette fills meet 4.5:1. Translucent custom colors are composited over the card surface. Palette tokens remain unchanged. |
| Selection | Color and tracking choices rely heavily on hue or outlines. | Selected colors, tracking modes, and schedules show explicit checkmarks as well as selected accessibility traits; cards strengthen their borders with Increase Contrast. |
| Editor feedback | Empty-name Save is disabled without an explanation; a zero-day schedule can be saved. | Inline guidance explains both states; Some days requires a valid selected weekday. |
| Weekday ordering | Editor uses hard-coded English labels and Sunday-first order. | Labels and ordering now follow the current calendar. |
| History semantics | Calendar labels future, pre-creation, paused, and off-schedule days as Not done. | Distinct spoken statuses, goal-day terminology, and a brief explanation of calendar and activity-grid encoding. |
| Detail statistics | Lifetime count is labeled check-ins although it counts completed days. | Labels now explicitly describe days completed and the 30-day metric. |
| First run | Primary action sits below all starter rows; singular selection says Add 1 habits. | Persistent bottom actions, clear singular/plural labels, concise onboarding copy, and selected-starter spoken names and descriptions. |
| Motion | Rings and day changes always animate. | Respect Reduce Motion for ring progress and day selection. |
| Review tooling | Home/detail previews lack required model/store environments. | Added isolated in-memory screen fixtures and normal/accessibility-text previews. These are prepared for Xcode, not rendered here. |

## Verification

- Local existing Python script suite: 8 test methods passed. These exercise
  developer scripts, not the SwiftUI app.
- Added 9 Swift tests: 4 contrast, 3 calendar-state, and 2 editor validation
  cases. They require the Apple test runner and are not executed on Linux.
- Reviewed source changes; all 20 changed Swift files pass tree-sitter syntax
  parsing. Also checked whitespace, Python syntax, asset JSON, and Xcode
  scheme/workspace XML. Parsing does not type-check Apple APIs. No schema, project build setting, deployment
  target, dependency, or icon changes are included.
- PR CI must compile the app and run its full Swift suite before approval.
  Passing script tests alone does not establish application readiness.

## Device acceptance checks

Capture fresh screenshots of the implemented screens and record device, OS,
Xcode/SDK, text size and locale. Do not approve visual quality from source alone.

| Target | Required checks |
| --- | --- |
| Small and standard iPhone | First run, populated Today, past-day check-in, rest day, long habit names, completed and partial count goals, paused habit, editor with multiple reminders. No clipped text or overlapping controls. |
| Dynamic Type | Default, XXXL, Accessibility 3 and Accessibility 5. Check summaries, row actions, details, calendar navigation, schedule choices, reminder settings, and first-run bottom actions. |
| VoiceOver | Habit navigation and completion remain separate; goal values, selected choices, date context, calendar statuses, undo and reset actions are accurate. |
| Locales | Monday-first and Sunday-first calendars, longer translated labels, 12/24-hour times, and right-to-left layout. |
| Accessibility settings | Reduce Motion, Increase Contrast, Bold Text; selected choices remain distinguishable without relying on hue alone. |
| iOS compatibility | Run the repository's iOS 26 baseline and SDK 27 validation on their supported runners. Review native sheet/toolbars and keyboard presentation. |
| Resizable windows | Narrow iPad windows and existing reserved-region layout. The new content must remain usable inside the current width cap. |

## Follow-up product work

These findings need dedicated behavior and device validation beyond this visual
pass; they remain open rather than being claimed as fixed:

1. Request notification permission when someone opts into reminders, with a
   useful denied-permission state. The root currently requests it on foreground
   entry, including first launch before reminders exist.
2. Add a discoverable archived-habits screen and restore action. Archiving
   retains data but the current UI has no way to revisit it.
3. Add unsaved-edit confirmation and verify sheet-dismiss/keyboard behavior.
4. Expose habit reordering; the store supports order but the current UI does not.
5. Offer accessible day-level drill-down for the blended global activity grid.
   Its current aggregate VoiceOver summary still cannot reveal a specific day.
6. Refresh the obsolete App Store screenshots after actual device validation.
