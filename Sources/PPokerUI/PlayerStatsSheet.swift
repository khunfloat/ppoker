#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct PlayerStatsSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    public let playerID: PlayerID

    public init(playerID: PlayerID) {
        self.playerID = playerID
    }

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                header
                if let stats = stats {
                    statsCard(stats)
                } else {
                    Text("No stats available").foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("Close").frame(maxWidth: .infinity)
                }
                .buttonStyle(PPSecondaryButton())
            }
            .padding(20)
        }
    }

    private var stats: PlayerSessionStats? {
        app.sessionStats.first { $0.playerID == playerID }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initial)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .padding(.top, 16)
            Text(displayName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func statsCard(_ s: PlayerSessionStats) -> some View {
        VStack(spacing: 0) {
            row("Total Buy-in", value: "\(s.totalBuyIn)", color: .white)
            divider
            row("Current Stack", value: "\(s.currentStack)", color: .white)
            divider
            row(
                "Profit / Loss",
                value: signed(s.profitLoss),
                color: s.profitLoss > 0 ? PPTheme.plPositive
                    : s.profitLoss < 0 ? PPTheme.plNegative
                    : .white
            )
            divider
            row("Hands Played", value: "\(s.handsPlayed)", color: .white.opacity(0.7))
        }
        .background(PPTheme.panel)
        .cornerRadius(12)
    }

    private func row(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.chipNumber(size: 18))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        PPTheme.divider.frame(height: 0.5)
    }

    private var displayName: String {
        app.gameState.players.first { $0.id == playerID }?.displayName ?? "Player"
    }

    private var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private func signed(_ x: Int) -> String {
        x > 0 ? "+\(x)" : "\(x)"
    }
}
#endif
