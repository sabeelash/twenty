import XCTest
@testable import Twenty

final class AppSettingsTests: XCTestCase {
    func testPersistedSettingsAreClampedToSupportedRanges() {
        clearSettings()
        defer { clearSettings() }
        AppSettings.registerDefaults()

        UserDefaults.standard.set(-1, forKey: AppSettings.workIntervalMinutesKey)
        UserDefaults.standard.set(1_000, forKey: AppSettings.breakDurationSecondsKey)
        UserDefaults.standard.set(0, forKey: AppSettings.snoozeMinutesKey)

        XCTAssertEqual(AppSettings.workIntervalMinutes, AppSettings.workIntervalMinutesRange.lowerBound)
        XCTAssertEqual(AppSettings.breakDurationSeconds, AppSettings.breakDurationSecondsRange.upperBound)
        XCTAssertEqual(
            AppSettings.snoozeInterval,
            TimeInterval(AppSettings.snoozeMinutesRange.lowerBound * 60)
        )
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
