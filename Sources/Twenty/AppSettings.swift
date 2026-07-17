import Foundation

/// UserDefaults-backed settings. The SwiftUI settings window writes the same
/// keys via @AppStorage; the scheduler reads them lazily when scheduling, so
/// nothing observes continuously.
enum AppSettings {
    static let workIntervalMinutesKey = "workIntervalMinutes"
    static let breakDurationSecondsKey = "breakDurationSeconds"
    static let snoozeMinutesKey = "snoozeMinutes"

    static let workIntervalMinutesRange = 5...180
    static let breakDurationSecondsRange = 10...60
    static let snoozeMinutesRange = 1...30

    static let defaultWorkIntervalMinutes = 20
    static let defaultBreakDurationSeconds = 20
    static let defaultSnoozeMinutes = 5

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            workIntervalMinutesKey: defaultWorkIntervalMinutes,
            breakDurationSecondsKey: defaultBreakDurationSeconds,
            snoozeMinutesKey: defaultSnoozeMinutes,
        ])
    }

    static var workIntervalMinutes: Int {
        clampedValue(forKey: workIntervalMinutesKey, to: workIntervalMinutesRange)
    }

    /// Work interval in seconds. `TWENTY_WORK_SECONDS` overrides for development.
    static var workInterval: TimeInterval {
        if let raw = ProcessInfo.processInfo.environment["TWENTY_WORK_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            return seconds
        }
        return TimeInterval(workIntervalMinutes * 60)
    }

    /// Break duration in seconds. `TWENTY_BREAK_SECONDS` overrides for development.
    static var breakDurationSeconds: Int {
        if let raw = ProcessInfo.processInfo.environment["TWENTY_BREAK_SECONDS"],
           let seconds = Int(raw), seconds > 0 {
            return seconds
        }
        return clampedValue(forKey: breakDurationSecondsKey, to: breakDurationSecondsRange)
    }

    static var snoozeMinutes: Int {
        clampedValue(forKey: snoozeMinutesKey, to: snoozeMinutesRange)
    }

    /// Snooze interval in seconds. `TWENTY_SNOOZE_SECONDS` overrides for development.
    static var snoozeInterval: TimeInterval {
        if let raw = ProcessInfo.processInfo.environment["TWENTY_SNOOZE_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            return seconds
        }
        return TimeInterval(snoozeMinutes * 60)
    }

    private static func clampedValue(forKey key: String, to range: ClosedRange<Int>) -> Int {
        min(max(UserDefaults.standard.integer(forKey: key), range.lowerBound), range.upperBound)
    }
}
