#if DEBUG
import Foundation

/// Sample birthdays for App Store screenshots.
/// Only in debug builds, and only with the launch argument `-demoData YES` on an empty list.
enum DemoData {
    @MainActor static func seedIfRequested(_ store: Store) {
        guard UserDefaults.standard.bool(forKey: "demoData"), store.data.birthdays.isEmpty else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let people: [(String, Int, Int?)] = [
            ("Anna Becker", 0, 1990), ("Jonas Weber", 2, 1986), ("Mia Schulz", 5, 2016),
            ("Oma Hilde", 6, 1941), ("Lukas Fischer", 12, nil), ("Emma Wagner", 19, 1994),
            ("Paul Hoffmann", 27, 1979), ("Lena Koch", 38, 2019), ("Felix Richter", 51, 1988),
            ("Sophie Klein", 66, nil), ("Noah Wolf", 80, 2012), ("Clara Neumann", 97, 1992),
        ]
        for (name, inDays, year) in people {
            let date = cal.date(byAdding: .day, value: inDays, to: today)!
            let parts = cal.dateComponents([.month, .day], from: date)
            let short = String(name.split(separator: " ").first ?? Substring(name))
            store.saveManual(Birthday(name: name, shortName: short, month: parts.month!, day: parts.day!, year: year))
        }
    }

    /// With `-demoOpen <n>`, opens the n-th birthday of the list, for screenshots of the detail.
    @MainActor static func openIfRequested(_ store: Store, _ router: Router) {
        let n = UserDefaults.standard.integer(forKey: "demoOpen")
        guard n > 0, store.visible.indices.contains(n - 1) else { return }
        router.open = store.visible[n - 1].id
    }
}

#if os(macOS)
import AppKit
import SwiftUI

extension DemoData {
    /// With `-demoSnapshot <file.png>`, for the Mac App Store: once the windows have settled,
    /// draws them on a 2880 × 1800 background into that file and quits. The app draws its own
    /// windows, so this needs no screen recording permission.
    @MainActor static func snapshotIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "demoSnapshot") else { return }
        // Light like the iPhone screenshots, and wide enough that the detail sheet fits in.
        NSApp.appearance = NSAppearance(named: .aqua)
        Task {
            try? await Task.sleep(for: .seconds(1))
            if let window = NSApp.windows.first(where: { $0.isVisible && $0.sheetParent == nil }) {
                window.setContentSize(NSSize(width: 640, height: 800))
            }
            try? await Task.sleep(for: .seconds(3))
            // Active, so the window and checkboxes show their colors (macOS may take a moment).
            for _ in 0..<20 where !NSApp.isActive {
                NSApp.activate()
                try? await Task.sleep(for: .milliseconds(250))
            }
            try? await Task.sleep(for: .milliseconds(500))
            if let png = snapshot() { try? png.write(to: URL(filePath: path)) }
            NSApp.terminate(nil)
        }
    }

    @MainActor private static func snapshot() -> Data? {
        var png: Data?
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance { png = draw() }
        return png
    }

    @MainActor private static func draw() -> Data? {
        let canvas = NSSize(width: 1440, height: 900)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2880, pixelsHigh: 1800, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = canvas
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        NSGradient(starting: NSColor(Color.brandSoft), ending: NSColor(Color.bg))?
            .draw(in: NSRect(origin: .zero, size: canvas), angle: -60)

        // Back to front, at their places relative to each other, centered as a group.
        let windows = NSApp.orderedWindows.filter(\.isVisible).reversed()
        let all = windows.map(\.frame).reduce(NSRect.null) { $0.union($1) }
        let shift = NSPoint(x: (canvas.width - all.width) / 2 - all.minX, y: (canvas.height - all.height) / 2 - all.minY)
        for window in windows {
            guard let view = window.contentView?.superview, let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: image)
            let rect = window.frame.offsetBy(dx: shift.x, dy: shift.y)
            let shape = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = .black.withAlphaComponent(0.22)
            shadow.shadowBlurRadius = 30
            shadow.shadowOffset = NSSize(width: 0, height: -10)
            shadow.set()
            NSColor(Color.bg).setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            image.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
        }
        return rep.representation(using: .png, properties: [:])
    }
}
#endif
#endif
