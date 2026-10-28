import SwiftUI

/// Main screen: today's birthdays, then everything else by next date.
struct ListView: View {
    let store: Store
    @Bindable var router: Router

    @State private var sheet: Sheet?
    @State private var undo: Birthday?

    enum Sheet: Identifiable {
        case detail(UUID), sync, settings, add, hidden
        var id: String {
            switch self {
            case .detail(let id): "detail-\(id)"
            case .sync: "sync"
            case .settings: "settings"
            case .add: "add"
            case .hidden: "hidden"
            }
        }
    }

    var body: some View {
        let items = store.visible
        List {
            header
            if items.isEmpty {
                emptyState
            } else {
                if store.notifications == .denied || store.notifications == .notDetermined { remindersOffBanner }
                let today = items.filter { $0.days == 0 }
                ForEach(today) { u in
                    TodayCard(item: u) { sheet = .detail(u.id) }
                        .plainRow(top: 6, bottom: 6)
                }
                // Titles as plain rows rather than section headers, which would stick to the top.
                ForEach(groups(items.filter { $0.days > 0 }), id: \.title) { group in
                    Text(group.title)
                        .font(.system(size: 21, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                        .plainRow(top: 18, bottom: 4)
                    ForEach(group.items) { u in
                        BirthdayRow(item: u) { sheet = .detail(u.id) }
                            .plainRow()
                            .swipeActions(edge: .trailing) { hideButton(u.birthday) }
                            .contextMenu { hideButton(u.birthday) }
                    }
                }
            }
            footer
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .overlay(alignment: .bottom) { if let undo { undoToast(undo) } }
        .sheet(item: $sheet) { s in
            switch s {
            case .detail(let id): DetailView(store: store, id: id)
            case .sync: SyncView(store: store)
            case .settings: SettingsView(store: store)
            case .add: EditView(store: store, birthday: nil)
            case .hidden: NavigationStack { HiddenView(store: store, standalone: true) }
            }
        }
        .onChange(of: router.open) { _, id in
            if let id, store.birthday(id) != nil { sheet = .detail(id) }
            router.open = nil
        }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack(spacing: 10) {
            Spacer()
            CircleIconButton(systemImage: "plus", label: "Add birthday") { sheet = .add }
            CircleIconButton(systemImage: "arrow.triangle.2.circlepath", label: "Sync with contacts") { sheet = .sync }
            CircleIconButton(systemImage: "gearshape", label: "Settings") { sheet = .settings }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Birthdays")
                .font(.system(size: 44, weight: .heavy))
                .tracking(-1.2)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text(Texts.weekdayDayMonth(.now))
                .font(.system(size: 17))
                .foregroundStyle(Color.muted)
        }
        .plainRow(top: 4, bottom: 14)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            BalloonIllustration()
                .padding(.bottom, 24)
            Text("Never miss a birthday.")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .padding(.bottom, 12)
            Text("Pick which birthdays from your contacts to keep. You get a reminder a week before and on the day.")
                .font(.system(size: 17))
                .lineSpacing(3)
                .foregroundStyle(Color.muted)
                .padding(.bottom, 28)
            VStack(spacing: 12) {
                Button { sheet = .sync } label: {
                    Label("Import from contacts", systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(BigButtonStyle(primary: true))
                Button { sheet = .add } label: {
                    Label("Add by hand", systemImage: "plus")
                }
                .buttonStyle(BigButtonStyle(primary: false))
            }
        }
        .foregroundStyle(Color.ink)
        .plainRow(top: 8, bottom: 8)
    }

    private var remindersOffBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.brand)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Reminders are off")
                    .font(.system(size: 16, weight: .semibold))
                Text("Allow notifications to get a reminder before each birthday.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.muted)
                Button("Turn on", action: turnOnNotifications)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.ink)
        .card()
        .plainRow(top: 0, bottom: 10)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            let hidden = store.hidden.count
            if hidden > 0 {
                Button { sheet = .hidden } label: {
                    Label("\(hidden) hidden", systemImage: "eye.slash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                }
                .buttonStyle(.borderless)
            }
            Text(store.cloud.isOn ? "Synced with your iCloud. Nothing else is uploaded." : "Your contacts stay on this device. Nothing is uploaded.")
                .font(.system(size: 14))
                .foregroundStyle(Color.muted)
        }
        .plainRow(top: 22, bottom: 40)
    }

    private func hideButton(_ b: Birthday) -> some View {
        Button {
            withAnimation { store.setHidden(b.id, true) }
            showUndo(b)
        } label: {
            Label("Hide", systemImage: "eye.slash")
        }
        .tint(Color.muted)
    }

    private func undoToast(_ b: Birthday) -> some View {
        HStack(spacing: 14) {
            Text("“\(b.name)” hidden")
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Undo") {
                withAnimation { store.setHidden(b.id, false) }
                undo = nil
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.brand)
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.line, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func showUndo(_ b: Birthday) {
        withAnimation { undo = b }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if undo?.id == b.id { withAnimation { undo = nil } }
        }
    }

    private func turnOnNotifications() {
        if store.notifications == .notDetermined {
            Task { await store.requestNotifications() }
        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: Grouping

    private struct Group {
        let title: String
        var items: [Upcoming]
    }

    /// "Next 7 days", then one section per month.
    private func groups(_ items: [Upcoming]) -> [Group] {
        var out: [Group] = []
        let soon = items.filter { $0.days <= 7 }
        if !soon.isEmpty { out.append(Group(title: String(localized: "Next 7 days"), items: soon)) }
        let thisYear = Calendar.birthdays.component(.year, from: .now)
        for u in items where u.days > 7 {
            let year = Calendar.birthdays.component(.year, from: u.date)
            let title = year == thisYear ? u.date.formatted(.dateTime.month(.wide))
                : u.date.formatted(.dateTime.month(.wide).year())
            if out.last?.title == title { out[out.count - 1].items.append(u) } else { out.append(Group(title: title, items: [u])) }
        }
        return out
    }
}

/// One birthday in the list.
struct BirthdayRow: View {
    let item: Upcoming
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Avatar(birthday: item.birthday, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.birthday.name)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                daysBadge
            }
            .foregroundStyle(Color.ink)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line, lineWidth: 1.5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        let date = Texts.dayMonth(item.date)
        guard let age = item.age else { return date }
        return "\(date) · \(Texts.turns(age))"
    }

    @ViewBuilder private var daysBadge: some View {
        let soon = item.days <= 7
        Text(Texts.days(item.days))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(soon ? Color.brand : Color.muted)
            .padding(.horizontal, soon ? 10 : 0)
            .padding(.vertical, soon ? 5 : 0)
            .background(soon ? Color.brandSoft : .clear, in: .capsule)
    }
}

/// Big raspberry card for birthdays today.
struct TodayCard: View {
    let item: Upcoming
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Avatar(birthday: item.birthday, size: 68)
                    .overlay(Circle().strokeBorder(Color.brandInk.opacity(0.9), lineWidth: 3))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today 🎉")
                        .font(.system(size: 14, weight: .bold))
                        .opacity(0.85)
                    Text(item.birthday.name)
                        .font(.system(size: 22, weight: .heavy))
                        .lineLimit(2)
                    if let age = item.age {
                        Text(Texts.turns(age))
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.brandInk)
            .padding(18)
            .background(Color.brand, in: .rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// A list row without separators, insets or background, for the custom card look.
    func plainRow(top: CGFloat = 4, bottom: CGFloat = 4) -> some View {
        self.listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
