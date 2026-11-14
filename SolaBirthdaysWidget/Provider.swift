import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BirthdayEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        guard let data = Storage.loadIfReadable() else { return completion(.locked(.now)) }
        completion(context.isPreview && data.birthdays.isEmpty ? .sample : BirthdayEntry(date: .now, data: data))
    }

    /// One entry now and one at each of the next seven midnights. A new timeline is asked for
    /// after the first midnight, so the widgets reread the data daily and a missed reload lasts
    /// at most a day; the further entries cover the time until the system gets to it.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        guard let data = Storage.loadIfReadable() else {
            // The file is locked until the first unlock after a restart. Try again soon instead
            // of showing an empty widget for a day.
            completion(Timeline(entries: [.locked(.now)], policy: .after(.now.addingTimeInterval(15 * 60))))
            return
        }
        let cal = Calendar.birthdays
        let start = cal.startOfDay(for: .now)
        var entries = [BirthdayEntry(date: .now, data: data)]
        for i in 1...7 {
            if let d = cal.date(byAdding: .day, value: i, to: start) { entries.append(BirthdayEntry(date: d, data: data)) }
        }
        let refresh = entries.count > 1 ? entries[1].date.addingTimeInterval(60) : .now.addingTimeInterval(24 * 3600)
        // Hand over the timeline first: rescheduling can take a while (up to 60 notifications with
        // photos), and if the extension is stopped before it's done, the widget keeps its old one.
        completion(Timeline(entries: entries, policy: .after(refresh)))
        // The widgets refresh daily, so they also keep the reminder queue topped up.
        Task { await Reminders.reschedule(data) }
    }
}

@main
struct BirthdayWidgets: WidgetBundle {
    var body: some Widget {
        NextBirthdaysWidget()
        #if os(iOS)
        TodayLineWidget()
        LockScreenWidget()
        #endif
    }
}

struct NextBirthdaysWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextBirthdays", provider: Provider()) { entry in
            HomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Next birthdays")
        .description("The next birthdays with photo and how many days to go.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#if os(iOS)
struct TodayLineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayLine", provider: Provider()) { entry in
            InlineView(entry: entry)
        }
        .configurationDisplayName("Date and birthdays")
        .description("Next to the date above the clock: who has a birthday today and who’s coming up in the next 7 days.")
        .supportedFamilies([.accessoryInline])
    }
}

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockScreen", provider: Provider()) { entry in
            LockView(entry: entry)
        }
        .configurationDisplayName("Next birthdays")
        .description("The next birthdays on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
#endif
