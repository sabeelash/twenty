import Foundation

/// UserDefaults-backed settings. The SwiftUI settings window writes the same
/// keys via @AppStorage; the scheduler reads them lazily when scheduling, so
/// nothing observes continuously.
enum AppSettings {
    static let workIntervalMinutesKey = "workIntervalMinutes"
    static let breakDurationSecondsKey = "breakDurationSeconds"
    static let snoozeMinutesKey = "snoozeMinutes"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            workIntervalMinutesKey: 20,
            breakDurationSecondsKey: 20,
            snoozeMinutesKey: 5,
        ])
    }

    static var workIntervalMinutes: Int {
        UserDefaults.standard.integer(forKey: workIntervalMinutesKey)
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
        return UserDefaults.standard.integer(forKey: breakDurationSecondsKey)
    }

    /// Snooze interval in seconds. `TWENTY_SNOOZE_SECONDS` overrides for development.
    static var snoozeInterval: TimeInterval {
        if let raw = ProcessInfo.processInfo.environment["TWENTY_SNOOZE_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            return seconds
        }
        return TimeInterval(UserDefaults.standard.integer(forKey: snoozeMinutesKey) * 60)
    }
}
