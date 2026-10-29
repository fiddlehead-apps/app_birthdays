import CloudKit
import Foundation
import Observation
import UserNotifications
import WidgetKit

/// The app's copy of the data. Every change is saved right away, reloads the widgets,
/// reschedules the reminders and, if iCloud sync is on, queues the upload.
@Observable
final class Store {
    private(set) var data = Storage.load()
    private(set) var notifications: UNAuthorizationStatus = .authorized

    /// Opt-in iCloud sync; does nothing until the user turns it on.
    let cloud = CloudSync(zone: "Birthdays", folder: {
        let url = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }())

    init() {
        cloud.attach(self)
    }

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
        settingsChanged()
    }

    func setReminderTime(hour: Int, minute: Int) {
        data.reminderHour = hour
        data.reminderMinute = minute
        settingsChanged()
    }

    /// Adds or updates a birthday entered by hand.
    func saveManual(_ b: Birthday) {
        var b = b
        b.modified = .now
        if let i = data.birthdays.firstIndex(where: { $0.id == b.id }) {
            data.birthdays[i] = b
        } else {
            data.birthdays.append(b)
        }
        save(changed: [b.id])
    }

    func delete(_ id: UUID) {
        data.birthdays.removeAll { $0.id == id }
        Storage.removePhoto(id)
        save(deleted: [id])
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
        var matched = Set<UUID>()
        var changed: [UUID] = []

        func update(_ i: Int, from c: ContactBirthday) {
            known.insert(c.contactID)
            matched.insert(data.birthdays[i].id)
            var b = data.birthdays[i]
            let before = b
            let photoBefore = try? Data(contentsOf: Storage.photoURL(b.id))
            b.contactID = c.contactID
            b.name = c.name
            b.shortName = c.shortName
            b.month = c.month
            b.day = c.day
            b.year = c.year
            b.hasPhoto = Storage.savePhoto(c.photo, for: b.id)
            let photoChanged = b.hasPhoto && photoBefore != (try? Data(contentsOf: Storage.photoURL(b.id)))
            if b.synced != before.synced || photoChanged {
                b.modified = .now
                changed.append(b.id)
                result.updated += 1
            }
            data.birthdays[i] = b
        }

        // Birthdays this device already knows the contact of.
        for i in data.birthdays.indices {
            guard let cid = data.birthdays[i].contactID, let c = byID[cid] else { continue }
            update(i, from: c)
        }
        // Birthdays from iCloud (or whose contact was re-created): match by name and date.
        for i in data.birthdays.indices where data.birthdays[i].fromContacts && !matched.contains(data.birthdays[i].id) {
            let b = data.birthdays[i]
            if let c = contacts.first(where: { !known.contains($0.contactID) && b.matches(name: $0.name, month: $0.month, day: $0.day) }) {
                update(i, from: c)
            }
        }

        // With limited access the app only sees some contacts; the others aren't gone. Birthdays
        // that never had a contact on this device (they came from iCloud) aren't gone either.
        var deleted: [UUID] = []
        if !limited {
            let gone = data.birthdays.filter { $0.fromContacts && $0.contactID != nil && !matched.contains($0.id) }
            result.removed = gone.filter { !$0.hidden }.map(\.name)
            for b in gone { Storage.removePhoto(b.id) }
            data.birthdays.removeAll { b in gone.contains { $0.id == b.id } }
            deleted = gone.map(\.id)
        }

        result.new = contacts.filter { !known.contains($0.contactID) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        data.lastSync = .now
        save(changed: changed, deleted: deleted)
        return result
    }

    /// Adds new contacts: the chosen ones to the list, the others straight to hidden,
    /// so the next sync doesn't offer them again.
    func add(_ contacts: [ContactBirthday], chosen: Set<String>) {
        var added: [UUID] = []
        for c in contacts where !data.birthdays.contains(where: { $0.contactID == c.contactID }) {
            var b = Birthday(contactID: c.contactID, name: c.name, shortName: c.shortName,
                             month: c.month, day: c.day, year: c.year)
            b.hidden = !chosen.contains(c.contactID)
            b.hasPhoto = Storage.savePhoto(c.photo, for: b.id)
            data.birthdays.append(b)
            added.append(b.id)
        }
        save(changed: added)
    }

    // MARK: Saving

    private func change(_ id: UUID, _ edit: (inout Birthday) -> Void) {
        guard let i = data.birthdays.firstIndex(where: { $0.id == id }) else { return }
        edit(&data.birthdays[i])
        data.birthdays[i].modified = .now
        save(changed: [id])
    }

    private func settingsChanged() {
        data.settingsModified = .now
        save()
        cloud.changed([Self.settingsRecord])
    }

    private func save(changed: [UUID] = [], deleted: [UUID] = []) {
        saveLocally()
        cloud.changed(changed.map(\.uuidString))
        cloud.deleted(deleted.map(\.uuidString))
    }

    private func saveLocally() {
        try? Storage.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        reschedule()
    }

    /// Queues a reschedule of the current data. One at a time, so remove/add don't interleave.
    @discardableResult
    private func reschedule() -> Task<Void, Never> {
        let snapshot = data
        let previous = rescheduling
        let task = Task {
            await previous?.value
            await Reminders.reschedule(snapshot)
        }
        rescheduling = task
        return task
    }

    @ObservationIgnored private var rescheduling: Task<Void, Never>?

    /// Tops up the reminders and checks whether notifications are allowed;
    /// called whenever the app becomes active.
    func refreshReminders() async {
        notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        await reschedule().value
    }

    /// Asks for permission if it wasn't asked yet, then schedules.
    func requestNotifications() async {
        _ = await Reminders.requestPermission()
        await refreshReminders()
    }
}

// MARK: - iCloud

/// Records: one "Birthday" per birthday (named by its UUID, photo as asset) and one
/// "Settings" for the reminder defaults. Contact IDs and the last contacts sync stay local.
extension Store: CloudSyncStore {
    static let settingsRecord = "settings"

    func allRecordNames() -> [String] {
        [Self.settingsRecord] + data.birthdays.map(\.id.uuidString)
    }

    func record(for id: CKRecord.ID, existing: CKRecord?) -> CKRecord? {
        if id.recordName == Self.settingsRecord {
            let r = existing ?? CKRecord(recordType: "Settings", recordID: id)
            r.encryptedValues["defaultReminders"] = data.defaultReminders
            r.encryptedValues["reminderHour"] = data.reminderHour
            r.encryptedValues["reminderMinute"] = data.reminderMinute
            r["modified"] = data.settingsModified
            return r
        }
        guard let uuid = UUID(uuidString: id.recordName), let b = birthday(uuid) else { return nil }
        let r = existing ?? CKRecord(recordType: "Birthday", recordID: id)
        let e = r.encryptedValues
        e["name"] = b.name
        e["shortName"] = b.shortName
        e["month"] = b.month
        e["day"] = b.day
        e["year"] = b.year
        let reminders: Data? = b.reminders.flatMap { try? JSONEncoder().encode($0) }
        e["reminders"] = reminders
        r["fromContacts"] = b.fromContacts
        r["hidden"] = b.hidden
        r["modified"] = b.modified
        let photo = Storage.photoURL(uuid)
        r["photo"] = b.hasPhoto && FileManager.default.fileExists(atPath: photo.path(percentEncoded: false)) ? CKAsset(fileURL: photo) : nil
        return r
    }

    func merge(_ r: CKRecord) -> Bool {
        let remote = r["modified"] as? Date ?? .distantPast
        if r.recordID.recordName == Self.settingsRecord {
            if data.settingsModified > remote { return true }
            let e = r.encryptedValues
            data.defaultReminders = e["defaultReminders"] as? [Int] ?? data.defaultReminders
            data.reminderHour = e["reminderHour"] as? Int ?? data.reminderHour
            data.reminderMinute = e["reminderMinute"] as? Int ?? data.reminderMinute
            data.settingsModified = remote
            return false
        }
        guard let uuid = UUID(uuidString: r.recordID.recordName) else { return false }
        let e = r.encryptedValues
        guard let name = e["name"] as? String, let month = e["month"] as? Int, let day = e["day"] as? Int else { return false }

        var index = data.birthdays.firstIndex { $0.id == uuid }
        if let i = index, data.birthdays[i].modified > remote { return true }
        if index == nil, let twin = data.birthdays.firstIndex(where: { $0.matches(name: name, month: month, day: day) }) {
            // The same birthday was added on two devices before syncing: keep the iCloud one.
            let old = data.birthdays[twin].id
            Storage.removePhoto(old)
            data.birthdays[twin].id = uuid
            cloud.deleted([old.uuidString])
            index = twin
        }

        var b = index.map { data.birthdays[$0] } ?? Birthday(name: name, shortName: name, month: month, day: day, year: nil)
        b.id = uuid
        b.name = name
        b.shortName = e["shortName"] as? String ?? name
        b.month = month
        b.day = day
        b.year = e["year"] as? Int
        b.reminders = (e["reminders"] as? Data).flatMap { try? JSONDecoder().decode([Int].self, from: $0) }
        b.fromContacts = r["fromContacts"] as? Bool ?? false
        b.hidden = r["hidden"] as? Bool ?? false
        b.modified = remote
        if let file = (r["photo"] as? CKAsset)?.fileURL {
            Storage.removePhoto(uuid)
            b.hasPhoto = (try? FileManager.default.copyItem(at: file, to: Storage.photoURL(uuid))) != nil
        } else {
            Storage.removePhoto(uuid)
            b.hasPhoto = false
        }
        if let i = index { data.birthdays[i] = b } else { data.birthdays.append(b) }
        return false
    }

    func remove(_ id: CKRecord.ID) {
        guard let uuid = UUID(uuidString: id.recordName) else { return }
        data.birthdays.removeAll { $0.id == uuid }
        Storage.removePhoto(uuid)
    }

    func didApplyChanges() {
        saveLocally()
    }
}

private extension Birthday {
    /// The fields that sync; a change in any of them is worth an upload.
    var synced: [AnyHashable] { [name, shortName, month, day, year, hasPhoto, hidden, reminders, fromContacts] }
}
