import SwiftUI
import WidgetKit

/// Above the clock: today's date, who has a birthday today, how many in the next 7 days.
/// The system picks the longest variant that fits.
struct InlineView: View {
    let entry: BirthdayEntry

    var body: some View {
        let today = entry.today
        let soon = entry.soon
        let long = Text(verbatim: entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
        let short = Text(verbatim: entry.date.formatted(.dateTime.weekday(.abbreviated).day()))
        // "Anna", or "Anna +1" when several have their birthday today; shortest: just the count.
        let name = today.first.map { today.count == 1 ? $0.birthday.shortName : "\($0.birthday.shortName) +\(today.count - 1)" }
        let count = today.isEmpty ? nil : "\(today.count)"

        ViewThatFits {
            line(long, today: name, soon: soon, soonLong: true)
            line(long, today: name, soon: soon, soonLong: false)
            line(short, today: name, soon: soon, soonLong: false)
            line(short, today: count, soon: soon, soonLong: false)
            short
        }
        .widgetURL(today.first.map { DeepLink.url($0.id) })
    }

    private func line(_ date: Text, today: String?, soon: Int, soonLong: Bool) -> Text {
        var parts = [date]
        if let today {
            parts += [Text(verbatim: " · "), Text(Image(systemName: "party.popper")), Text(verbatim: " \(today)")]
        }
        if soon > 0 {
            parts += [Text(verbatim: " · "), Text(Image(systemName: "birthday.cake")), Text(verbatim: " ")]
            parts.append(soonLong ? Text(verbatim: String(localized: "\(soon) in 7 days", comment: "Lock Screen: birthdays in the next 7 days"))
                                  : Text(verbatim: "\(soon)"))
        }
        return parts.dropFirst().reduce(parts[0]) { Text("\($0)\($1)") }
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
