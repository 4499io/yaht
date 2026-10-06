# Hardware division layout on iOS 27.1

Yaht retains its single navigation column and 440-point width cap. On iOS
27.1, the window root and editor root query active hardware divisions and
place that column inside the largest contiguous rectangle that does not
cross a division. Frames from Apple already include interaction margins.
Physical coordinates (`layoutDirectionBehavior: .fixed`) keep placement
consistent with the queried frames in both left-to-right and right-to-left
interfaces. Equal-area candidates prefer the top, then left, then wider
rectangle. A completely reserved container yields a clipped zero-size column.

The existing layout remains the fallback on iOS 26 and 27.0 and when there
are no intersecting divisions. No minimum deployment target changes.
`GeometryReader` is used only at the two full-height presentation roots;
this modifier must not be applied to intrinsically sized list rows or cards.

## SDK compilation

The new symbols are behind `YAHT_IOS27_1_SDK`, and runtime execution is also
guarded by `#available(iOS 27.1, *)`. Xcode 26 and 27.0 compile the existing
fallback without that condition. The SDK validation runner should enable
the condition only when the selected SDK is at least 27.1.

For native Xcode 27.1+ builds, add `YAHT_IOS27_1_SDK` to **Active Compilation
Conditions** for the app target, preserving existing conditions. For direct
`xcodebuild` validation, replace the destination placeholder with an installed
iOS 27.1+ simulator UDID and pass:

```sh
xcodebuild test -project Yaht.xcodeproj -scheme Yaht \
  -destination 'platform=iOS Simulator,id=<INSTALLED-27.1-UDID>' \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) YAHT_IOS27_1_SDK'
```

Do not enable this condition against SDK 27.0 or infer SDK support from the
Swift compiler version. Without it, newer native Xcode builds intentionally
retain the fallback as well.

## Validation

`UsableContentRegionTests` exercise no reservations, vertical/horizontal and
multiple divisions, spanning free rectangles, offset/out-of-bounds geometry,
equal-area ties, undersized windows, full reservations, and invalid input.
Apple builds and Swift Testing cannot run on this Linux machine. On macOS,
run baseline iOS 26 tests and SDK 27.1 tests with the condition enabled. Verify
the list and editor navigation, keyboard, safe areas, large Dynamic Type,
right-to-left layout, resizing, and actual hardware division geometry.

Official API evidence:

- https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)
- https://developer.apple.com/documentation/swiftui/reservedregion/frame
- https://developer.apple.com/documentation/swiftui/reservedregion/isactive
