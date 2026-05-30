#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct StatsView: View {
    @EnvironmentObject var app: AppState

    public init() {}

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                if app.sessionStats.isEmpty {
                    Text("No stats yet").foregroundStyle(.white.opacity(0.5))
                    Spacer()
                } else {
                    statsTable
                    Spacer()
                }
                doneButton
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Session Summary")
                .foregroundStyle(.white)
                .font(.system(size: 22, weight: .semibold))
            Text("Hand #\(app.gameState.handCount)")
                .foregroundStyle(.white.opacity(0.5))
                .font(.caption)
        }
    }

    private var statsTable: some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(sorted, id: \.playerID) { stats in
                playerRow(stats)
            }
        }
        .background(PPTheme.panel)
        .cornerRadius(12)
    }

    private var headerRow: some View {
        HStack {
            Text("Player").foregroundStyle(.white.opacity(0.6))
            Spacer()
            cell("Buy-in")
            cell("Stack")
            cell("P/L")
            cell("Hands").frame(width: 50)
        }
        .font(.caption.bold())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
    }

    private func playerRow(_ s: PlayerSessionStats) -> some View {
        HStack {
            Text(s.displayName)
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            valueCell("\(s.totalBuyIn)", color: .white)
            valueCell("\(s.currentStack)", color: .white)
            valueCell(
                signed(s.profitLoss),
                color: s.profitLoss > 0 ? PPTheme.plPositive
                    : s.profitLoss < 0 ? PPTheme.plNegative
                    : .white
            )
            valueCell("\(s.handsPlayed)", color: .white.opacity(0.7))
                .frame(width: 50)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { PPTheme.divider.frame(height: 0.5) }
    }

    private func cell(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 70, alignment: .trailing)
    }

    private func valueCell(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.chipNumber(size: 14))
            .foregroundStyle(color)
            .frame(width: 70, alignment: .trailing)
    }

    private var doneButton: some View {
        Button {
            app.goHome()
        } label: {
            Text("Done").frame(maxWidth: .infinity)
        }
        .buttonStyle(PPPrimaryButton())
    }

    private var sorted: [PlayerSessionStats] {
        app.sessionStats.sorted { $0.profitLoss > $1.profitLoss }
    }

    private func signed(_ x: Int) -> String {
        x > 0 ? "+\(x)" : "\(x)"
    }
}
#endif
