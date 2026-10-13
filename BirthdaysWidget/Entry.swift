import Foundation
import WidgetKit

struct BirthdayEntry: TimelineEntry {
    let date: Date
    /// Visible birthdays by next date, as seen from `date`.
    let items: [Upcoming]

    var today: [Upcoming] { items.filter { $0.days == 0 } }
    /// Birthdays in the next 7 days, not counting today.
    var soon: Int { items.filter { (1...7).contains($0.days) }.count }

    init(date: Date, data: AppData) {
        self.date = date
        items = Array(data.upcoming(from: date).prefix(12))
    }

    /// Made-up birthdays for the widget gallery.
    static var sample: BirthdayEntry {
        var data = AppData()
        let cal = Calendar.birthdays
        for (name, short, days, year) in [("Anna Berger", "Anna", 3, 1992), ("Ben Krüger", "Ben", 9, 1988),
                                          ("Clara Wolf", "Clara", 16, 2001), ("David Roth", "David", 24, 1979)] {
            let d = cal.date(byAdding: .day, value: days, to: .now) ?? .now
            let c = cal.dateComponents([.month, .day], from: d)
            data.birthdays.append(Birthday(name: name, shortName: short, month: c.month ?? 1, day: c.day ?? 1, year: year))
        }
        return BirthdayEntry(date: .now, data: data)
    }
}
