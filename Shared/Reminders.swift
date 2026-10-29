import Foundation
import UniformTypeIdentifiers
import UserNotifications

/// Local notifications before and on birthdays.
///
/// iOS keeps at most 64 pending notifications per app, so only the soonest ones are
/// scheduled. The app (on every change, at launch and in background refresh) and the
/// widgets (once a day) top the queue up again.
nonisolated enum Reminders {
    /// Offsets offered in the settings, in days before the birthday.
    static let choices = [30, 14, 7, 3, 2, 1, 0]
    private static let prefix = "birthday."
    private static let limit = 60

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isAllowed() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return s == .authorized || s == .provisional || s == .ephemeral
    }

    static func reschedule(_ data: AppData, now: Date = .now) async {
        guard await isAllowed() else { return }
        let center = UNUserNotificationCenter.current()
        let planned = Array(plan(data, now: now).prefix(limit))
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard Set(pending) != Set(planned.map(\.id)) else { return }

        center.removePendingNotificationRequests(withIdentifiers: pending)
        for p in planned {
            try? await center.add(UNNotificationRequest(identifier: p.id, content: content(p),
                                                        trigger: trigger(p.fire)))
        }
    }

    struct Planned {
        let birthday: Birthday
        let birthdayDate: Date
        let offset: Int
        let fire: Date

        /// Changes whenever anything shown in the notification changes (name, age, language,
        /// photo) or the device calendar its trigger is written in.
        var id: String {
            let t = texts
            let shown = [t.title, t.subtitle, t.body, "\(birthday.hasPhoto)", "\(Calendar.current.identifier)"]
            return "\(Reminders.prefix)\(birthday.id.uuidString).\(Int(fire.timeIntervalSince1970)).\(stableHash(shown.joined(separator: "|")))"
        }

        var texts: (title: String, subtitle: String, body: String) {
            let age = birthday.age(on: birthdayDate)
            if offset == 0 {
                let body = if let age {
                    String(localized: "Turns \(age) today.", comment: "Notification on the birthday, age known")
                } else {
                    String(localized: "Don’t forget to congratulate.", comment: "Notification on the birthday, age unknown")
                }
                return (birthday.name, String(localized: "Birthday today 🎂", comment: "Notification subtitle on the birthday"), body)
            }
            let date = Texts.weekdayDayMonth(birthdayDate)
            let body = if let age {
                String(localized: "Birthday on \(date) – turns \(age).", comment: "Notification before the birthday, age known")
            } else {
                String(localized: "Birthday on \(date).", comment: "Notification before the birthday, age unknown")
            }
            return (birthday.name, Texts.days(offset), body)
        }
    }

    /// Every reminder still to come, soonest first.
    static func plan(_ data: AppData, now: Date) -> [Planned] {
        let cal = Calendar.birthdays
        var out: [Planned] = []
        for b in data.birthdays where !b.hidden {
            for offset in Set(data.reminders(for: b)) {
                var date = b.next(onOrAfter: now)
                for _ in 0..<2 {
                    if let day = cal.date(byAdding: .day, value: -offset, to: date),
                       let fire = cal.date(bySettingHour: data.reminderHour, minute: data.reminderMinute, second: 0, of: day),
                       fire > now {
                        out.append(Planned(birthday: b, birthdayDate: date, offset: offset, fire: fire))
                        break
                    }
                    date = b.date(in: cal.component(.year, from: date) + 1)
                }
            }
        }
        return out.sorted { $0.fire < $1.fire }
    }

    private static func content(_ p: Planned) -> UNNotificationContent {
        let b = p.birthday
        let c = UNMutableNotificationContent()
        (c.title, c.subtitle, c.body) = p.texts
        c.threadIdentifier = "birthdays"
        c.sound = .default
        c.userInfo = ["birthday": b.id.uuidString]
        if b.hasPhoto, let a = photoAttachment(b.id) { c.attachments = [a] }
        return c
    }

    /// Written in the device's calendar, which is how iOS reads trigger components without one.
    /// (Gregorian numbers would land centuries off with a Japanese or Buddhist calendar.) No time
    /// zone, so the reminder follows the device when it travels.
    private static func trigger(_ fire: Date) -> UNCalendarNotificationTrigger {
        let comps = Calendar.current.dateComponents([.era, .year, .month, .day, .hour, .minute], from: fire)
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }

    /// The system moves attachment files into its own store, so hand it a copy.
    private static func photoAttachment(_ id: UUID) -> UNNotificationAttachment? {
        let copy = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).jpg")
        guard (try? FileManager.default.copyItem(at: Storage.photoURL(id), to: copy)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "photo", url: copy,
                                             options: [UNNotificationAttachmentOptionsTypeHintKey: UTType.jpeg.identifier])
    }
}

/// djb2; `String.hashValue` changes on every launch.
nonisolated func stableHash(_ s: String) -> UInt32 {
    s.unicodeScalars.reduce(UInt32(5381)) { ($0 &<< 5) &+ $0 &+ $1.value }
}
