import AppKit

@MainActor
protocol BreakOverlay: AnyObject {
    func present()
    func cancelImmediately()
}

/// Owns all timing. One one-shot timer while working — no ticking, no polling.
/// A lightweight poll runs only while the user is away from the machine, and a
/// 1 Hz countdown timer runs only while the break overlay is on screen.
@MainActor
final class BreakScheduler: NSObject {
    enum State: Equatable {
        case working
        case waitingForReturn
        case onBreak
        case paused
    }

    private(set) var state: State = .working
    private(set) var nextBreakDate: Date?

    private var workTimer: Timer?
    private var idlePollTimer: Timer?
    private var overlay: (any BreakOverlay)?
    private let now: () -> Date
    private let systemIdleSeconds: () -> TimeInterval
    private let makeOverlay: (Int, @escaping (OverlayController.Outcome) -> Void) -> any BreakOverlay

    /// Start of the current work session; kept so an interval change in
    /// Settings adjusts the pending break instead of restarting from zero.
    private var sessionStart: Date
    private var scheduledFullInterval = true
    private var lastKnownIntervalMinutes = 0
    private var awayBegan: Date?
    private var sessionIsInactive = false

    /// Set when a manual break is started while reminders are paused, so the
    /// pause survives the break instead of silently resuming the cycle.
    private var returnToPausedAfterBreak = false
    private var nextBreakGeneration = 0
    private var activeBreakGeneration: Int?

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

    init(
        now: @escaping () -> Date = Date.init,
        systemIdleSeconds: @escaping () -> TimeInterval = IdleMonitor.systemIdleSeconds,
        makeOverlay: @escaping (Int, @escaping (OverlayController.Outcome) -> Void) -> any BreakOverlay = { duration, onFinish in
            OverlayController(duration: duration, onFinish: onFinish)
        }
    ) {
        self.now = now
        self.systemIdleSeconds = systemIdleSeconds
        self.makeOverlay = makeOverlay
        sessionStart = now()
        super.init()
    }

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
            self, selector: #selector(sessionBecameInactive),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(sessionBecameActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(screensDidSleep),
            name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceCenter.addObserver(
            self, selector: #selector(screensDidWake),
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
        sessionStart = now()
        scheduledFullInterval = fullInterval
        armWorkTimer(at: now().addingTimeInterval(interval))
    }

    private func armWorkTimer(at fireDate: Date) {
        workTimer?.invalidate()
        nextBreakDate = fireDate
        let timer = Timer(
            fireAt: fireDate, interval: 0,
            target: self, selector: #selector(workTimerFired),
            userInfo: nil, repeats: false)
        timer.tolerance = min(30, max(1, fireDate.timeIntervalSince(now()) * 0.05))
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
        workTimerElapsed()
    }

    func workTimerElapsed() {
        guard state == .working else { return }
        if systemIdleSeconds() >= idleResetThreshold {
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
        idlePollElapsed()
    }

    func idlePollElapsed() {
        guard state == .waitingForReturn else { return }
        if systemIdleSeconds() < idlePollInterval {
            userDidReturn()
        }
    }

    /// Handles direct user interaction while waiting for an idle break to end.
    func userDidReturn() {
        guard state == .waitingForReturn else { return }
        scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
    }

    // MARK: - Break

    private func beginBreak() {
        cancelTimers()
        state = .onBreak
        nextBreakDate = nil
        nextBreakGeneration += 1
        let generation = nextBreakGeneration
        activeBreakGeneration = generation
        let controller = makeOverlay(AppSettings.breakDurationSeconds) { [weak self] outcome in
            self?.finishBreak(outcome, generation: generation)
        }
        overlay = controller
        controller.present()
    }

    private func finishBreak(_ outcome: OverlayController.Outcome, generation: Int) {
        guard activeBreakGeneration == generation else { return }
        activeBreakGeneration = nil
        overlay = nil
        let returnToPaused = returnToPausedAfterBreak
        returnToPausedAfterBreak = false
        switch outcome {
        case .later:
            if returnToPaused {
                state = .paused
                nextBreakDate = nil
            } else {
                scheduleBreak(after: AppSettings.snoozeInterval, fullInterval: false)
            }
        case .skipped, .completed:
            if returnToPaused {
                state = .paused
                nextBreakDate = nil
            } else {
                scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
            }
        }
    }

    // MARK: - Sleep / wake

    @objc private func systemWillSleep() {
        handleSystemWillSleep()
    }

    @objc private func systemDidWake() {
        handleSystemDidWake()
    }

    func handleSystemWillSleep() {
        handleUserBecameInactive()
    }

    func handleSystemDidWake() {
        guard !sessionIsInactive else { return }
        handleUserBecameActive()
    }

    @objc private func sessionBecameInactive() {
        handleSessionBecameInactive()
    }

    func handleSessionBecameInactive() {
        sessionIsInactive = true
        handleUserBecameInactive()
    }

    @objc private func sessionBecameActive() {
        handleSessionBecameActive()
    }

    func handleSessionBecameActive() {
        sessionIsInactive = false
        handleUserBecameActive()
    }

    @objc private func screensDidSleep() {
        handleUserBecameInactive()
    }

    @objc private func screensDidWake() {
        handleScreensDidWake()
    }

    func handleScreensDidWake() {
        guard !sessionIsInactive else { return }
        handleUserBecameActive()
    }

    private func handleUserBecameInactive() {
        guard awayBegan == nil else { return }
        awayBegan = now()

        switch state {
        case .working:
            workTimer?.invalidate()
            workTimer = nil
            state = .waitingForReturn
        case .onBreak:
            overlay?.cancelImmediately()
            overlay = nil
            activeBreakGeneration = nil
            let returnToPaused = returnToPausedAfterBreak
            returnToPausedAfterBreak = false
            state = returnToPaused ? .paused : .waitingForReturn
            nextBreakDate = nil
        case .waitingForReturn, .paused:
            break
        }
    }

    private func handleUserBecameActive() {
        guard let awayBegan else { return }
        self.awayBegan = nil

        guard state != .paused else { return }
        let awayFor = now().timeIntervalSince(awayBegan)
        if awayFor >= idleResetThreshold || nextBreakDate == nil {
            // A real time away from the machine — that was a break.
            scheduleBreak(after: AppSettings.workInterval, fullInterval: true)
        } else {
            // Short interruption: keep the session and its original deadline.
            state = .working
            let pending = nextBreakDate!
            armWorkTimer(at: max(pending, now().addingTimeInterval(5)))
        }
    }

    // MARK: - Settings changes

    @objc private func defaultsChanged() {
        settingsDidChange()
    }

    func settingsDidChange() {
        let minutes = AppSettings.workIntervalMinutes
        guard minutes > 0, minutes != lastKnownIntervalMinutes else { return }
        lastKnownIntervalMinutes = minutes
        guard state == .working, scheduledFullInterval else { return }
        let newFireDate = sessionStart.addingTimeInterval(AppSettings.workInterval)
        armWorkTimer(at: max(newFireDate, now().addingTimeInterval(2)))
    }
}
