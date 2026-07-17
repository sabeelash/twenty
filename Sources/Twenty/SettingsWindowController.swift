import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let launchAtLogin = LaunchAtLoginModel()

    func show() {
        launchAtLogin.refreshForDisplay()
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(launchAtLogin: launchAtLogin))
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.title = "Settings"
            // The card stack owns the whole surface, Flighty-style: hidden
            // title, transparent titlebar, and forced dark appearance so the
            // explicit card gradients always sit on the intended background.
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(srgbRed: 0.07, green: 0.075, blue: 0.09, alpha: 1)
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.setContentSize(hosting.view.fittingSize)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
