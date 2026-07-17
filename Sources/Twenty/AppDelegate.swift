import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var scheduler: BreakScheduler?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()

        let scheduler = BreakScheduler()
        self.scheduler = scheduler
        statusItemController = StatusItemController(scheduler: scheduler)
        scheduler.start()

        if ProcessInfo.processInfo.environment["TWENTY_OPEN_SETTINGS"] == "1" {
            statusItemController?.showSettings()
        }
    }
}
