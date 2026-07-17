import AppKit

/// The app's mark: a pupil lifting toward a distant horizon ("look 20 feet away").
enum HorizonGazeIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()

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

            NSBezierPath(ovalIn: NSRect(x: 6.6, y: 9.6, width: 4.8, height: 4.8)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Twenty"
        return image
    }()
}
