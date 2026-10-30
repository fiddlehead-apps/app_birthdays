import SwiftUI

/// Reads the contacts, updates known birthdays and lets you pick which new ones to add.
struct SyncView: View {
    let store: Store

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var phase = Phase.loading
    @State private var chosen: Set<String> = []
    @State private var limited = false

    enum Phase {
        case loading, denied
        case failed(String)
        case review(Store.SyncResult)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView("Reading contacts …")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .denied:
                    message(icon: "person.crop.circle.badge.xmark",
                            title: "No access to contacts",
                            text: Text("Allow access in Settings to import birthdays from your contacts.")) {
                        Button("Open Settings") {
                            if let url = SystemSettings.contacts { openURL(url) }
                        }
                        .buttonStyle(BigButtonStyle(primary: true))
                    }
                case .failed(let error):
                    message(icon: "exclamationmark.triangle", title: "Couldn’t read contacts", text: Text(verbatim: error)) {
                        EmptyView()
                    }
                case .review(let result):
                    review(result)
                }
            }
            .background(Color.bg)
            .navigationTitle("Sync with contacts")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await run() }
    }

    private func run() async {
        let access = await ContactsReader.requestAccess()
        guard access != .denied else { phase = .denied; return }
        limited = access == .limited
        do {
            let contacts = try await Task.detached { try ContactsReader.readAll() }.value
            let result = store.sync(with: contacts, limited: limited)
            chosen = Set(result.new.map(\.contactID))
            phase = .review(result)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Review

    @ViewBuilder
    private func review(_ r: Store.SyncResult) -> some View {
        if r.new.isEmpty {
            message(icon: "checkmark.circle", title: "Everything is up to date", text: nil) {
                summary(r)
                Button("Done") { dismiss() }
                    .buttonStyle(BigButtonStyle(primary: true))
            }
        } else {
            List {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(r.new.count) new birthdays")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(-0.6)
                    Text("Pick the ones you want in your list.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.muted)
                    summary(r)
                    let all = chosen.count == r.new.count
                    Button(all ? LocalizedStringKey("Select none") : LocalizedStringKey("Select all")) {
                        chosen = all ? [] : Set(r.new.map(\.contactID))
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .buttonStyle(.borderless)
                    .padding(.top, 6)
                }
                .foregroundStyle(Color.ink)
                .plainRow(top: 12, bottom: 10)

                ForEach(r.new) { c in
                    candidateRow(c).plainRow(top: 3, bottom: 3)
                }

                Text("Birthdays you don’t pick go to Hidden, so they aren’t offered again. You can show them any time.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .plainRow(top: 14, bottom: 20)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.add(r.new, chosen: chosen)
                    Task { await store.requestNotifications() }
                    dismiss()
                } label: {
                    if chosen.isEmpty { Text("Hide all") } else { Text("Add \(chosen.count) birthdays") }
                }
                .buttonStyle(BigButtonStyle(primary: true))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.bg)
            }
        }
    }

    private func candidateRow(_ c: ContactBirthday) -> some View {
        let on = chosen.contains(c.contactID)
        let next = Upcoming(c.preview, from: .now)
        return Button {
            if on { chosen.remove(c.contactID) } else { chosen.insert(c.contactID) }
        } label: {
            HStack(spacing: 14) {
                Avatar(birthday: c.preview, size: 42, image: c.photo.flatMap(PlatformImage.init(data:)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(next.age.map { "\(Texts.dayMonth(next.date)) · \(Texts.turns($0))" } ?? Texts.dayMonth(next.date))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(on ? Color.brand : Color.line)
            }
            .foregroundStyle(Color.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.surface, in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder
    private func summary(_ r: Store.SyncResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if r.updated > 0 {
                Text("\(r.updated) birthdays updated")
            }
            if !r.removed.isEmpty {
                Text("Removed, no longer in your contacts: \(r.removed.formatted(.list(type: .and)))")
            }
            if limited {
                Text("The app can only see some of your contacts. Allow access to all contacts in Settings to find every birthday.")
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(Color.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func message<Actions: View>(icon: String, title: LocalizedStringKey, text: Text?,
                                        @ViewBuilder actions: () -> Actions) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.brand)
                Text(title)
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.6)
                if let text {
                    text
                        .font(.system(size: 17))
                        .foregroundStyle(Color.muted)
                }
                actions().padding(.top, 10)
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: 520, alignment: .leading)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
    }
}
