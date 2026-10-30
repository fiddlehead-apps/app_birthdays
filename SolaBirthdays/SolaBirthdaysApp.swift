#if os(iOS)
import BackgroundTasks
#endif
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct SolaBirthdaysApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif
    @State private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        #if os(macOS)
        // One window: widgets and notifications open their birthday in it instead of a new one.
        Window("Birthdays", id: "main") { content }
            .defaultSize(width: 520, height: 820)
            .windowResizability(.contentMinSize)
            .commands { MenuCommands(router: delegate.router) }
        #else
        WindowGroup { content }
            .backgroundTask(.appRefresh(Refresh.id)) {
                await Reminders.reschedule(Storage.load())
                Refresh.schedule()
            }
        #endif
    }

    private var content: some View {
        ListView(store: store, router: delegate.router)
            .tint(Color.brand)
            #if DEBUG
            .onAppear { DemoData.seedIfRequested(store) }
            #endif
            .onOpenURL { url in
                if let id = DeepLink.id(from: url) { delegate.router.open = id }
            }
            // initial: the app starts out active, so a cold start doesn't count as a change.
            .onChange(of: phase, initial: true) { _, phase in
                switch phase {
                case .active:
                    store.reload()
                    Task { await store.refreshReminders() }
                    Task { await store.cloud.syncNow() }
                case .background:
                    #if os(iOS)
                    Refresh.schedule()
                    #endif
                default: break
                }
            }
    }
}

/// Which birthday a widget or notification asked to open, or which sheet a menu command asked for.
@Observable
final class Router {
    var open: UUID?
    var sheet: ListView.Sheet?
}

#if os(macOS)
/// The Mac menu bar: new birthday, sync and settings with their usual shortcuts.
struct MenuCommands: Commands {
    let router: Router

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { router.sheet = .settings }
                .keyboardShortcut(",")
        }
        CommandGroup(replacing: .newItem) {
            Button("Add birthday") { router.sheet = .add }
                .keyboardShortcut("n")
            Button("Sync with contacts") { router.sheet = .sync }
                .keyboardShortcut("r")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = Router()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Closing the window keeps the app running for iCloud; clicking the Dock icon brings it back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
#else
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = Router()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
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
#endif

extension AppDelegate {
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
