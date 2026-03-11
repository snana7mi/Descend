import CoreGraphics

extension CGFloat {
    static func lerp(from start: CGFloat, to end: CGFloat, t: CGFloat) -> CGFloat {
        start + (end - start) * t
    }

    static func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        Swift.min(maxVal, Swift.max(minVal, value))
    }
}
