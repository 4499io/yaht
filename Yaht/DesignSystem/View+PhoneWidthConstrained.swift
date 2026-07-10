import SwiftUI

extension View {
    /// Caps content at an iPhone-class width and centers it, so the UI never
    /// stretches edge-to-edge in a resizable window on iPadOS 26+.
    ///
    /// Every iPhone-only app is now installable *and resizable* on iPad, and the
    /// old scaled/letterboxed compatibility mode is gone under the iOS 26 SDK — an
    /// iPhone app receives real iPad-size geometry and its layout will stretch.
    /// Apple rejects that under Guideline 4 (Design). `horizontalSizeClass` stays
    /// `.compact`, so no iPad UI is expected — only that the layout doesn't break.
    ///
    /// Apply at the window root **and** at the root of every `.sheet` /
    /// `.fullScreenCover`: sheets present at window level, so the root cap does not
    /// reach them. On iPhone (screen narrower than `maxWidth`) this is a no-op.
    ///
    /// Ref: 99issues #418 · Apple TN3192 (UIRequiresFullScreen deprecation).
    func phoneWidthConstrained(_ maxWidth: CGFloat = 440) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
