import Foundation
import Observation
import UserNotifications
import WidgetKit

/// The app's copy of the data. Every change is saved right away, reloads the widgets
/// and reschedules the reminders.
@Observable
final class Store {
    private(set) var data = Storage.load()
    private(set) var notifications: UNAuthorizationStatus = .authorized

    var visible: [Upcoming] { data.upcoming() }

    var hidden: [Birthday] {
        data.birthdays.filter(\.hidden).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func birthday(_ id: UUID) -> Birthday? { data.birthdays.first { $0.id == id } }

    /// Re-reads the file, e.g. when the app comes back to the foreground.
    func reload() { data = Storage.load() }

    // MARK: Changes

    func setHidden(_ id: UUID, _ hidden: Bool) {
        change(id) { $0.hidden = hidden }
    }

    func setReminders(_ id: UUID, _ reminders: [Int]?) {
        change(id) { $0.reminders = reminders }
    }

    func setDefaultReminders(_ list: [Int]) {
        data.defaultReminders = list.sorted(by: >)
        save()
    }

    func setReminderTime(hour: Int, minute: Int) {
        data.reminderHour = hour
        data.reminderMinute = minute
        save()
    }

    /// Adds or updates a birthday entered by hand.
    func saveManual(_ b: Birthday) {
        if let i = data.birthdays.firstIndex(where: { $0.id == b.id }) {
            data.birthdays[i] = b
        } else {
            data.birthdays.append(b)
        }
        save()
    }

    func delete(_ id: UUID) {
        data.birthdays.removeAll { $0.id == id }
        Storage.removePhoto(id)
        save()
    }

    // MARK: Contacts sync

    struct SyncResult {
        var updated = 0
        var removed: [String] = []
        /// Contacts with a birthday that are neither in the list nor hidden yet.
        var new: [ContactBirthday] = []
    }

    /// Updates birthdays that came from contacts, drops those whose contact or birthday
    /// is gone, and returns the contacts that are new. Hidden birthdays are updated too,
    /// but stay hidden.
    func sync(with contacts: [ContactBirthday], limited: Bool) -> SyncResult {
        var result = SyncResult()
        let byID = Dictionary(contacts.map { ($0.contactID, $0) }, uniquingKeysWith: { a, _ in a })
        var known = Set<String>()

        for i in data.birthdays.indices {
            guard let cid = data.birthdays[i].contactID else { continue }
            guard let c = byID[cid] else { continue }
            known.insert(cid)
            var b = data.birthdays[i]
            let before = b
            b.name = c.name
            b.shortName = c.shortName
            b.month = c.month
            b.day = c.day
            b.year = c.year
            b.hasPhoto = Storage.savePhoto(c.photo, for: b.id)
            if b != before { result.updated += 1 }
            data.birthdays[i] = b
        }

        // With limited access the app only sees some contacts; the others aren't gone.
        if !limited {
            let gone = data.birthdays.filter { $0.contactID.map { byID[$0] == nil } ?? false }
            result.removed = gone.filter { !$0.hidden }.map(\.name)
            for b in gone { Storage.removePhoto(b.id) }
            data.birthdays.removeAll { b in gone.contains { $0.id == b.id } }
        }

        result.new = contacts.filter { !known.contains($0.contactID) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        data.lastSync = .now
        save()
        return result
    }

    /// Adds new contacts: the chosen ones to the list, the others straight to hidden,
    /// so the next sync doesn't offer them again.
    func add(_ contacts: [ContactBirthday], chosen: Set<String>) {
        for c in contacts where !data.birthdays.contains(where: { $0.contactID == c.contactID }) {
            var b = Birthday(contactID: c.contactID, name: c.name, shortName: c.shortName,
                             month: c.month, day: c.day, year: c.year)
            b.hidden = !chosen.contains(c.contactID)
            b.hasPhoto = Storage.savePhoto(c.photo, for: b.id)
            data.birthdays.append(b)
        }
        save()
    }

    // MARK: Saving

    private func change(_ id: UUID, _ edit: (inout Birthday) -> Void) {
        guard let i = data.birthdays.firstIndex(where: { $0.id == id }) else { return }
        edit(&data.birthdays[i])
        save()
    }

    private func save() {
        try? Storage.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        let snapshot = data
        let previous = rescheduling
        rescheduling = Task {
            await previous?.value  // one at a time, so remove/add don't interleave
            await Reminders.reschedule(snapshot)
        }
    }

    @ObservationIgnored private var rescheduling: Task<Void, Never>?

    /// Tops up the reminders and checks whether notifications are allowed;
    /// called whenever the app becomes active.
    func refreshReminders() async {
        notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        await Reminders.reschedule(data)
    }

    /// Asks for permission if it wasn't asked yet, then schedules.
    func requestNotifications() async {
        _ = await Reminders.requestPermission()
        await refreshReminders()
    }
}
