import SwiftUI

/// One birthday: date, age, its own reminders, hide.
struct DetailView: View {
    let store: Store
    let id: UUID

    var body: some View {
        // The content is its own view so it observes the store; read directly in the
        // NavigationStack closure, changes didn't update the sheet.
        NavigationStack { DetailContent(store: store, id: id) }
    }
}

private struct DetailContent: View {
    let store: Store
    let id: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let b = store.birthday(id) { content(b) } else { Color.bg }
        }
        .background(Color.bg)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            if store.birthday(id)?.isManual == true {
                ToolbarItem(placement: .leading) {
                    Button("Edit") { editing = true }
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let b = store.birthday(id) { EditView(store: store, birthday: b) }
        }
    }

    private func content(_ b: Birthday) -> some View {
        let next = Upcoming(b, from: .now)
        return ScrollView {
            VStack(spacing: 0) {
                Avatar(birthday: b, size: 116)
                    .padding(.bottom, 16)
                Text(b.name)
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)
                Text(Texts.weekdayDayMonth(next.date))
                    .font(.system(size: 17))
                    .foregroundStyle(Color.muted)
                    .padding(.bottom, 14)
                HStack(spacing: 8) {
                    pill(Texts.days(next.days), strong: next.days <= 7)
                    if let age = next.age { pill(Texts.turns(age), strong: false) }
                }
                .padding(.bottom, 28)

                remindersCard(b)

                if let year = b.year {
                    Text("Born on \(b.date(in: year).formatted(.dateTime.day().month(.wide).year()))")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)
                }

                VStack(spacing: 12) {
                    if b.hidden {
                        Button { store.setHidden(b.id, false) } label: {
                            Label("Show again", systemImage: "eye")
                        }
                        .buttonStyle(BigButtonStyle(primary: true))
                    } else {
                        Button {
                            store.setHidden(b.id, true)
                            dismiss()
                        } label: {
                            Label("Hide birthday", systemImage: "eye.slash")
                        }
                        .buttonStyle(BigButtonStyle(primary: false))
                    }
                    if b.isManual {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                                .foregroundStyle(Color.danger)
                        }
                        .buttonStyle(BigButtonStyle(primary: false))
                    }
                }
                .padding(.top, 28)

                Group {
                    if b.isManual {
                        Text("Added by hand.")
                    } else {
                        Text("From your contacts. To change the date, edit the contact and sync again. Hidden birthdays stay hidden when you sync.")
                    }
                }
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: 520)
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Delete this birthday?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                store.delete(b.id)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func pill(_ text: String, strong: Bool) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(strong ? Color.brandInk : Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(strong ? Color.brand : Color.surface, in: .capsule)
            .overlay { if !strong { Capsule().strokeBorder(Color.line, lineWidth: 1.5) } }
    }

    private func remindersCard(_ b: Birthday) -> some View {
        let usesDefault = b.reminders == nil
        let current = store.data.reminders(for: b)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Reminders")
                .font(.system(size: 18, weight: .bold))
                .padding(.bottom, 10)
            Toggle(isOn: Binding(get: { usesDefault }, set: { on in
                store.setReminders(b.id, on ? nil : store.data.defaultReminders)
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use default")
                        .font(.system(size: 16))
                    Text(Texts.offsets(store.data.defaultReminders))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.muted)
                }
            }
            if !usesDefault {
                Divider().padding(.vertical, 10)
                ForEach(Reminders.choices, id: \.self) { offset in
                    Toggle(Texts.offset(offset), isOn: Binding(get: { current.contains(offset) }, set: { on in
                        var list = current.filter { $0 != offset }
                        if on { list.append(offset) }
                        store.setReminders(b.id, list.sorted(by: >))
                    }))
                    .font(.system(size: 16))
                    .padding(.vertical, 3)
                }
            }
        }
        .tint(Color.brand)
        .card()
        .opacity(b.hidden ? 0.5 : 1)
        .disabled(b.hidden)
    }
}
