import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// The few places where iPhone/iPad and Mac differ.
nonisolated extension Image {
    init(platformImage img: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: img)
        #else
        self.init(uiImage: img)
        #endif
    }
}

nonisolated extension Color {
    /// A color that follows light and dark mode.
    static func dynamic(light: Color, dark: Color) -> Color {
        #if os(macOS)
        Color(NSColor(name: nil) { a in NSColor(a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light) })
        #else
        Color(UIColor { t in UIColor(t.userInterfaceStyle == .dark ? dark : light) })
        #endif
    }
}

/// Where to send people who turned something off.
enum SystemSettings {
    /// This app's notification settings.
    static var notifications: URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")")
        #else
        URL(string: UIApplication.openNotificationSettingsURLString)
        #endif
    }

    /// Contacts access: the app's settings on iPhone, Privacy & Security on the Mac.
    static var contacts: URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts")
        #else
        URL(string: UIApplication.openSettingsURLString)
        #endif
    }
}

extension View {
    /// Small title in the bar on iPhone and iPad; the Mac has no large titles anyway.
    func inlineTitle() -> some View {
        #if os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Sheets on the Mac are only as big as their content asks for.
    func sheetSize(width: CGFloat = 460, height: CGFloat = 640) -> some View {
        #if os(macOS)
        frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height)
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    /// Top left on iPhone and iPad; on the Mac, next to the other buttons.
    static var leading: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarLeading
        #endif
    }
}
