import CoreGraphics
import Foundation

/// System idle time via Quartz event source state. Requires no permissions.
enum IdleMonitor {
    /// `kCGAnyInputEventType` from CGEventTypes.h, which is not exposed to
    /// Swift. Imported C enums accept any raw value, so the init cannot fail.
    private static let anyInputEventType = CGEventType(rawValue: UInt32.max)!

    /// Seconds since the last keyboard, mouse, or tablet input event.
    static func systemIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInputEventType)
    }
}
