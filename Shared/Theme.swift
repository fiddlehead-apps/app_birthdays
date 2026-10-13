import SwiftUI

/// Klar palette, light and dark. Same neutrals as the other Klar apps, raspberry as accent.
nonisolated extension Color {
    static let bg = dynamic(0xEEF0F3, 0x121418)
    static let surface = dynamic(0xFFFFFF, 0x1C1F25)
    static let ink = dynamic(0x16181D, 0xF1F2F4)
    static let muted = dynamic(0x5D6470, 0x9AA1AD)
    static let line = dynamic(0xD5D9E0, 0x2C3038)
    static let brand = dynamic(0xD63A5E, 0xFF8AA3)
    static let brandInk = dynamic(0xFFFFFF, 0x2B0711)
    static let brandSoft = dynamic(0xFBE3E9, 0x3A1C24)
    static let danger = dynamic(0xC4321F, 0xE5533E)
    static let sun = Color(hex: 0xFFC857)

    /// Soft backgrounds for initials when a contact has no photo.
    static let avatarTones: [Color] = [0x8BA3FF, 0xFF9F80, 0x7FD1AE, 0xFFC857, 0xC49BFF, 0x6FC3DF, 0xF28DB2]
        .map { Color(hex: $0) }

    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { t in UIColor(Color(hex: t.userInterfaceStyle == .dark ? dark : light)) })
    }
}

/// Round contact photo, or initials on a color picked from the name.
struct Avatar: View {
    let birthday: Birthday
    var size: CGFloat = 44
    /// Pass a preloaded image (widgets); otherwise the photo is read from disk.
    var image: UIImage?

    var body: some View {
        Group {
            if let img = image ?? (birthday.hasPhoto ? Storage.photo(birthday.id) : nil) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(birthday.initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x16181D))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.avatarTones[Int(stableHash(birthday.name) % UInt32(Color.avatarTones.count))])
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
