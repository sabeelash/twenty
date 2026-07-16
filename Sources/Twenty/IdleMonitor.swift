import CoreGraphics
import Foundation

/// System idle time via Quartz event source state. Requires no permissions.
enum IdleMonitor {
    private static let inputEventTypes: [CGEventType] = [
        .mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .scrollWheel,
        .keyDown,
        .flagsChanged,
    ]

    /// Seconds since the last user input event of any common kind.
    static func systemIdleSeconds() -> TimeInterval {
        inputEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }
}
