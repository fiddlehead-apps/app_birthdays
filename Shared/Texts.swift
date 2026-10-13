import Foundation

/// Texts used by the app, the widgets and the notifications.
nonisolated enum Texts {
    /// "Today", "Tomorrow", "In 3 days".
    static func days(_ n: Int) -> String {
        switch n {
        case 0: String(localized: "Today", comment: "Birthday is today")
        case 1: String(localized: "Tomorrow", comment: "Birthday is tomorrow")
        default: String(localized: "In \(n) days", comment: "Days until a birthday, more than one")
        }
    }

    /// "3 days", "1 day" – compact, for the widgets.
    static func count(_ n: Int) -> String {
        String(localized: "\(n) days", comment: "Number of days, compact")
    }

    /// "day" / "days" under a big number, without the number.
    static func unit(_ n: Int) -> String {
        n == 1 ? String(localized: "day", comment: "Under the big number 1 in the small widget")
            : String(localized: "days", comment: "Under the big number of days in the small widget")
    }

    /// When a reminder fires, relative to the birthday.
    static func offset(_ n: Int) -> String {
        switch n {
        case 0: String(localized: "On the day", comment: "Reminder on the birthday itself")
        case 1: String(localized: "The day before", comment: "Reminder 1 day before")
        case 7: String(localized: "1 week before", comment: "Reminder 7 days before")
        case 14: String(localized: "2 weeks before", comment: "Reminder 14 days before")
        default: String(localized: "\(n) days before", comment: "Reminder some days before the birthday")
        }
    }

    /// "1 week before · On the day", or "No reminders".
    static func offsets(_ list: [Int]) -> String {
        guard !list.isEmpty else { return String(localized: "No reminders", comment: "A birthday without reminders") }
        return list.sorted(by: >).map(offset).joined(separator: " · ")
    }

    static func turns(_ age: Int) -> String {
        String(localized: "Turns \(age)", comment: "Age on the next birthday")
    }

    /// "20 October" / "20. Oktober"
    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }

    /// "Oct 20" / "20. Okt."
    static func shortDayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "Tuesday, 20 October"
    static func weekdayDayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
