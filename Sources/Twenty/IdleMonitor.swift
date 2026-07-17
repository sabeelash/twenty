import CoreGraphics
import Foundation

/// System idle time via Quartz event source state. Requires no permissions.
enum IdleMonitor {
    /// Seconds since the last keyboard, mouse, or tablet input event.
    static func systemIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: UInt32.max)!)
    }
}
