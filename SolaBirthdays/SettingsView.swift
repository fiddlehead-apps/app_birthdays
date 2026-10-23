import SwiftUI

struct SettingsView: View {
    let store: Store

    var body: some View {
        // Own view for the form so it observes the store (see DetailView).
        NavigationStack { SettingsForm(store: store) }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }
}

private struct SettingsForm: View {
    let store: Store

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                ForEach(Reminders.choices, id: \.self) { offset in
                    Toggle(Texts.offset(offset), isOn: Binding(
                        get: { store.data.defaultReminders.contains(offset) },
                        set: { on in
                            var list = store.data.defaultReminders.filter { $0 != offset }
                            if on { list.append(offset) }
                            store.setDefaultReminders(list)
                        }))
                }
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
            } header: {
                Text("Reminders")
            } footer: {
                if store.notifications == .denied {
                    Button("Notifications are off for this app. Turn them on in Settings.") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .foregroundStyle(Color.danger)
                } else {
                    Text("Applies to every birthday without its own reminders.")
                }
            }

            Section {
                NavigationLink {
                    HiddenView(store: store, standalone: false)
                } label: {
                    LabeledContent("Hidden birthdays", value: "\(store.hidden.count)")
                }
                if let last = store.data.lastSync {
                    LabeledContent("Last sync", value: last.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Text("Contacts")
            } footer: {
                Text("Sync only runs when you tap the sync button. Hidden birthdays stay hidden.")
            }

            Section {
                CloudSyncToggle(sync: store.cloud)
            } header: {
                Text("iCloud")
            } footer: {
                Text("Off unless you turn it on. Then your birthdays, their photos and the reminder settings sync through your private iCloud database to your devices with the same Apple Account. Each device sends its own reminders.")
            }

            Section {
                Text("Your contacts stay on your devices. Nothing goes to a server of ours, there is no account and nothing is tracked.")
                    .foregroundStyle(Color.muted)
                LabeledContent("Version", value: SettingsView.version)
            } header: {
                Text("About")
            }
        }
        .tint(Color.brand)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { await store.refreshReminders() }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: store.data.reminderHour, minute: store.data.reminderMinute,
                                      second: 0, of: .now) ?? .now
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                store.setReminderTime(hour: c.hour ?? 9, minute: c.minute ?? 0)
            })
    }
}

/// All hidden birthdays, to bring them back.
struct HiddenView: View {
    let store: Store
    /// Presented as its own sheet (needs a Done button) or pushed from the settings.
    let standalone: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        let all = store.hidden
        let shown = search.isEmpty ? all : all.filter { $0.name.localizedStandardContains(search) }
        List {
            if all.isEmpty {
                Text("No hidden birthdays.")
                    .foregroundStyle(Color.muted)
                    .plainRow(top: 20, bottom: 8)
            } else {
                Text("Hidden birthdays get no reminders and don’t show up in the list or the widgets. Sync doesn’t bring them back.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .plainRow(top: 8, bottom: 10)
            }
            ForEach(shown) { b in
                HStack(spacing: 12) {
                    Avatar(birthday: b, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        Text(Texts.dayMonth(b.displayDate))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.muted)
                    }
                    Spacer(minLength: 8)
                    Button {
                        withAnimation { store.setHidden(b.id, false) }
                    } label: {
                        Label("Show", systemImage: "eye")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.brandSoft, in: .capsule)
                            .foregroundStyle(Color.brand)
                    }
                    .buttonStyle(.borderless)
                }
                .foregroundStyle(Color.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.surface, in: .rect(cornerRadius: 14))
                .plainRow(top: 3, bottom: 3)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .searchable(text: $search)
        .navigationTitle("Hidden")
        .toolbar {
            if standalone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
