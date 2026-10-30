import Contacts
import Foundation

/// A contact with a birthday, as read from the address book.
nonisolated struct ContactBirthday: Identifiable, Sendable {
    let contactID: String
    let name: String
    let shortName: String
    let month: Int
    let day: Int
    let year: Int?
    let photo: Data?

    var id: String { contactID }

    /// For showing the row before it's added.
    var preview: Birthday {
        Birthday(contactID: contactID, name: name, shortName: shortName, month: month, day: day, year: year)
    }
}

nonisolated enum ContactsReader {
    enum Access { case full, limited, denied }

    static func requestAccess() async -> Access {
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            _ = try? await CNContactStore().requestAccess(for: .contacts)
        }
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return .full
        #if os(iOS)
        case .limited: return .limited  // the Mac has no limited access
        #endif
        default: return .denied
        }
    }

    /// Every contact that has a birthday. Blocks; call off the main thread.
    static func readAll() throws -> [ContactBirthday] {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = true
        var out: [ContactBirthday] = []
        try CNContactStore().enumerateContacts(with: request) { c, _ in
            guard let bd = c.birthday, let month = bd.month, let day = bd.day,
                  (1...12).contains(month), (1...31).contains(day) else { return }
            let year = bd.year.flatMap { $0 == NSDateComponentUndefined || $0 < 1800 ? nil : $0 }
            let full = CNContactFormatter.string(from: c, style: .fullName) ?? c.organizationName
            guard !full.isEmpty else { return }
            let short = [c.nickname, c.givenName, full].first { !$0.isEmpty } ?? full
            out.append(ContactBirthday(contactID: c.identifier, name: full, shortName: short,
                                       month: month, day: day, year: year, photo: c.thumbnailImageData))
        }
        return out
    }
}
