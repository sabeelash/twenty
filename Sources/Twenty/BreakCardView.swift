import SwiftUI
import Observation

@MainActor
@Observable
final class BreakCountdownModel {
    var remaining: Int

    init(remaining: Int) {
        self.remaining = remaining
    }
}

/// Full-screen root hosted inside the overlay window: a dim layer over the
/// window's behind-desktop blur, with the card centered.
struct BreakOverlayRoot: View {
    let model: BreakCountdownModel
    let onLater: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            BreakCardView(model: model, onLater: onLater, onSkip: onSkip)
        }
        .ignoresSafeArea()
    }
}

struct BreakCardView: View {
    let model: BreakCountdownModel
    let onLater: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Look far away.")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)

            Text("\(max(0, model.remaining))")
                .font(.system(size: 112, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.3), value: model.remaining)
                .padding(.top, 16)
                .padding(.bottom, 28)

            HStack(spacing: 12) {
                OverlayButton(title: "Later", badge: snoozeBadge, action: onLater)
                OverlayButton(title: "Skip", action: onSkip)
            }
        }
        .padding(.horizontal, 64)
        .padding(.vertical, 48)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    /// Compact snooze duration ("5m", or "30s" under a minute) shown on Later.
    private var snoozeBadge: String {
        let seconds = Int(AppSettings.snoozeInterval)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m"
    }
}

private struct OverlayButton: View {
    let title: String
    var badge: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.primary.opacity(0.10)))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(.primary.opacity(hovering ? 0.14 : 0.07))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
