#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct ActionPanelView: View {
    public let hand: HandState
    public let myPlayer: Player
    public let onAction: (BettingAction) -> Void

    @State private var raiseMode: Bool = false
    @State private var raiseAmount: Int

    public init(hand: HandState, myPlayer: Player, onAction: @escaping (BettingAction) -> Void) {
        self.hand = hand
        self.myPlayer = myPlayer
        self.onAction = onAction
        let minRaise = hand.bettingRound.currentBet + hand.bettingRound.lastRaiseSize
        _raiseAmount = State(initialValue: minRaise)
    }

    public var body: some View {
        VStack(spacing: 12) {
            if raiseMode {
                raisePanel
            }
            HStack(spacing: 10) {
                foldButton
                checkOrCallButton
                raiseToggleButton
            }
        }
        .padding(12)
        .background(PPTheme.panel)
        .cornerRadius(14)
    }

    private var owed: Int {
        max(0, hand.bettingRound.currentBet - myPlayer.committedThisRound)
    }

    private var canCheck: Bool { owed == 0 }

    private var isOpening: Bool {
        hand.bettingRound.currentBet == 0
    }

    private var minRaise: Int {
        if isOpening { return hand.config.bigBlind }
        return hand.bettingRound.currentBet + hand.bettingRound.lastRaiseSize
    }

    private var maxRaise: Int {
        myPlayer.stack + myPlayer.committedThisRound
    }

    private var foldButton: some View {
        Button {
            onAction(.fold)
        } label: {
            Text("Fold").frame(maxWidth: .infinity)
        }
        .buttonStyle(PPSecondaryButton())
    }

    private var checkOrCallButton: some View {
        Button {
            onAction(canCheck ? .check : .call)
        } label: {
            Text(canCheck ? "Check" : "Call \(owed)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PPPrimaryButton())
    }

    private var raiseToggleButton: some View {
        Button {
            if raiseMode {
                let target = min(max(raiseAmount, minRaise), maxRaise)
                if target == maxRaise {
                    onAction(.allIn)
                } else if isOpening {
                    onAction(.bet(target))
                } else {
                    onAction(.raiseTo(target))
                }
                raiseMode = false
            } else {
                raiseMode = true
            }
        } label: {
            Text(raiseMode ? "Confirm \(raiseAmount)" : (isOpening ? "Bet" : "Raise"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PPPrimaryButton())
        .disabled(maxRaise < minRaise && !raiseMode)
    }

    private var raisePanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                presetButton("1/3", multiplier: 1.0 / 3)
                presetButton("1/2", multiplier: 0.5)
                presetButton("2/3", multiplier: 2.0 / 3)
                presetButton("POT", multiplier: 1.0)
            }
            HStack(spacing: 12) {
                Button {
                    raiseAmount = max(minRaise, raiseAmount - hand.config.bigBlind)
                } label: {
                    Image(systemName: "minus").foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                .background(PPTheme.divider)
                .cornerRadius(8)

                VStack(spacing: 0) {
                    Text("Raise to")
                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    Text("\(raiseAmount)")
                        .font(.chipNumber(size: 22))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)

                Button {
                    raiseAmount = min(maxRaise, raiseAmount + hand.config.bigBlind)
                } label: {
                    Image(systemName: "plus").foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                .background(PPTheme.divider)
                .cornerRadius(8)
            }
            Slider(
                value: Binding(
                    get: { Double(raiseAmount) },
                    set: { raiseAmount = Int($0) }
                ),
                in: Double(minRaise)...Double(max(maxRaise, minRaise))
            )
            .tint(.white)
        }
    }

    private func presetButton(_ label: String, multiplier: Double) -> some View {
        Button {
            let potNow = liveContributions() + owed
            let target = hand.bettingRound.currentBet + Int(Double(potNow) * multiplier)
            raiseAmount = min(maxRaise, max(minRaise, target))
        } label: {
            Text(label).frame(maxWidth: .infinity)
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(PPTheme.divider)
                .cornerRadius(8)
        }
    }

    private func liveContributions() -> Int {
        hand.players.map(\.totalCommitted).reduce(0, +)
    }
}
#endif
