import CoreGraphics
import Testing
@testable import Yaht

@MainActor
struct UsableContentRegionTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)

    @Test func noReservationsRetainWholeContainer() {
        #expect(UsableContentRegion.largest(in: bounds, excluding: []) == bounds)
    }

    @Test func tallDivisionChoosesLargerSide() {
        let division = CGRect(x: 400, y: 0, width: 40, height: 800)
        #expect(UsableContentRegion.largest(in: bounds, excluding: [division])
            == CGRect(x: 440, y: 0, width: 560, height: 800))
    }

    @Test func wideDivisionChoosesLargerVerticalRegion() {
        let division = CGRect(x: 0, y: 300, width: 1_000, height: 20)
        #expect(UsableContentRegion.largest(in: bounds, excluding: [division])
            == CGRect(x: 0, y: 320, width: 1_000, height: 480))
    }

    @Test func crossingDivisionsLeaveOneContiguousQuadrant() {
        let divisions = [
            CGRect(x: 400, y: 0, width: 20, height: 800),
            CGRect(x: 0, y: 300, width: 1_000, height: 20)
        ]
        #expect(UsableContentRegion.largest(in: bounds, excluding: divisions)
            == CGRect(x: 420, y: 320, width: 580, height: 480))
    }

    @Test func separateReservationsAllowSpanningFreeRectangles() {
        let smallBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let divisions = [
            CGRect(x: 20, y: 20, width: 20, height: 20),
            CGRect(x: 60, y: 60, width: 20, height: 20)
        ]
        let expected = CGRect(x: 40, y: 0, width: 60, height: 60)
        #expect(UsableContentRegion.largest(in: smallBounds, excluding: divisions) == expected)
        #expect(UsableContentRegion.largest(in: smallBounds, excluding: Array(divisions.reversed())) == expected)
    }

    @Test func reservationsAreClippedToOffsetBounds() {
        let offsetBounds = CGRect(x: 10, y: 20, width: 100, height: 80)
        let reservations = [
            CGRect(x: -50, y: -50, width: 80, height: 200),
            CGRect(x: 200, y: 200, width: 10, height: 10)
        ]
        #expect(UsableContentRegion.largest(in: offsetBounds, excluding: reservations)
            == CGRect(x: 30, y: 20, width: 80, height: 80))
    }

    @Test func outsideOrTouchingReservationsDoNotReduceContent() {
        let reservations = [
            CGRect(x: -20, y: 0, width: 20, height: 800),
            CGRect(x: 1_000, y: 0, width: 20, height: 800)
        ]
        #expect(UsableContentRegion.largest(in: bounds, excluding: reservations) == bounds)
    }

    @Test func equalSidesPreferPhysicalLeftAndEqualRowsPreferTop() {
        #expect(UsableContentRegion.largest(in: bounds, excluding: [
            CGRect(x: 490, y: 0, width: 20, height: 800)
        ]) == CGRect(x: 0, y: 0, width: 490, height: 800))
        #expect(UsableContentRegion.largest(in: bounds, excluding: [
            CGRect(x: 0, y: 390, width: 1_000, height: 20)
        ]) == CGRect(x: 0, y: 0, width: 1_000, height: 390))
    }

    @Test func undersizedWindowsAreNotExpandedToPhoneWidth() {
        let narrow = CGRect(x: 0, y: 0, width: 200, height: 300)
        #expect(UsableContentRegion.largest(in: narrow, excluding: []) == narrow)
        #expect(UsableContentRegion.largest(in: narrow, excluding: [
            CGRect(x: 80, y: 0, width: 20, height: 300)
        ]) == CGRect(x: 100, y: 0, width: 100, height: 300))
    }

    @Test func fullyReservedContainerHasNoUsableContent() {
        #expect(UsableContentRegion.largest(in: bounds, excluding: [bounds]) == .zero)
    }

    @Test func invalidGeometryCannotProduceNegativeOrNonfiniteFrames() {
        let invalid = [CGRect.zero, CGRect.null, CGRect.infinite,
            CGRect(x: 0, y: 0, width: -10, height: 20),
            CGRect(x: CGFloat.nan, y: 0, width: 20, height: 20)]
        for rect in invalid {
            #expect(UsableContentRegion.largest(in: rect, excluding: []) == .zero)
        }
        #expect(UsableContentRegion.largest(in: bounds, excluding: invalid) == bounds)
    }
}
