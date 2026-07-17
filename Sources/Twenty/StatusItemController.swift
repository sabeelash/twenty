import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let scheduler: BreakScheduler
    private let statusItem: NSStatusItem
    private let settingsWindowController = SettingsWindowController()

    private let statusLineItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseItem: NSMenuItem

    init(scheduler: BreakScheduler) {
        self.scheduler = scheduler
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        pauseItem = NSMenuItem(title: "Pause Reminders", action: #selector(togglePause), keyEquivalent: "")
        super.init()

        if let button = statusItem.button {
            button.image = HorizonGazeIcon.image
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(statusLineItem)
        menu.addItem(.separator())

        let breakNowItem = NSMenuItem(title: "Take a Break Now", action: #selector(takeBreakNow), keyEquivalent: "")
        breakNowItem.target = self
        menu.addItem(breakNowItem)

        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Twenty", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        scheduler.userDidReturn()
        statusLineItem.title = scheduler.menuStatusText()
        pauseItem.title = scheduler.state == .paused ? "Resume Reminders" : "Pause Reminders"
    }

    @objc private func takeBreakNow() {
        scheduler.takeBreakNow()
    }

    @objc private func togglePause() {
        if scheduler.state == .paused {
            scheduler.resumeReminders()
        } else {
            scheduler.pauseReminders()
        }
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    /// Dev affordance: lets `TWENTY_OPEN_SETTINGS=1` surface the settings
    /// window at launch without clicking through the menu.
    func showSettings() {
        settingsWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

}
