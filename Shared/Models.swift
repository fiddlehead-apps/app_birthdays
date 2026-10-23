import Foundation

/// One birthday. Comes from a contact, or was added by hand.
nonisolated struct Birthday: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    /// `CNContact.identifier` on this device. Contact IDs differ between devices, so this one
    /// isn't synced: birthdays from iCloud start without it and get matched by name and date.
    var contactID: String?
    /// Came from the contacts (true) or was added by hand.
    var fromContacts: Bool
    var name: String
    /// First name or nickname, for tight spots like the widgets.
    var shortName: String
    var month: Int
    var day: Int
    var year: Int?
    var hasPhoto = false
    /// Hidden birthdays stay in the data so the next sync doesn't bring them back,
    /// but they get no reminders and don't show up in the list or the widgets.
    var hidden = false
    /// Days before the birthday to remind, 0 = on the day. nil = use the default.
    var reminders: [Int]?
    /// Last change of a synced field, for resolving conflicts with iCloud.
    var modified = Date()

    init(contactID: String? = nil, name: String, shortName: String, month: Int, day: Int, year: Int?) {
        self.contactID = contactID
        fromContacts = contactID != nil
        self.name = name
        self.shortName = shortName
        self.month = month
        self.day = day
        self.year = year
    }

    // Tolerant decoding, so fields added later don't break older files.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        contactID = try c.decodeIfPresent(String.self, forKey: .contactID)
        fromContacts = try c.decodeIfPresent(Bool.self, forKey: .fromContacts) ?? (contactID != nil)
        name = try c.decode(String.self, forKey: .name)
        shortName = try c.decodeIfPresent(String.self, forKey: .shortName) ?? name
        month = try c.decode(Int.self, forKey: .month)
        day = try c.decode(Int.self, forKey: .day)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        hasPhoto = try c.decodeIfPresent(Bool.self, forKey: .hasPhoto) ?? false
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        reminders = try c.decodeIfPresent([Int].self, forKey: .reminders)
        modified = try c.decodeIfPresent(Date.self, forKey: .modified) ?? .distantPast
    }

    var isManual: Bool { !fromContacts }

    /// Same person and day, for matching birthdays across devices.
    func matches(name other: String, month m: Int, day d: Int) -> Bool {
        month == m && day == d && name.compare(other, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}

/// Everything the app stores. One JSON file in the App Group, read by the widgets too.
nonisolated struct AppData: Codable, Sendable {
    var birthdays: [Birthday] = []
    var defaultReminders: [Int] = [7, 0]
    var reminderHour = 9
    var reminderMinute = 0
    /// Last contacts sync on this device.
    var lastSync: Date?
    /// Last change of the reminder settings, for resolving conflicts with iCloud.
    var settingsModified = Date.distantPast

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        birthdays = try c.decodeIfPresent([Birthday].self, forKey: .birthdays) ?? []
        defaultReminders = try c.decodeIfPresent([Int].self, forKey: .defaultReminders) ?? [7, 0]
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 9
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        lastSync = try c.decodeIfPresent(Date.self, forKey: .lastSync)
        settingsModified = try c.decodeIfPresent(Date.self, forKey: .settingsModified) ?? .distantPast
    }

    func reminders(for b: Birthday) -> [Int] { b.reminders ?? defaultReminders }

    /// Visible birthdays by next occurrence, then name.
    func upcoming(from now: Date = .now) -> [Upcoming] {
        birthdays.filter { !$0.hidden }
            .map { Upcoming($0, from: now) }
            .sorted { ($0.days, $0.birthday.name) < ($1.days, $1.birthday.name) }
    }
}

/// A birthday together with its next date, as seen from a given day.
nonisolated struct Upcoming: Identifiable, Hashable, Sendable {
    let birthday: Birthday
    let date: Date
    /// 0 = today.
    let days: Int
    /// Age on that birthday, if the year is known.
    let age: Int?

    var id: UUID { birthday.id }

    init(_ b: Birthday, from now: Date) {
        let cal = Calendar.birthdays
        let today = cal.startOfDay(for: now)
        let date = b.next(onOrAfter: today)
        birthday = b
        self.date = date
        days = cal.dateComponents([.day], from: today, to: date).day ?? 0
        age = b.age(on: date)
    }
}

nonisolated extension Calendar {
    /// Birthdays are Gregorian dates in the local time zone, whatever calendar the device uses.
    static var birthdays: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.locale = .current
        return c
    }
}

nonisolated extension Birthday {
    /// The birthday in a given year. Feb 29 falls on Feb 28 in common years.
    func date(in year: Int, calendar cal: Calendar = .birthdays) -> Date {
        var d = day
        if month == 2, day == 29, !Self.isLeap(year) { d = 28 }
        return cal.date(from: DateComponents(year: year, month: month, day: d)) ?? .distantFuture
    }

    /// The next birthday on or after the day of `ref`.
    func next(onOrAfter ref: Date, calendar cal: Calendar = .birthdays) -> Date {
        let today = cal.startOfDay(for: ref)
        let year = cal.component(.year, from: today)
        let this = date(in: year, calendar: cal)
        return this >= today ? this : date(in: year + 1, calendar: cal)
    }

    func age(on date: Date) -> Int? {
        guard let year else { return nil }
        let age = Calendar.birthdays.component(.year, from: date) - year
        return age > 0 ? age : nil
    }

    /// A date in a leap year, for showing month and day without a year.
    var displayDate: Date { date(in: year ?? 2000) }

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    var initials: String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
