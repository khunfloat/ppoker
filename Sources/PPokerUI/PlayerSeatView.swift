#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct PlayerSeatView: View {
    public let player: Player
    public let isActor: Bool
    public let isButton: Bool
    public let isMe: Bool
    public let timerStart: TimeInterval?
    public let timerDuration: TimeInterval?

    @State private var pulse: Bool = false

    public init(
        player: Player,
        isActor: Bool,
        isButton: Bool,
        isMe: Bool,
        timerStart: TimeInterval? = nil,
        timerDuration: TimeInterval? = nil
    ) {
        self.player = player
        self.isActor = isActor
        self.isButton = isButton
        self.isMe = isMe
        self.timerStart = timerStart
        self.timerDuration = timerDuration
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(player.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        if isButton {
                            Text("D")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(.white))
                        }
                    }
                    Text("\(player.stack)")
                        .font(.chipNumber(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            if player.committedThisRound > 0 {
                Text("→ \(player.committedThisRound)")
                    .font(.caption2)
                    .foregroundStyle(PPTheme.actionPositive)
            }
            if player.status == .folded {
                Text("FOLDED").font(.caption2).foregroundStyle(.white.opacity(0.4))
            } else if player.status == .allIn {
                Text("ALL-IN").font(.caption2).bold().foregroundStyle(PPTheme.actionDanger)
            } else if player.status == .sittingOut {
                Text("SITTING OUT").font(.caption2).foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(8)
        .background(PPTheme.panel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActor && timerStart == nil ? Color.yellow : Color.clear, lineWidth: 3)
                .shadow(color: isActor ? .yellow.opacity(pulse ? 0.7 : 0.2) : .clear, radius: 8)
        )
        .overlay(timerRing)
        .scaleEffect(isActor && pulse ? 1.04 : 1.0)
        .opacity(player.status == .folded ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
        .onAppear { if isActor { pulse = true } }
        .onChange(of: isActor) { active in
            pulse = active
        }
    }

    @ViewBuilder
    private var timerRing: some View {
        if isActor, let start = timerStart, let duration = timerDuration {
            TimelineView(.animation(minimumInterval: 0.1)) { context in
                let elapsed = context.date.timeIntervalSince1970 - start
                let remaining = max(0, min(1, 1 - elapsed / duration))
                RoundedRectangle(cornerRadius: 10)
                    .trim(from: 0, to: remaining)
                    .stroke(timerColor(remaining: remaining),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    private func timerColor(remaining: Double) -> Color {
        if remaining > 0.5 { return .yellow }
        if remaining > 0.2 { return .orange }
        return PPTheme.actionDanger
    }

    private var avatar: some View {
        Circle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 28, height: 28)
            .overlay(
                Text(String(player.displayName.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay(
                Circle().stroke(isMe ? Color.yellow : Color.clear, lineWidth: 2)
            )
    }
}
#endif
