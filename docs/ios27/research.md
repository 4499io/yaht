# Yaht: verified iOS 27 migration research

Research date: 2026-10-06. Official Apple content fetched successfully after environment networking became available. The release notes are structured DocC JSON with matching title and canonical identifier, not a generic HTTP-200 HTML page.

## Toolchain and publication status

- [iOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes): SDK bundled with Xcode 27.
- [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes): Swift 6.4, macOS Tahoe 26.6 or later required.
- [Apple developer releases](https://developer.apple.com/news/releases/): iOS 27.2 beta 3 (24B5099f), Xcode 27.1 RC (27A9275), published October 5, 2026. Do not confuse beta testing with the stable baseline.
- The existing minimum deployment target is iOS 26.0. Building with a new SDK does not itself require increasing this minimum.

## Confirmed base iOS 27 behavior changes

From iOS 27 release notes:

- @State becomes a macro in Xcode 27, with lazy class initialization and source-compatibility exceptions (105893279). Declaration initial values plus constructor assignments, synthesized private struct initializers, generic inference, and composing wrappers/macros require auditing. Existing YahtApp and HabitEditView have explicit State(initialValue:) constructors; actual Xcode 27 compilation is required to verify them.
- Apps built with SDK 27 require a launch-screen plist key (168247372). Yaht already sets INFOPLIST_KEY_UILaunchScreen_Generation=YES for Debug and Release. Validate built plist rather than claim a missing configuration.
- Apps linked latest SDK must use scene-based lifecycle or fail to launch (141837548). Yaht already uses SwiftUI App and WindowGroup.
- iPad menu symbol images are hidden by default in many contexts; labelStyle(.titleAndIcon) can retain appropriate object/concept icons (170480710). Audit context menus; no need to restore every action icon.
- controlSize, buttonSizing, buttonRepeatBehavior, menuIndicatorVisibility, ButtonBorderShape reset in sheets/popovers (167448274). Existing editor needs presentation validation.
- roundedBorder and squareBorder text-field styles soft-deprecated in favor of bordered (173362083); current app does not use those old styles.
- TabsPickerStyle exists for navigation tabs and improves VoiceOver semantics (173211711); current app has no TabView.
- SwiftData background ModelContext/@Query deadlock fixed (178113288). No automatic schema rewrite follows from this fix.
- CloudKit CKShare administrator self-demotion fix (177621316); current app uses SwiftData automatic mirroring, not explicit CKShare roles.
- Notifications critical-alert permission bug fixed (179179362); current app requests alert/sound/badge, not critical alerts.

## Confirmed iOS 27.1 adaptive APIs

[SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui), September 2026, publishes ArrangementView, hardware reserved regions, hinge handling, and vertical toolbar behavior. Exact symbol pages mark these APIs introduced in iOS/iPadOS **27.1**, currently beta metadata true. Do not label them 27.0 APIs.

- [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview): nonisolated struct ArrangementView<Primary, Secondary> where Primary: View, Secondary: View. Computes layout using available size, size class, and hardware features.
- [Initializer](https://developer.apple.com/documentation/swiftui/arrangementview/init(primary:secondary:)): nonisolated init(@ContentBuilder primary: () -> Primary, @ContentBuilder secondary: () -> Secondary). .arrangementViewStyle(.split) gives adaptive primary/secondary panes; .overlay supports controls over a full-screen surface and can adapt to side-by-side on folded devices.
- [GeometryProxy.reservedRegions](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)): func reservedRegions(kind: ReservedRegion.Kind, options: ReservedRegion.QueryOptions = [], layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors) -> [ReservedRegion]. .division identifies hinge/fold split regions; .occlusion identifies camera/Dynamic Island/window controls.
- [ReservedRegion.frame](https://developer.apple.com/documentation/swiftui/reservedregion/frame): var frame: CGRect { get }, in querying view coordinates, **includes margins**. Do not expand again.
- [ReservedRegion.margins](https://developer.apple.com/documentation/swiftui/reservedregion/margins): var margins: EdgeInsets { get }, describes included interaction margins.
- [ReservedRegion.isActive](https://developer.apple.com/documentation/swiftui/reservedregion/isactive): var isActive: Bool { get }. Explicit filtering is useful because prose about default active/inactive behavior is inconsistent between symbol descriptions.
- .mirrors is default for RTL; [LayoutDirectionBehavior.fixed](https://developer.apple.com/documentation/swiftui/layoutdirectionbehavior/fixed) avoids automatic geometry mirroring for manual physical CGRect placement.
- [onHingeChange](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)): nonisolated func onHingeChange(isEnabled: Bool = true, _ action: @escaping (DeviceHingeContext, DeviceHingeContext) -> Void) -> some View. It is for iPhone Duo; do not gate layout using device-model strings.
- [toolbarVerticalBehavior](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:)): nonisolated func toolbarVerticalBehavior(_ behavior: ToolbarVerticalBehavior) -> some View, introduced 27.1.

Yaht currently centers a 440-point column at its root and editor sheet, which can place it across a hinge. Minimal adaptation: preserve one-column app and select a contiguous region outside active .division frames, applying the existing width cap within that region. Add deterministic geometry tests for vertical/horizontal divisions, no regions, undersized windows, and bounds. Alternative ArrangementView adoption involves a deliberate second content pane and navigation design.

Require Xcode 27.1+ to compile these symbols and #available(iOS 27.1, *) for runtime. A compiler-version guard alone cannot prove SDK 27.1 availability: Xcode 27.0 already includes Swift 6.4.

## Existing readiness defects, not Apple-mandated migrations

- YahtApp cloud-container failure moves the SQLite store aside before attempting local persistence. Try explicitly cloud-disabled local fallback against the existing store first; this prevents iCloud/provisioning failures from appearing to erase history.
- VoiceOver history grid exposes insufficient data: single-habit grid says only Activity grid; global grid has no meaningful dates/progress description. Improve semantic summaries independently of visual design.
- GlassCard/Pill use Material backgrounds while comments claim Liquid Glass. Existing material is appropriate for content surfaces; audit roles before adopting glassEffect wholesale.

## Validation limits

This Linux environment cannot compile Apple SwiftUI/SwiftData or execute iOS simulators. Tests and build validation must run on macOS with the required Xcode SDK and iOS 26/27/27.1 device or simulator runtimes. Validate startup with existing store, CloudKit unavailable, existing reminders/permissions, editor navigation, Dynamic Type and VoiceOver, iPad resizing, and hardware division layouts.
