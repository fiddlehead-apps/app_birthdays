import SwiftUI
import WidgetKit

/// Above the clock, after the date the system shows there itself: who has a birthday today
/// and who's coming up in the next 7 days. The system picks the longest variant that fits.
struct InlineView: View {
    let entry: BirthdayEntry

    var body: some View {
        let today = entry.today
        let soon = entry.soon
        // "Anna", or "Anna +1" when several have their birthday today; shortest: just the count.
        let todayName = today.first.map { today.count == 1 ? $0.birthday.shortName : "\($0.birthday.shortName) +\(today.count - 1)" }
        let todayCount = today.isEmpty ? nil : "\(today.count)"
        // The next one and how many days until it, then how many more follow within 7 days:
        // "Ben in 3; +2", shorter "Ben +2"; shortest: just the count.
        let soonCount = soon.isEmpty ? nil : "\(soon.count)"
        let others = soon.count > 1 ? " +\(soon.count - 1)" : ""
        let soonShort = soon.first.map { "\($0.birthday.shortName)\(others)" }
        let soonLong = soon.first.map {
            let next = String(localized: "\($0.birthday.shortName) in \($0.days)", comment: "Lock Screen: name and days until their birthday")
            return soon.count > 1 ? "\(next);\(others)" : next
        }

        ViewThatFits {
            line(today: todayName, soon: soonLong)
            line(today: todayName, soon: soonShort)
            line(today: todayCount, soon: soonShort)
            line(today: todayCount, soon: soonCount)
            line(today: todayCount, soon: nil)
        }
        .widgetURL((today.first ?? soon.first).map { DeepLink.url($0.id) })
    }

    private func line(today: String?, soon: String?) -> Text {
        var parts: [Text] = []
        if let today {
            parts += [Text(Image(systemName: "party.popper")), Text(verbatim: " \(today)")]
        }
        if let soon {
            if !parts.isEmpty { parts.append(Text(verbatim: " · ")) }
            parts += [Text(Image(systemName: "birthday.cake")), Text(verbatim: " \(soon)")]
        }
        return parts.reduce(Text(verbatim: "")) { Text("\($0)\($1)") }
    }
}

/// Rectangular: the next three birthdays. Circular: days until the next one.
struct LockView: View {
    let entry: BirthdayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryCircular { CircularView(entry: entry) } else { RectangularView(entry: entry) }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(entry.items.first.map { DeepLink.url($0.id) })
    }
}

struct RectangularView: View {
    let entry: BirthdayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if entry.items.isEmpty {
                Label("Birthdays", systemImage: "birthday.cake")
                    .font(.system(size: 15, weight: .bold))
                    .widgetAccentable()
                Text("No birthdays yet")
                    .font(.system(size: 14))
            }
            ForEach(entry.items.prefix(3)) { u in
                HStack(spacing: 4) {
                    if u.days == 0 {
                        Image(systemName: "party.popper.fill")
                            .font(.system(size: 12))
                    }
                    Text(u.birthday.shortName)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(u.days == 0 ? Texts.days(0) : Texts.count(u.days))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .font(.system(size: 15, weight: u.days == 0 ? .bold : .medium))
                .widgetAccentable(u.days == 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CircularView: View {
    let entry: BirthdayEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let first = entry.items.first {
                VStack(spacing: -1) {
                    Image(systemName: first.days == 0 ? "party.popper.fill" : "birthday.cake.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .widgetAccentable()
                    if first.days > 0 {
                        Text(verbatim: "\(first.days)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                    }
                    Text(first.birthday.shortName)
                        .font(.system(size: first.days == 0 ? 12 : 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                }
            } else {
                Image(systemName: "birthday.cake")
                    .font(.system(size: 22, weight: .semibold))
            }
        }
    }
}
