import XCTest
@testable import Twenty

final class BreakSchedulerTests: XCTestCase {
    @MainActor
    func testPauseAndResumeSchedulesANewFullInterval() {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        scheduler.pauseReminders()

        XCTAssertEqual(scheduler.state, .paused)
        XCTAssertNil(scheduler.nextBreakDate)

        scheduler.resumeReminders()

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, harness.currentDate.addingTimeInterval(AppSettings.workInterval))
    }

    @MainActor
    func testManualBreakLaterSnoozesAndIgnoresDuplicateCompletion() throws {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        scheduler.takeBreakNow()
        let breakOverlay = try XCTUnwrap(harness.overlay)

        XCTAssertEqual(scheduler.state, .onBreak)

        breakOverlay.finish(.later)
        let snoozedBreak = harness.currentDate.addingTimeInterval(AppSettings.snoozeInterval)
        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, snoozedBreak)

        breakOverlay.finish(.completed)

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, snoozedBreak)
    }

    @MainActor
    func testIdleReturnStartsANewWorkInterval() {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        harness.idleSeconds = 180
        scheduler.workTimerElapsed()

        XCTAssertEqual(scheduler.state, .waitingForReturn)

        harness.idleSeconds = 0
        scheduler.idlePollElapsed()

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, harness.currentDate.addingTimeInterval(AppSettings.workInterval))
    }

    @MainActor
    func testMenuStatusTextDoesNotResumeAnIdleSession() {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        harness.idleSeconds = 180
        scheduler.workTimerElapsed()

        XCTAssertEqual(scheduler.menuStatusText(), "Next Break Soon")
        XCTAssertEqual(scheduler.state, .waitingForReturn)
        XCTAssertNil(scheduler.nextBreakDate)

        scheduler.userDidReturn()

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, harness.currentDate.addingTimeInterval(AppSettings.workInterval))
    }

    @MainActor
    func testShortSleepPreservesThePendingBreakDeadline() throws {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        harness.startWorkingInterval()
        let pendingBreak = try XCTUnwrap(scheduler.nextBreakDate)

        scheduler.handleSystemWillSleep()
        harness.currentDate = harness.currentDate.addingTimeInterval(30)
        scheduler.handleSystemDidWake()

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, pendingBreak)
    }

    @MainActor
    func testLongSessionLockStartsANewWorkInterval() {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        harness.startWorkingInterval()

        scheduler.handleSessionBecameInactive()
        harness.currentDate = harness.currentDate.addingTimeInterval(180)
        scheduler.handleSessionBecameActive()

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, harness.currentDate.addingTimeInterval(AppSettings.workInterval))
    }

    @MainActor
    func testScreenWakeWhileLockedWaitsForSessionActivation() {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        harness.startWorkingInterval()
        let pendingBreak = scheduler.nextBreakDate

        scheduler.handleSessionBecameInactive()
        harness.currentDate = harness.currentDate.addingTimeInterval(180)
        scheduler.handleSystemDidWake()
        scheduler.handleScreensDidWake()

        XCTAssertEqual(scheduler.state, .waitingForReturn)
        XCTAssertEqual(scheduler.nextBreakDate, pendingBreak)

        scheduler.handleSessionBecameActive()

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, harness.currentDate.addingTimeInterval(AppSettings.workInterval))
    }

    @MainActor
    func testLongSleepStartsANewWorkInterval() {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        harness.startWorkingInterval()

        scheduler.handleSystemWillSleep()
        harness.currentDate = harness.currentDate.addingTimeInterval(180)
        scheduler.handleSystemDidWake()

        XCTAssertEqual(scheduler.state, .working)
        XCTAssertEqual(scheduler.nextBreakDate, harness.currentDate.addingTimeInterval(AppSettings.workInterval))
    }

    @MainActor
    func testSettingsChangeRecalculatesAFullWorkInterval() {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        harness.startWorkingInterval()
        UserDefaults.standard.set(30, forKey: AppSettings.workIntervalMinutesKey)

        scheduler.settingsDidChange()

        XCTAssertEqual(scheduler.nextBreakDate, harness.currentDate.addingTimeInterval(AppSettings.workInterval))
    }

    @MainActor
    func testCompletionAfterSessionBecomesInactiveIsIgnored() throws {
        let harness = SchedulerHarness()
        defer { harness.stop() }
        let scheduler = harness.scheduler
        scheduler.takeBreakNow()
        let breakOverlay = try XCTUnwrap(harness.overlay)

        scheduler.handleSessionBecameInactive()
        breakOverlay.finish(.completed)

        XCTAssertEqual(scheduler.state, .waitingForReturn)
        XCTAssertNil(scheduler.nextBreakDate)
    }
}

@MainActor
private final class SchedulerHarness {
    var currentDate = Date()
    var idleSeconds: TimeInterval = 0
    var overlay: TestOverlay?
    private(set) lazy var scheduler: BreakScheduler = {
        BreakScheduler(
            now: { [unowned self] in self.currentDate },
            systemIdleSeconds: { [unowned self] in self.idleSeconds },
            makeOverlay: { [unowned self] _, onFinish in
                let overlay = TestOverlay(onFinish: onFinish)
                self.overlay = overlay
                return overlay
            }
        )
    }()

    init() {
        clearSettings()
        AppSettings.registerDefaults()
        UserDefaults.standard.set(20, forKey: AppSettings.workIntervalMinutesKey)
        UserDefaults.standard.set(20, forKey: AppSettings.breakDurationSecondsKey)
        UserDefaults.standard.set(5, forKey: AppSettings.snoozeMinutesKey)
    }

    func stop() {
        scheduler.pauseReminders()
        clearSettings()
    }

    func startWorkingInterval() {
        scheduler.pauseReminders()
        scheduler.resumeReminders()
    }

    private func clearSettings() {
        for key in [
            AppSettings.workIntervalMinutesKey,
            AppSettings.breakDurationSecondsKey,
            AppSettings.snoozeMinutesKey,
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

@MainActor
private final class TestOverlay: BreakOverlay {
    private let onFinish: (OverlayController.Outcome) -> Void

    init(onFinish: @escaping (OverlayController.Outcome) -> Void) {
        self.onFinish = onFinish
    }

    func present() {}

    func cancelImmediately() {}

    func finish(_ outcome: OverlayController.Outcome) {
        onFinish(outcome)
    }
}
