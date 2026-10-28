import SwiftUI

/// The big filled / outlined buttons, as in the other Sola apps.
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
