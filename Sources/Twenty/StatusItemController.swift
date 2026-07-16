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
            button.image = Self.horizonGazeIcon()
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

    /// The app's mark: a pupil lifting toward a distant horizon ("look 20
    /// feet away"). Drawn as a template image so it follows menu bar tinting.
    private static func horizonGazeIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()

            // Horizon: shallow upward arc (quadratic bezier converted to cubic).
            let arc = NSBezierPath()
            arc.move(to: NSPoint(x: 2.5, y: 5))
            arc.curve(
                to: NSPoint(x: 15.5, y: 5),
                controlPoint1: NSPoint(x: 6.83, y: 7.4),
                controlPoint2: NSPoint(x: 11.17, y: 7.4)
            )
            arc.lineWidth = 1.8
            arc.lineCapStyle = .round
            arc.stroke()

            // Pupil above the horizon.
            NSBezierPath(ovalIn: NSRect(x: 6.6, y: 9.6, width: 4.8, height: 4.8)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Twenty"
        return image
    }
}
