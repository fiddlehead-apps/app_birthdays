import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BirthdayEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        let data = Storage.load()
        completion(context.isPreview && data.birthdays.isEmpty ? .sample : BirthdayEntry(date: .now, data: data))
    }

    /// One entry now and one at each of the next seven midnights.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        let data = Storage.load()
        let cal = Calendar.birthdays
        let start = cal.startOfDay(for: .now)
        var entries = [BirthdayEntry(date: .now, data: data)]
        for i in 1...7 {
            if let d = cal.date(byAdding: .day, value: i, to: start) { entries.append(BirthdayEntry(date: d, data: data)) }
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        // The widgets refresh daily, so they also keep the reminder queue topped up.
        let done = Done(completion)
        Task {
            await Reminders.reschedule(data)
            done.call(timeline)
        }
    }

    private struct Done: @unchecked Sendable {
        let completion: (Timeline<BirthdayEntry>) -> Void
        init(_ c: @escaping (Timeline<BirthdayEntry>) -> Void) { completion = c }
        func call(_ t: Timeline<BirthdayEntry>) { completion(t) }
    }
}

@main
struct BirthdayWidgets: WidgetBundle {
    var body: some Widget {
        NextBirthdaysWidget()
        TodayLineWidget()
        LockScreenWidget()
    }
}

struct NextBirthdaysWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextBirthdays", provider: Provider()) { entry in
            HomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Next birthdays")
        .description("The next birthdays with photo and how many days to go.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayLineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayLine", provider: Provider()) { entry in
            InlineView(entry: entry)
        }
        .configurationDisplayName("Date and birthdays")
        .description("Today’s date above the clock, who has a birthday today and how many are coming up in the next 7 days.")
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
