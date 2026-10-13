import SwiftUI

/// The big filled / outlined buttons, as in the other Klar apps.
struct BigButtonStyle: ButtonStyle {
    var primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 22)
            .foregroundStyle(primary ? Color.brandInk : Color.ink)
            .background(primary ? Color.brand : Color.surface, in: .rect(cornerRadius: 16))
            .overlay {
                if !primary { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line, lineWidth: 1.5) }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Round outlined icon button for the top bar.
struct CircleIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .background(Color.surface, in: .circle)
                .overlay(Circle().strokeBorder(Color.line, lineWidth: 1.5))
        }
        .accessibilityLabel(label)
    }
}

extension View {
    /// White card with a thin border.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line, lineWidth: 1.5))
    }
}

/// A cake with three candles, the motif of the app icon.
struct CakeIllustration: View {
    var body: some View {
        Canvas { ctx, _ in
            // plate
            ctx.fill(Path(roundedRect: CGRect(x: 20, y: 128, width: 150, height: 10), cornerRadius: 5), with: .color(.line))
            // cake
            let cake = Path(roundedRect: CGRect(x: 36, y: 72, width: 118, height: 58), cornerRadius: 10)
            ctx.fill(cake, with: .color(.surface))
            ctx.stroke(cake, with: .color(.line), lineWidth: 1.5)
            // icing with drips
            var icing = Path()
            icing.move(to: CGPoint(x: 36, y: 82))
            icing.addArc(center: CGPoint(x: 46, y: 82), radius: 10, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            icing.addLine(to: CGPoint(x: 144, y: 72))
            icing.addArc(center: CGPoint(x: 144, y: 82), radius: 10, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            icing.addLine(to: CGPoint(x: 154, y: 92))
            for (x, depth) in [(138.0, 10.0), (114.0, 16.0), (90.0, 8.0), (66.0, 14.0), (44.0, 9.0)] {
                icing.addQuadCurve(to: CGPoint(x: x, y: 92), control: CGPoint(x: x + 12, y: 92 + depth * 1.6))
            }
            icing.addLine(to: CGPoint(x: 36, y: 92))
            icing.closeSubpath()
            ctx.fill(icing, with: .color(.brand))
            // candles and flames
            for x in [62.0, 92.0, 122.0] {
                ctx.fill(Path(roundedRect: CGRect(x: x - 4, y: 40, width: 8, height: 32), cornerRadius: 3), with: .color(.ink))
                var flame = Path()
                flame.move(to: CGPoint(x: x, y: 16))
                flame.addQuadCurve(to: CGPoint(x: x, y: 34), control: CGPoint(x: x + 11, y: 30))
                flame.addQuadCurve(to: CGPoint(x: x, y: 16), control: CGPoint(x: x - 11, y: 30))
                ctx.fill(flame, with: .color(.sun))
            }
        }
        .frame(width: 190, height: 140)
        .accessibilityHidden(true)
    }
}
