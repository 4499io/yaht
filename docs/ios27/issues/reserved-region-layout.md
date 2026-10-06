# Keep the habit interface out of active hardware divisions on iOS 27.1

Priority: P1. Confirmed new adaptive API adoption; preserve iOS 26 support.

## Evidence and app impact

Apple's September SwiftUI updates introduce reserved hardware regions and
adaptive arrangements. Symbol documentation marks these APIs available from
iOS 27.1, not iOS 27.0. Yaht's `phoneWidthConstrained()` centers a 440-point
column across the full container. On hardware with a central active division,
that can place content or touch targets across the division.

- https://developer.apple.com/documentation/updates/swiftui
- https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)
- https://developer.apple.com/documentation/swiftui/reservedregion/frame
- https://developer.apple.com/documentation/swiftui/reservedregion/isactive

## Acceptance criteria

- Keep the single-column app and existing width cap in a contiguous usable
  rectangle outside active division regions, including editor presentations.
- Query geometry in physical coordinates with `.fixed` layout direction;
  region frames already include margins, so do not expand them again.
- Handle vertical/horizontal/multiple divisions, narrow windows, no division,
  out-of-bounds reservations, and deterministic tie breaking.
- Preserve iOS 26 and 27.0 runtime/build support: gate new symbols behind an
  explicit SDK compilation condition and runtime iOS 27.1 availability.
  Automatically enable the SDK condition only after detecting SDK 27.1+ in
  the validation runner. A Swift compiler version alone is insufficient.
- Test the rectangle-selection algorithm and validate actual hardware/simulator
  geometry and editor navigation on macOS with Xcode 27.1+.

Implementation branch: `feat/ios27-reserved-region-layout`.
Apple-platform compilation and runtime checks cannot run in this Linux machine.

Remote issue: https://github.com/4499io/yaht/issues/5
