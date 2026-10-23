import SwiftUI

/// The iCloud switch: off until the user turns it on. Shows the sync status while on and,
/// when turning it off, asks whether to delete the copy in iCloud.
struct CloudSyncToggle: View {
    let sync: CloudSync

    @State private var askTurnOff = false
    @State private var working = false

    var body: some View {
        if CloudSync.isAvailable {
            Toggle("iCloud sync", isOn: Binding(get: { sync.isOn }, set: { on in
                if on { run { await sync.turnOn() } } else { askTurnOff = true }
            }))
            .disabled(working)
            .confirmationDialog("Turn off iCloud sync?", isPresented: $askTurnOff, titleVisibility: .visible) {
                Button("Keep data in iCloud") { run { await sync.turnOff(deleteFromICloud: false) } }
                Button("Delete data from iCloud", role: .destructive) { run { await sync.turnOff(deleteFromICloud: true) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everything stays on this device either way. Your other devices keep their copy too and stop syncing if you delete it.")
            }
            if sync.isOn {
                LabeledContent("Status", value: status)
            }
            if case .problem(let message) = sync.status {
                Text(message).foregroundStyle(Color.danger)
            }
        } else {
            LabeledContent("iCloud sync", value: String(localized: "Off"))
            Text("This build keeps everything on this device and can’t sync.")
                .foregroundStyle(Color.muted)
        }
    }

    private var status: String {
        switch sync.status {
        case .syncing: String(localized: "Syncing…")
        case .problem: String(localized: "Not synced")
        case .off, .upToDate:
            sync.lastSync.map { String(localized: "Synced \($0.formatted(.relative(presentation: .named)))") }
                ?? String(localized: "Up to date")
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        working = true
        Task {
            await work()
            working = false
        }
    }
}
