import CloudKit
import Foundation
import Observation
import os
import UserNotifications
import WidgetKit

/// The app's copy of the data. Every change is saved right away, reloads the widgets,
/// reschedules the reminders and, if iCloud sync is on, queues the upload.
@Observable
final class Store {
    private(set) var data: AppData
    private(set) var notifications: UNAuthorizationStatus = .authorized

    /// Opt-in iCloud sync; does nothing until the user turns it on.
    let cloud = CloudSync(zone: "Birthdays", folder: {
        let url = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }())

    /// The moment "today" and the days to go are counted from. Moves on at midnight and when
    /// the app comes back, so a window left open overnight (Mac) doesn't show yesterday.
    private(set) var now = Date.now

    /// False while the file couldn't be read (the app was started in the background before the
    /// first unlock after a restart). Until then nothing is saved and iCloud waits, so the empty
    /// list shown meanwhile never replaces the real one.
    @ObservationIgnored private var loaded = false

    init() {
        let file = Storage.loadIfReadable()
        data = file ?? AppData()
        loaded = file != nil
        if loaded { cloud.attach(self) }
        dayObserver = NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = .now }
        }
    }

    @ObservationIgnored private var dayObserver: NSObjectProtocol?

    var visible: [Upcoming] { data.upcoming(from: now) }

    var hidden: [Birthday] {
        data.birthdays.filter(\.hidden).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func birthday(_ id: UUID) -> Birthday? { data.birthdays.first { $0.id == id } }

    /// Re-reads the file when the app comes back to the foreground, and refreshes the widgets
    /// so opening the app always fixes one that missed a reload.
    func reload() {
        if let file = Storage.loadIfReadable() {
            data = file
            if !loaded {
                loaded = true
                cloud.attach(self)
            }
        }
        now = .now
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The background refresh (iPhone, about twice a day): gets the changes from iCloud, so the
    /// widgets and reminders follow changes made on another device without opening the app.
    /// Silent pushes do that too, but iOS doesn't deliver all of them.
    func backgroundRefresh() async {
        reload()
        guard loaded else { return }
        await cloud.syncNow()
        await refreshReminders()
    }

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
        b.touch()
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
            b.contactID = c.contactID
            b.fromContacts = true
            b.name = c.name
            b.shortName = c.shortName
            b.month = c.month
            b.day = c.day
            b.year = c.year
            // Only touch the photo when the contact's photo itself changed. A photo this device
            // hasn't recorded yet (it came from iCloud, or an older version saved it) is kept:
            // replacing it would upload it back and forth between the devices.
            var photoChanged = false
            let source = Self.photoSource(c.photo)
            if source != b.photoSource {
                if !(b.photoSource == nil && b.hasPhoto) {
                    b.hasPhoto = Storage.savePhoto(c.photo, for: b.id)
                    photoChanged = b.hasPhoto
                }
                b.photoSource = source
            }
            if b.synced != before.synced || photoChanged {
                b.touch()
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
        // Birthdays from iCloud (or whose contact was re-created, or added by hand): match by
        // name and date, so importing never duplicates a birthday that is already in the list.
        for i in data.birthdays.indices where !matched.contains(data.birthdays[i].id) {
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

    /// Fingerprint of a contact photo for `Birthday.photoSource`; 0 = the contact has none.
    private static func photoSource(_ photo: Data?) -> UInt32 { photo.map(stableHash) ?? 0 }

    /// Adds new contacts: the chosen ones to the list, the others straight to hidden,
    /// so the next sync doesn't offer them again.
    func add(_ contacts: [ContactBirthday], chosen: Set<String>) {
        var added: [UUID] = []
        for c in contacts where !data.birthdays.contains(where: {
            $0.contactID == c.contactID || $0.matches(name: c.name, month: c.month, day: c.day)
        }) {
            var b = Birthday(contactID: c.contactID, name: c.name, shortName: c.shortName,
                             month: c.month, day: c.day, year: c.year)
            b.hidden = !chosen.contains(c.contactID)
            b.hasPhoto = Storage.savePhoto(c.photo, for: b.id)
            b.photoSource = Self.photoSource(c.photo)
            data.birthdays.append(b)
            added.append(b.id)
        }
        save(changed: added)
    }

    // MARK: Saving

    private func change(_ id: UUID, _ edit: (inout Birthday) -> Void) {
        guard let i = data.birthdays.firstIndex(where: { $0.id == id }) else { return }
        edit(&data.birthdays[i])
        data.birthdays[i].touch()
        save(changed: [id])
    }

    private func settingsChanged() {
        data.touchSettings()
        save()
        cloud.changed([Self.settingsRecord])
    }

    private func save(changed: [UUID] = [], deleted: [UUID] = []) {
        saveLocally()
        cloud.changed(changed.map(\.uuidString))
        cloud.deleted(deleted.map(\.uuidString))
    }

    private func saveLocally() {
        guard loaded else { return }
        do {
            try Storage.save(data)
        } catch {
            // The widgets and the next launch would read the old file.
            Self.log.error("Saving the birthdays failed: \(error.localizedDescription, privacy: .public)")
        }
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

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SolaBirthdays", category: "Store")

    /// Tops up the reminders and checks whether notifications are allowed;
    /// called whenever the app becomes active.
    func refreshReminders() async {
        #if DEBUG
        if Storage.demoFolder != nil { return }  // screenshots: no "Reminders are off" banner
        #endif
        notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard loaded else { return }  // an empty list would cancel all reminders
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

        let remoteReminders = (e["reminders"] as? Data).flatMap { try? JSONDecoder().decode([Int].self, from: $0) }
        var index = data.birthdays.firstIndex { $0.id == uuid }
        if let i = index, data.birthdays[i].modified > remote { return true }
        var loser: Birthday?
        if index == nil, let twin = data.birthdays.firstIndex(where: { $0.matches(name: name, month: month, day: day) }) {
            // The same birthday was added on two devices before syncing. Every device keeps the
            // copy with the smaller ID and deletes the other. If each kept the one from iCloud
            // instead, two devices could delete each other's copy and lose it on both.
            let local = data.birthdays[twin]
            if local.id.uuidString < uuid.uuidString {
                cloud.deleted([uuid.uuidString])
                var b = local
                b.inherit(hidden: r["hidden"] as? Bool ?? false, reminders: remoteReminders)
                if b.synced != local.synced {
                    b.touch()
                    data.birthdays[twin] = b
                    cloud.changed([b.id.uuidString])
                }
                return false
            }
            loser = local
            Storage.removePhoto(local.id)
            data.birthdays[twin].id = uuid
            cloud.deleted([local.id.uuidString])
            index = twin
        }

        var b = index.map { data.birthdays[$0] } ?? Birthday(name: name, shortName: name, month: month, day: day, year: nil)
        b.id = uuid
        b.name = name
        b.shortName = e["shortName"] as? String ?? name
        b.month = month
        b.day = day
        b.year = e["year"] as? Int
        b.reminders = remoteReminders
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
        var upload = false
        if let loser {
            let before = b.synced
            b.inherit(hidden: loser.hidden, reminders: loser.reminders)
            upload = b.synced != before
            if upload { b.touch() }
        }
        if let i = index { data.birthdays[i] = b } else { data.birthdays.append(b) }
        return upload
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

    /// What the surviving copy of a birthday added on two devices takes from the other one.
    /// Both devices end up with the same result, whichever copy they had. Hiding is a choice;
    /// showing is just the default for new birthdays. Own reminders beat the defaults.
    mutating func inherit(hidden: Bool, reminders: [Int]?) {
        self.hidden = self.hidden || hidden
        self.reminders = self.reminders ?? reminders
    }
}
