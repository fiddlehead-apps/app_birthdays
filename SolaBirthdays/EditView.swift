import SwiftUI

/// Add or edit a birthday that isn't in the contacts.
struct EditView: View {
    let store: Store
    let birthday: Birthday?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Calendar.birthdays.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? .now
    @State private var knowsYear = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                }
                Section {
                    DatePicker("Birthday", selection: $date, in: ...Date.now, displayedComponents: .date)
                    Toggle("Year known", isOn: $knowsYear)
                } footer: {
                    Text("With the year, the app shows how old they turn.")
                }
            }
            .formStyle(.grouped)
            .tint(Color.brand)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle(birthday == nil ? Text("New birthday") : Text("Edit birthday"))
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let b = birthday else { return }
        name = b.name
        knowsYear = b.year != nil
        date = b.date(in: b.year ?? 2000)
    }

    private func save() {
        let c = Calendar.birthdays.dateComponents([.year, .month, .day], from: date)
        let clean = name.trimmingCharacters(in: .whitespaces)
        let short = clean.split(separator: " ").first.map(String.init) ?? clean
        var b = birthday ?? Birthday(name: clean, shortName: short, month: 1, day: 1, year: nil)
        b.name = clean
        b.shortName = short
        b.month = c.month ?? 1
        b.day = c.day ?? 1
        b.year = knowsYear ? c.year : nil
        store.saveManual(b)
        if birthday == nil {
            Task { await store.requestNotifications() }
        }
        dismiss()
    }
}
