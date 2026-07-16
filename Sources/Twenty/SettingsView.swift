import SwiftUI
import ServiceManagement

/// Flighty-style settings: a dark stack of gradient stat cards. Each setting
/// is presented as a big stat (compact "1h 30m" style) with its control
/// beneath it. The window forces dark appearance (see SettingsWindowController)
/// so the card colors are explicit, not adaptive.
struct SettingsView: View {
    @AppStorage(AppSettings.workIntervalMinutesKey) private var workIntervalMinutes = 20
    @AppStorage(AppSettings.breakDurationSecondsKey) private var breakDurationSeconds = 20
    @AppStorage(AppSettings.snoozeMinutesKey) private var snoozeMinutes = 5
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Spacer()
                HorizonGazeMark(size: 17)
                Text("Twenty")
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            workIntervalCard

            HStack(spacing: 12) {
                StatStepperCard(
                    label: "BREAK",
                    caption: "Look 20 feet away",
                    value: $breakDurationSeconds,
                    range: 10...60,
                    step: 5,
                    unit: "s"
                )
                StatStepperCard(
                    label: "SNOOZE",
                    caption: "When you press Later",
                    value: $snoozeMinutes,
                    range: 1...30,
                    step: 1,
                    unit: "m"
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            launchAtLoginCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .frame(width: 400)
        .background(Color(red: 0.07, green: 0.075, blue: 0.09))
    }

    private var workIntervalCard: some View {
        Card {
            MicroLabel("WORK INTERVAL")
                .padding(.bottom, 6)

            StatText(compactWorkInterval)
                .padding(.bottom, 2)

            Text("of screen time between breaks")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 14)

            Slider(
                value: Binding(
                    get: { Double(workIntervalMinutes) },
                    set: { workIntervalMinutes = Int($0) }
                ),
                in: 5...180,
                step: 5
            )
            .tint(.white)

            HStack {
                Text("5m")
                Spacer()
                Text("3h")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
            .padding(.top, 2)
        }
    }

    private var launchAtLoginCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Launch at login")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text("Starts quietly in the menu bar")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(red: 0.20, green: 0.47, blue: 0.95))
                .onChange(of: launchAtLogin) { _, enabled in
                    applyLaunchAtLogin(enabled)
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
    }

    /// Flighty-style compact duration: "20m", "1h", "1h 30m".
    private var compactWorkInterval: String {
        let hours = workIntervalMinutes / 60
        let minutes = workIntervalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// The horizon gaze mark (pupil over a horizon arc) — same geometry as the
/// menu bar icon in StatusItemController, in an 18×18 design space.
private struct HorizonGazeMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, _ in
            let s = size / 18

            var arc = Path()
            arc.move(to: CGPoint(x: 2.5 * s, y: 13 * s))
            arc.addCurve(
                to: CGPoint(x: 15.5 * s, y: 13 * s),
                control1: CGPoint(x: 6.83 * s, y: 10.6 * s),
                control2: CGPoint(x: 11.17 * s, y: 10.6 * s)
            )
            context.stroke(
                arc,
                with: .color(.white),
                style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round)
            )

            let dot = CGRect(x: 6.6 * s, y: 3.6 * s, width: 4.8 * s, height: 4.8 * s)
            context.fill(Path(ellipseIn: dot), with: .color(.white))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Card building blocks

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
    }
}

/// A card whose stat is edited with translucent −/+ buttons.
private struct StatStepperCard: View {
    let label: String
    let caption: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        Card {
            MicroLabel(label)
                .padding(.bottom, 6)

            StatText("\(value)\(unit)")
                .padding(.bottom, 2)

            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)

            Spacer(minLength: 14)

            HStack(spacing: 8) {
                StepButton(symbol: "minus", enabled: value > range.lowerBound) {
                    value = max(range.lowerBound, value - step)
                }
                StepButton(symbol: "plus", enabled: value < range.upperBound) {
                    value = min(range.upperBound, value + step)
                }
            }
        }
    }
}

private struct MicroLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
    }
}

private struct StatText: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.system(size: 36, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.25), value: value)
    }
}

private struct StepButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(enabled ? 0.9 : 0.3))
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white.opacity(hovering && enabled ? 0.24 : 0.12)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
