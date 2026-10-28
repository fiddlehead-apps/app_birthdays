import SwiftUI

/// Slim line drawing in the style of the app icon. Coordinates are those of the
/// 1024 px icon canvas (tools/make_icon.py); `area` is the part of it to show.
struct LineArt: View {
    let area: CGRect
    let width: CGFloat
    var lineWidth: CGFloat = 3.5
    var color: Color = .brand
    let draw: (inout Path) -> Void

    var body: some View {
        let scale = width / area.width
        Canvas { ctx, _ in
            var path = Path()
            draw(&path)
            let fit = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -area.minX, y: -area.minY)
            ctx.stroke(path.applying(fit), with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: area.height * scale)
        .accessibilityHidden(true)
    }
}

extension Path {
    /// Fiddlehead curl starting at `start`, leaving in direction `heading`
    /// (degrees, 0 = up, clockwise). Same construction as the curl in the app icon.
    mutating func addFiddlehead(at start: CGPoint, heading: Double, radius: Double, turns: Int = 3, left: Bool = false) {
        let h = heading * .pi / 180, flip: Double = left ? -1 : 1
        func place(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: start.x + flip * x * cos(h) - y * sin(h), y: start.y + flip * x * sin(h) + y * cos(h))
        }
        move(to: start)
        var from = 0.0
        for (i, f) in [1, 0.64, 0.33, 0.12].prefix(turns).enumerated() {
            let r = radius * f
            let (cx, a0) = i % 2 == 0 ? (from + r, Double.pi) : (from - r, 0)
            for k in 1...40 {
                let a = a0 + .pi * Double(k) / 40
                addLine(to: place(cx + r * cos(a), r * sin(a)))
            }
            from = cx - r * cos(a0)
        }
    }
}

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// A balloon whose string ends in a curl. The motif of the app icon.
struct BalloonIllustration: View {
    var body: some View {
        LineArt(area: CGRect(x: 290, y: 150, width: 444, height: 744), width: 96) { p in
            p.move(to: pt(512, 176))
            p.addCurve(to: pt(708, 378), control1: pt(632, 176), control2: pt(708, 268))
            p.addCurve(to: pt(512, 606), control1: pt(708, 500), control2: pt(600, 592))
            p.addCurve(to: pt(316, 378), control1: pt(424, 592), control2: pt(316, 500))
            p.addCurve(to: pt(512, 176), control1: pt(316, 268), control2: pt(392, 176))
            p.closeSubpath()
            // knot
            p.move(to: pt(490, 640))
            p.addLines([pt(490, 640), pt(512, 606), pt(534, 640)])
            p.closeSubpath()
            // string
            p.move(to: pt(512, 640))
            p.addCurve(to: pt(512, 776), control1: pt(474, 690), control2: pt(550, 730))
            p.addFiddlehead(at: pt(512, 776), heading: 200, radius: 70, left: true)
            // highlight
            p.move(to: pt(404, 300))
            p.addCurve(to: pt(486, 242), control1: pt(422, 266), control2: pt(452, 248))
        }
    }
}
