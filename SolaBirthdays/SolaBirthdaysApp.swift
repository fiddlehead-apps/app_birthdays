import BackgroundTasks
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct SolaBirthdaysApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ListView(store: store, router: delegate.router)
                .tint(Color.brand)
                .onOpenURL { url in
                    if let id = DeepLink.id(from: url) { delegate.router.open = id }
                }
        }
        .onChange(of: phase) { _, phase in
            switch phase {
            case .active:
                store.reload()
                Task { await store.refreshReminders() }
                Task { await store.cloud.syncNow() }
            case .background:
                Refresh.schedule()
            default: break
            }
        }
        .backgroundTask(.appRefresh(Refresh.id)) {
            await Reminders.reschedule(Storage.load())
            Refresh.schedule()
        }
    }
}

/// Which birthday a widget or notification asked to open.
@Observable
final class Router {
    var open: UUID?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = Router()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["birthday"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run { router.open = id }
    }
}

/// Daily background refresh that tops up the reminder queue.
nonisolated enum Refresh {
    static let id = (Bundle.main.bundleIdentifier ?? "") + ".refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = .now.addingTimeInterval(12 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
