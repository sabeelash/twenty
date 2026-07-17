import AppKit

/// Owns all timing. One one-shot timer while working — no ticking, no polling.
/// A lightweight poll runs only while the user is away from the machine, and a
/// 1 Hz countdown timer runs only while the break overlay is on screen.
@MainActor
final class BreakScheduler: NSObject {
    enum State {
        case working
        case waitingForReturn
        case onBreak
        case paused
    }

    private(set) var state: State = .working
    private(set) var nextBreakDate: Date?

    private var workTimer: Timer?
    private var idlePollTimer: Timer?
    private var overlay: OverlayController?

    /// Start of the current work session; kept so an interval change in
    /// Settings adjusts the pending break instead of restarting from zero.
    private var sessionStart = Date()
    private var scheduledFullInterval = true
    private var lastKnownIntervalMinutes = 0
    private var awayBegan: Date?

    /// Set when a manual break is started while reminders are paused, so the
    /// pause survives the break instead of silently resuming the cycle.
    private var returnToPausedAfterBreak = false

    /// Idle beyond this counts as an already-taken break; shorter gaps
    /// (reading, thinking) still count as work. `TWENTY_IDLE_RESET_SECONDS`
    /// overrides for development.
    private let idleResetThreshold: TimeInterval = {
        if let raw = ProcessInfo.processInfo.environment["TWENTY_IDLE_RESET_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            return seconds
        }
        return 180
    }()
    private let idlePollInterval: TimeInterval = 15

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    func start() {
        lastKnownIntervalMinutes = AppSettings.workIntervalMinutes

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(userBecameInactive),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(userBecameActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(userBecameInactive),
            name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(userBecameActive),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification, object: nil)

        scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
    }

    // MARK: - Menu actions

    func takeBreakNow() {
        guard state != .onBreak else { return }
        returnToPausedAfterBreak = (state == .paused)
        beginBreak()
    }

    func pauseReminders() {
        guard state != .onBreak else { return }
        cancelTimers()
        state = .paused
        nextBreakDate = nil
    }

    func resumeReminders() {
        guard state == .paused else { return }
        scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
    }

    func menuStatusText() -> String {
        // Opening the menu is user input; if we were waiting for the user to
        // return from idle, they're back — start a fresh session now.
        if state == .waitingForReturn {
            scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
        }
        switch state {
        case .paused:
            return "Reminders Paused"
        case .onBreak:
            return "Break in Progress"
        case .working, .waitingForReturn:
            if let date = nextBreakDate {
                return "Next Break at \(Self.timeFormatter.string(from: date))"
            }
            return "Next Break Soon"
        }
    }

    // MARK: - Scheduling

    private func scheduleBreak(after interval: TimeInterval, fullInterval: Bool) {
        cancelTimers()
        state = .working
        sessionStart = Date()
        scheduledFullInterval = fullInterval
        armWorkTimer(at: Date().addingTimeInterval(interval))
    }

    private func armWorkTimer(at fireDate: Date) {
        workTimer?.invalidate()
        nextBreakDate = fireDate
        let timer = Timer(
            fireAt: fireDate, interval: 0,
            target: self, selector: #selector(workTimerFired),
            userInfo: nil, repeats: false)
        timer.tolerance = min(30, max(1, fireDate.timeIntervalSinceNow * 0.05))
        RunLoop.main.add(timer, forMode: .common)
        workTimer = timer
    }

    private func cancelTimers() {
        workTimer?.invalidate()
        workTimer = nil
        idlePollTimer?.invalidate()
        idlePollTimer = nil
    }

    @objc private func workTimerFired() {
        guard state == .working else { return }
        if IdleMonitor.systemIdleSeconds() >= idleResetThreshold {
            beginWaitingForReturn()
        } else {
            beginBreak()
        }
    }

    // MARK: - Idle handling

    private func beginWaitingForReturn() {
        cancelTimers()
        state = .waitingForReturn
        nextBreakDate = nil
        let timer = Timer(
            timeInterval: idlePollInterval,
            target: self, selector: #selector(idlePollFired),
            userInfo: nil, repeats: true)
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        idlePollTimer = timer
    }

    @objc private func idlePollFired() {
        guard state == .waitingForReturn else { return }
        if IdleMonitor.systemIdleSeconds() < idlePollInterval {
            scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
        }
    }

    // MARK: - Break

    private func beginBreak() {
        cancelTimers()
        state = .onBreak
        nextBreakDate = nil
        let controller = OverlayController(duration: AppSettings.breakDurationSeconds) { [weak self] outcome in
            guard let self else { return }
            self.overlay = nil
            let returnToPaused = self.returnToPausedAfterBreak
            self.returnToPausedAfterBreak = false
            switch outcome {
            case .later:
                // Asking for a break later is explicit intent — it overrides
                // a pre-break pause.
                self.scheduleBreak(after: AppSettings.snoozeInterval, fullInterval: false)
            case .skipped, .completed:
                if returnToPaused {
                    self.state = .paused
                    self.nextBreakDate = nil
                } else {
                    self.scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
                }
            }
        }
        overlay = controller
        controller.present()
    }

    // MARK: - Sleep / wake

    @objc private func systemWillSleep() {
        userBecameInactive()
    }

    @objc private func systemDidWake() {
        userBecameActive()
    }

    @objc private func userBecameInactive() {
        guard awayBegan == nil else { return }
        awayBegan = Date()

        switch state {
        case .working:
            workTimer?.invalidate()
            workTimer = nil
            state = .waitingForReturn
        case .onBreak:
            overlay?.cancelImmediately()
            overlay = nil
            let returnToPaused = returnToPausedAfterBreak
            returnToPausedAfterBreak = false
            state = returnToPaused ? .paused : .waitingForReturn
            nextBreakDate = nil
        case .waitingForReturn, .paused:
            break
        }
    }

    @objc private func userBecameActive() {
        guard let awayBegan else { return }
        self.awayBegan = nil

        guard state != .paused else { return }
        let awayFor = Date().timeIntervalSince(awayBegan)
        if awayFor >= idleResetThreshold || nextBreakDate == nil {
            // A real time away from the machine — that was a break.
            scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
        } else {
            // Short interruption: keep the session and its original deadline.
            state = .working
            let pending = nextBreakDate!
            armWorkTimer(at: max(pending, Date().addingTimeInterval(5)))
        }
    }

    // MARK: - Settings changes

    @objc private func defaultsChanged() {
        let minutes = AppSettings.workIntervalMinutes
        guard minutes > 0, minutes != lastKnownIntervalMinutes else { return }
        lastKnownIntervalMinutes = minutes
        guard state == .working, scheduledFullInterval else { return }
        let newFireDate = sessionStart.addingTimeInterval(TimeInterval(minutes * 60))
        armWorkTimer(at: max(newFireDate, Date().addingTimeInterval(2)))
    }
}
