import AppKit
import SwiftUI

/// Borderless window that may become key so the break card's buttons work.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Presents the full-screen break overlay on every connected display and
/// drives the once-per-second countdown while it is visible.
@MainActor
final class OverlayController: NSObject {
    enum Outcome {
        case completed
        case later
        case skipped
    }

    private let model: BreakCountdownModel
    private let onFinish: (Outcome) -> Void
    private var windows: [OverlayWindow] = []
    private var tickTimer: Timer?
    private var finished = false

    init(duration: Int, onFinish: @escaping (Outcome) -> Void) {
        self.model = BreakCountdownModel(remaining: max(1, duration))
        self.onFinish = onFinish
        super.init()
    }

    func present() {
        buildWindows()
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        windows.first?.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in windows {
                window.animator().alphaValue = 1
            }
        }
        startCountdown()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    /// Tear down with no animation (e.g. the system is going to sleep).
    func cancelImmediately() {
        guard !finished else { return }
        finished = true
        tickTimer?.invalidate()
        closeWindows()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Countdown

    private func startCountdown() {
        let timer = Timer(
            timeInterval: 1,
            target: self, selector: #selector(tick),
            userInfo: nil, repeats: true)
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    @objc private func tick() {
        guard !finished else { return }
        model.remaining -= 1
        if model.remaining <= 0 {
            finish(.completed)
        }
    }

    private func finish(_ outcome: Outcome) {
        guard !finished else { return }
        finished = true
        tickTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in windows {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.closeWindows()
                self.onFinish(outcome)
            }
        })
    }

    private func closeWindows() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows = []
    }

    // MARK: - Windows

    @objc private func screensChanged() {
        guard !finished else { return }
        closeWindows()
        buildWindows()
        for window in windows {
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
        windows.first?.makeKey()
    }

    private func buildWindows() {
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isMovable = false
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let bounds = NSRect(origin: .zero, size: screen.frame.size)
            let effectView = NSVisualEffectView(frame: bounds)
            effectView.material = .fullScreenUI
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.autoresizingMask = [.width, .height]

            let hostingView = NSHostingView(rootView: BreakOverlayRoot(
                model: model,
                onLater: { [weak self] in self?.finish(.later) },
                onSkip: { [weak self] in self?.finish(.skipped) }))
            hostingView.frame = bounds
            hostingView.autoresizingMask = [.width, .height]
            effectView.addSubview(hostingView)

            window.contentView = effectView
            window.setFrame(screen.frame, display: true)
            return window
        }
    }
}
