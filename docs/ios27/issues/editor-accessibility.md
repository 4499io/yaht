# Label color choices and enlarge habit-editor controls

Priority: P2. Existing accessibility defect; no iOS 27-specific requirement
has been verified.

## Problem

`HabitEditView` uses Circle-only color buttons with accessibility identifiers
but no spoken color names, and 30-point swatches. The weekday editor uses
34-point-high controls in a rigid seven-column row. VoiceOver cannot describe
color choices meaningfully and narrow layouts have small touch targets.

## Acceptance criteria

- Announce documented palette color names and selected state with VoiceOver.
- Preserve persisted color hex values and existing accessibility identifiers.
- Give color and weekday controls targets of at least 44 by 44 points.
- Adapt weekday layout on narrow screens and announce full weekday names.
- Verify selection, VoiceOver, and largest Dynamic Type on a narrow iPhone.

Implementation branch: `fix/habit-color-accessibility`.
Remote issue: https://github.com/4499io/yaht/issues/2

## Implementation progress

Implementation prepared locally on `fix/habit-color-accessibility` (`6bc58ee`, `0e9c3ec`): named colors, full localized weekday labels, and 44-point targets. Palette tokens and ordering unchanged. VoiceOver, Dynamic Type and build validation remain unrun.

Branches remain local: upstream push permission is absent, and GitHub integration denied fork creation. Issue remains open pending acceptance checks.
