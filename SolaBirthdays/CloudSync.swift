import CloudKit
import Foundation
import Observation
import UIKit

/// The app's side of iCloud sync: turns local items into records and back.
protocol CloudSyncStore: AnyObject {
    /// The record to upload for a local item, built on `existing` (the last known server
    /// version) if there is one. nil if the item doesn't exist anymore.
    func record(for id: CKRecord.ID, existing: CKRecord?) -> CKRecord?
    /// Applies a record from iCloud unless the local item was changed more recently.
    /// Returns true if the local item is newer and should be uploaded again.
    func merge(_ record: CKRecord) -> Bool
    /// The record was deleted in iCloud.
    func remove(_ id: CKRecord.ID)
    /// Names of all local records, uploaded when sync is turned on.
    func allRecordNames() -> [String]
    /// Called after a round of changes from iCloud has been applied.
    func didApplyChanges()
}

/// Opt-in sync with the user's private iCloud database (CKSyncEngine).
///
/// Off until the user turns it on in the settings. While it's off nothing here talks to
/// iCloud: no engine, no account check, no push registration. All records live in one
/// record zone, so turning sync off can remove everything with a single zone deletion.
///
/// Conflicts: the more recently changed side wins; the store decides by its own timestamps.
/// Leaving iCloud (sign-out, other account, data deleted elsewhere) turns sync off and keeps
/// the data on the device.
@Observable
final class CloudSync {
    enum Status: Equatable {
        case off
        case syncing
        case upToDate
        case problem(String)
    }

    /// The iCloud container from the build settings; empty when built without iCloud.
    static let containerID = Bundle.main.object(forInfoDictionaryKey: "SolaCloudKitContainer") as? String ?? ""
    /// Whether this build can sync at all (SOLA_ICLOUD = YES).
    static var isAvailable: Bool { !containerID.isEmpty }

    private(set) var isOn: Bool
    private(set) var status: Status
    private(set) var lastSync: Date?

    @ObservationIgnored private let zoneID: CKRecordZone.ID
    @ObservationIgnored private let stateURL: URL
    @ObservationIgnored private var saved: Saved
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private weak var store: CloudSyncStore?

    /// What survives a restart: whether sync is on, the engine's state and the server's
    /// version info for every record (so uploads don't run into conflicts).
    private struct Saved: Codable {
        var on = false
        var engine: CKSyncEngine.State.Serialization?
        var systemFields: [String: Data] = [:]
        var lastSync: Date?
    }

    /// - Parameters:
    ///   - zone: name of the record zone, one per app.
    ///   - folder: where to keep the sync state (not synced itself).
    init(zone: String, folder: URL) {
        zoneID = CKRecordZone.ID(zoneName: zone, ownerName: CKCurrentUserDefaultName)
        stateURL = folder.appending(path: "CloudSync.json")
        let s = (try? Data(contentsOf: stateURL)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } ?? Saved()
        saved = Self.isAvailable ? s : Saved()
        isOn = saved.on
        lastSync = saved.lastSync
        status = saved.on ? .syncing : .off
    }

    /// Connects the store and, if sync is on, starts syncing.
    func attach(_ store: CloudSyncStore) {
        self.store = store
        if isOn { start() }
    }

    func recordID(_ name: String) -> CKRecord.ID { CKRecord.ID(recordName: name, zoneID: zoneID) }

    // MARK: Local changes

    /// Queues local items for upload. Does nothing while sync is off.
    func changed(_ names: [String]) {
        guard let engine, !names.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: names.map { .saveRecord(recordID($0)) })
    }

    /// Queues local deletions. Does nothing while sync is off.
    func deleted(_ names: [String]) {
        guard let engine, !names.isEmpty else { return }
        let ids = names.map(recordID)
        engine.state.remove(pendingRecordZoneChanges: ids.map { .saveRecord($0) })
        engine.state.add(pendingRecordZoneChanges: ids.map { .deleteRecord($0) })
        for name in names { saved.systemFields[name] = nil }
        persist()
    }

    // MARK: Turning it on and off

    /// Checks the iCloud account, then merges what's in iCloud with what's on the device.
    func turnOn() async {
        guard Self.isAvailable, !isOn, store != nil else { return }
        status = .syncing
        do {
            switch try await CKContainer(identifier: Self.containerID).accountStatus() {
            case .available:
                break
            case .noAccount:
                status = .problem(String(localized: "Sign in to iCloud in the Settings app first."))
                return
            case .restricted:
                status = .problem(String(localized: "iCloud is restricted on this device."))
                return
            default:
                status = .problem(String(localized: "iCloud isn’t available right now. Try again later."))
                return
            }
        } catch {
            status = .problem(error.localizedDescription)
            return
        }

        saved = Saved()
        saved.on = true
        isOn = true
        persist()
        start()
        guard let engine else { return }
        do {
            // Fetch first, so items that are already in iCloud aren't uploaded again.
            try await engine.fetchChanges()
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            uploadAll(onlyNew: true)
            try await engine.sendChanges()
        } catch {
            report(error)
        }
    }

    /// Stops syncing. The data stays on this device; with `deleteFromICloud` the copy in
    /// iCloud is removed first. Returns false if that didn't work (sync then stays on).
    @discardableResult
    func turnOff(deleteFromICloud: Bool) async -> Bool {
        if deleteFromICloud {
            do {
                let db = CKContainer(identifier: Self.containerID).privateCloudDatabase
                let result = try await db.modifyRecordZones(saving: [], deleting: [zoneID])
                if case .failure(let error) = result.deleteResults[zoneID], (error as? CKError)?.code != .zoneNotFound {
                    throw error
                }
            } catch {
                status = .problem(String(localized: "Couldn’t delete the data in iCloud: \(error.localizedDescription)"))
                return false
            }
        }
        await stop()
        status = .off
        return true
    }

    /// Fetches and sends now, e.g. when the app comes to the foreground.
    func syncNow() async {
        guard let engine else { return }
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
        } catch {
            report(error)
        }
    }

    private func start() {
        guard engine == nil, Self.isAvailable else { return }
        let db = CKContainer(identifier: Self.containerID).privateCloudDatabase
        engine = CKSyncEngine(.init(database: db, stateSerialization: saved.engine, delegate: self))
        // Silent pushes tell the engine about changes from other devices. No permission prompt.
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func stop() async {
        let old = engine
        engine = nil
        await old?.cancelOperations()
        saved = Saved()
        persist()
        isOn = false
        lastSync = nil
    }

    /// Turns sync off without touching iCloud and says why.
    private func stop(because reason: String) async {
        await stop()
        status = .problem(reason)
    }

    private func uploadAll(onlyNew: Bool) {
        guard let engine, let store else { return }
        let names = store.allRecordNames().filter { !onlyNew || saved.systemFields[$0] == nil }
        engine.state.add(pendingRecordZoneChanges: names.map { .saveRecord(recordID($0)) })
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func report(_ error: Error) {
        switch (error as? CKError)?.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            status = .problem(String(localized: "Waiting for a connection to iCloud."))
        case .quotaExceeded:
            status = .problem(String(localized: "Your iCloud storage is full."))
        case .operationCancelled:
            break
        default:
            status = .problem(error.localizedDescription)
        }
    }

    private func pending(_ id: CKRecord.ID) -> Bool {
        engine?.state.pendingRecordZoneChanges.contains(.saveRecord(id)) ?? false
    }
}

// MARK: - CKSyncEngineDelegate

extension CloudSync: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard syncEngine === engine else { return }  // an engine from before sync was turned off
        switch event {
        case .stateUpdate(let update):
            saved.engine = update.stateSerialization
            persist()

        case .accountChange(let change):
            switch change.changeType {
            case .signIn:
                break
            case .signOut:
                await stop(because: String(localized: "You signed out of iCloud, so sync was turned off. Everything is still on this device."))
            case .switchAccounts:
                await stop(because: String(localized: "The iCloud account changed, so sync was turned off. Everything is still on this device."))
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let changes):
            for deletion in changes.deletions where deletion.zoneID == zoneID {
                if deletion.reason == .encryptedDataReset {
                    // The user reset their iCloud keys: the data is gone, upload it again.
                    saved.systemFields = [:]
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                    uploadAll(onlyNew: false)
                    persist()
                } else {
                    await stop(because: String(localized: "The data in iCloud was deleted, so sync was turned off. Everything is still on this device."))
                    return
                }
            }

        case .fetchedRecordZoneChanges(let changes):
            applyFetched(changes)

        case .sentDatabaseChanges(let changes):
            if let failure = changes.failedZoneSaves.first {
                report(failure.error)
            }

        case .sentRecordZoneChanges(let changes):
            handleSent(changes)

        case .willFetchChanges, .willSendChanges:
            if case .problem = status {} else { status = .syncing }

        case .didFetchChanges, .didSendChanges:
            if syncEngine.state.pendingRecordZoneChanges.isEmpty, syncEngine.state.pendingDatabaseChanges.isEmpty {
                status = .upToDate
                lastSync = .now
                saved.lastSync = lastSync
                persist()
            }

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard syncEngine === engine, let store else { return nil }
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        var toSave: [CKRecord] = []
        var toDelete: [CKRecord.ID] = []
        var gone: [CKSyncEngine.PendingRecordZoneChange] = []
        var assets = 0
        // Small batches: images make big requests, and each batch is one round trip.
        for change in changes {
            if toSave.count + toDelete.count >= 200 || assets >= 20 { break }
            switch change {
            case .saveRecord(let id):
                let existing = saved.systemFields[id.recordName].flatMap(CKRecord.init(systemFields:))
                if let record = store.record(for: id, existing: existing) {
                    toSave.append(record)
                    assets += record.allKeys().contains { record[$0] is CKAsset } ? 1 : 0
                } else {
                    gone.append(change)
                }
            case .deleteRecord(let id):
                toDelete.append(id)
            @unknown default:
                break
            }
        }
        if !gone.isEmpty { syncEngine.state.remove(pendingRecordZoneChanges: gone) }
        if toSave.isEmpty, toDelete.isEmpty { return nil }
        return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: toSave, recordIDsToDelete: toDelete)
    }

    private func applyFetched(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        guard let store, let engine else { return }
        var resend: [CKSyncEngine.PendingRecordZoneChange] = []
        var superseded: [CKSyncEngine.PendingRecordZoneChange] = []
        for modification in changes.modifications where modification.record.recordID.zoneID == zoneID {
            let record = modification.record
            saved.systemFields[record.recordID.recordName] = record.systemFields
            if store.merge(record) {
                if !pending(record.recordID) { resend.append(.saveRecord(record.recordID)) }
            } else {
                superseded.append(.saveRecord(record.recordID))
            }
        }
        for deletion in changes.deletions where deletion.recordID.zoneID == zoneID {
            saved.systemFields[deletion.recordID.recordName] = nil
            superseded.append(.saveRecord(deletion.recordID))
            store.remove(deletion.recordID)
        }
        engine.state.remove(pendingRecordZoneChanges: superseded)
        engine.state.add(pendingRecordZoneChanges: resend)
        persist()
        if !changes.modifications.isEmpty || !changes.deletions.isEmpty { store.didApplyChanges() }
    }

    private func handleSent(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) {
        guard let engine else { return }
        for record in changes.savedRecords {
            saved.systemFields[record.recordID.recordName] = record.systemFields
        }
        for id in changes.deletedRecordIDs {
            saved.systemFields[id.recordName] = nil
        }

        var resend: [CKSyncEngine.PendingRecordZoneChange] = []
        var needsZone = false
        var merged = false
        for failure in changes.failedRecordSaves {
            let id = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // Someone else changed it first: keep whichever side is newer.
                guard let server = failure.error.serverRecord else { continue }
                saved.systemFields[id.recordName] = server.systemFields
                if store?.merge(server) == true {
                    resend.append(.saveRecord(id))
                } else {
                    merged = true
                }
            case .zoneNotFound:
                needsZone = true
                saved.systemFields[id.recordName] = nil
                resend.append(.saveRecord(id))
            case .unknownItem:
                saved.systemFields[id.recordName] = nil
                resend.append(.saveRecord(id))
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .notAuthenticated, .operationCancelled, .requestRateLimited:
                break  // the engine retries these on its own
            default:
                report(failure.error)
            }
        }
        if needsZone {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        }
        engine.state.add(pendingRecordZoneChanges: resend)
        persist()
        if merged { store?.didApplyChanges() }
    }
}

// MARK: - Helpers

extension CKRecord {
    /// The server's version info for this record, without the fields.
    var systemFields: Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    convenience init?(systemFields: Data) {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: systemFields) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        self.init(coder: coder)
    }
}
