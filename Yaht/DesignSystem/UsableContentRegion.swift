import Foundation
import CoreGraphics

/// Finds one axis-aligned content rectangle without crossing a reservation.
/// Frames already contain hardware interaction margins; do not expand them.
enum UsableContentRegion {
    static func largest(in bounds: CGRect, excluding reservations: [CGRect]) -> CGRect {
        guard isValid(bounds) else { return .zero }
        let obstacles = reservations.compactMap { reservation -> CGRect? in
            guard isValid(reservation) else { return nil }
            let intersection = bounds.intersection(reservation)
            return isValid(intersection) ? intersection : nil
        }
        guard !obstacles.isEmpty else { return bounds }

        // A maximal free rectangle has edges on the bounds or an obstacle.
        // Enumerating these edges also finds rectangles spanning several gaps,
        // which a greedy subtraction/partition can miss.
        let xs = Array(Set([bounds.minX, bounds.maxX] + obstacles.flatMap { [$0.minX, $0.maxX] })).sorted()
        let ys = Array(Set([bounds.minY, bounds.maxY] + obstacles.flatMap { [$0.minY, $0.maxY] })).sorted()
        var best = CGRect(x: bounds.minX, y: bounds.minY, width: 0, height: 0)
        var bestArea: CGFloat = 0
        for left in 0..<(xs.count - 1) {
            for right in (left + 1)..<xs.count {
                for top in 0..<(ys.count - 1) {
                    for bottom in (top + 1)..<ys.count {
                        let candidate = CGRect(
                            x: xs[left], y: ys[top],
                            width: xs[right] - xs[left], height: ys[bottom] - ys[top]
                        )
                        guard !obstacles.contains(where: { obstacle in
                            let overlap = candidate.intersection(obstacle)
                            return overlap.width > 0 && overlap.height > 0
                        }) else { continue }
                        let area = candidate.width * candidate.height
                        // Physical top, then left, then wider is deterministic
                        // regardless of reservation order or layout direction.
                        let winsTie = candidate.minY < best.minY
                            || (candidate.minY == best.minY && candidate.minX < best.minX)
                            || (candidate.minY == best.minY && candidate.minX == best.minX
                                && candidate.width > best.width)
                        if area > bestArea || (area == bestArea && winsTie) {
                            best = candidate
                            bestArea = area
                        }
                    }
                }
            }
        }
        return best
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0
            && rect.maxX.isFinite && rect.maxY.isFinite
            && (rect.width * rect.height).isFinite
    }
}
