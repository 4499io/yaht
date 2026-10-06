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

`Configuration/SDKConditions.xcconfig` sets the condition automatically for
SDK 27.1 and later (Xcode, Xcode Cloud and `xcodebuild` alike), so no manual
build setting is needed. Do not set it by hand for SDK 27.0 or infer SDK
support from the Swift compiler version. To exercise the 27.1 path, build with
Xcode 27.1+ and run on an iOS 27.1+ simulator or device.

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
