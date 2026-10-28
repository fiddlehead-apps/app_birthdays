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
}
#endif
