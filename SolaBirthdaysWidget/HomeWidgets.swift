import SwiftUI
import WidgetKit

/// Small: the next birthday (or everyone on that day) big, with photo and days to go.
/// Medium: the same on the left, the three after that on the right.
/// Large: the same as one row on top, the five after that below.
struct HomeWidgetView: View {
    let entry: BirthdayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let festive = entry.items.first?.days == 0
        Group {
            if let first = entry.items.first {
                let group = entry.items.filter { $0.days == first.days }
                if family == .systemLarge {
                    VStack(alignment: .leading, spacing: 12) {
                        WideFeature(group: group, festive: festive)
                        Rectangle()
                            .fill(festive ? Color.brandInk.opacity(0.25) : Color.line)
                            .frame(height: 1)
                        upcomingList(Array(entry.items.dropFirst(group.count).prefix(5)), festive: festive)
                    }
                } else if family == .systemMedium {
                    HStack(spacing: 12) {
                        Feature(group: group, festive: festive)
                            .frame(width: 116)
                        Rectangle()
                            .fill(festive ? Color.brandInk.opacity(0.25) : Color.line)
                            .frame(width: 1)
                        upcomingList(Array(entry.items.dropFirst(group.count).prefix(3)), festive: festive)
                    }
                } else {
                    Feature(group: group, festive: festive)
                }
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) { festive ? Color.brand : Color.surface }
        // Tapping opens the first birthday; the rows in the medium widget link to their own.
        .widgetURL(entry.items.first.map { DeepLink.url($0.id) })
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "birthday.cake")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.brand)
            Spacer(minLength: 0)
            Text("No birthdays yet")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.ink)
            Text("Open the app to import them from your contacts.")
                .font(.system(size: 12))
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func upcomingList(_ items: [Upcoming], festive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(items) { u in
                Link(destination: DeepLink.url(u.id)) {
                    HStack(spacing: 8) {
                        Avatar(birthday: u.birthday, size: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(u.birthday.shortName)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(Texts.shortDayMonth(u.date))
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(festive ? Color.brandInk.opacity(0.75) : Color.muted)
                        }
                        Spacer(minLength: 4)
                        Text(u.days == 0 ? Texts.days(0) : Texts.count(u.days))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(festive ? Color.brandInk : Color.brand)
                            .lineLimit(1)
                            .fixedSize()
                            .widgetAccentable()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(festive ? Color.brandInk : Color.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The next birthday: photos, big day count, name and date.
private struct Feature: View {
    let group: [Upcoming]
    let festive: Bool

    var body: some View {
        let first = group[0]
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                AvatarStack(items: Array(group.prefix(3)), ring: festive ? Color.brand : Color.surface)
                Spacer(minLength: 0)
                if first.days == 0 {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.brandInk)
                        .widgetAccentable()
                } else {
                    VStack(alignment: .trailing, spacing: -4) {
                        Text(verbatim: "\(first.days)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.brand)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(Texts.unit(first.days))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.muted)
                    }
                    .widgetAccentable()
                }
            }
            Spacer(minLength: 6)
            Text(names)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(festive ? Color.brandInk.opacity(0.8) : Color.muted)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .foregroundStyle(festive ? Color.brandInk : Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var names: String { group.names }
    private var detail: String { group.detail }
}

/// The next birthday as one row, for the top of the large widget.
private struct WideFeature: View {
    let group: [Upcoming]
    let festive: Bool

    var body: some View {
        let first = group[0]
        HStack(spacing: 12) {
            AvatarStack(items: Array(group.prefix(3)), ring: festive ? Color.brand : Color.surface)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.names)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(group.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(festive ? Color.brandInk.opacity(0.8) : Color.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if first.days == 0 {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.brandInk)
                    .widgetAccentable()
            } else {
                VStack(alignment: .trailing, spacing: -4) {
                    Text(verbatim: "\(first.days)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.brand)
                        .lineLimit(1)
                    Text(Texts.unit(first.days))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.muted)
                }
                .widgetAccentable()
            }
        }
        .foregroundStyle(festive ? Color.brandInk : Color.ink)
    }
}

private extension [Upcoming] {
    /// The full name, or the first names of everyone on that day.
    var names: String {
        count == 1 ? self[0].birthday.name : map(\.birthday.shortName).formatted(.list(type: .and))
    }

    /// When, and how old if it's just one.
    var detail: String {
        let first = self[0]
        let when = first.days == 0 ? Texts.days(0) : Texts.shortDayMonth(first.date)
        guard count == 1, let age = first.age else { return when }
        return "\(when) · \(Texts.turns(age))"
    }
}

/// Overlapping round photos.
private struct AvatarStack: View {
    let items: [Upcoming]
    let ring: Color

    var body: some View {
        let size: CGFloat = items.count == 1 ? 52 : 40
        HStack(spacing: -size * 0.32) {
            ForEach(items) { u in
                Avatar(birthday: u.birthday, size: size)
                    .overlay(Circle().strokeBorder(ring, lineWidth: items.count == 1 ? 0 : 2))
            }
        }
    }
}
