import Foundation

public struct Pot: Codable, Sendable, Hashable {
    public let amount: Int
    public let eligiblePlayers: Set<PlayerID>

    public init(amount: Int, eligiblePlayers: Set<PlayerID>) {
        self.amount = amount
        self.eligiblePlayers = eligiblePlayers
    }
}

public enum PotCalculator {
    public struct Contribution: Sendable {
        public let player: PlayerID
        public let amount: Int
        public let folded: Bool

        public init(player: PlayerID, amount: Int, folded: Bool) {
            self.player = player
            self.amount = amount
            self.folded = folded
        }
    }

    /// Computes main + side pots given each player's total contribution and folded status.
    /// Standard rule: folded players' chips stay in the pots but they aren't eligible to win.
    public static func compute(contributions: [Contribution]) -> [Pot] {
        let contributors = contributions.filter { $0.amount > 0 }
        if contributors.isEmpty { return [] }

        let levels = Set(contributors.map(\.amount)).sorted()
        var pots: [Pot] = []
        var prev = 0
        for level in levels {
            let delta = level - prev
            let participants = contributors.filter { $0.amount >= level }
            let amount = delta * participants.count
            let eligible = Set(participants.filter { !$0.folded }.map(\.player))
            if amount > 0 {
                pots.append(Pot(amount: amount, eligiblePlayers: eligible))
            }
            prev = level
        }

        // Merge consecutive pots whose eligible sets are identical.
        var merged: [Pot] = []
        for pot in pots {
            if let last = merged.last, last.eligiblePlayers == pot.eligiblePlayers {
                merged[merged.count - 1] = Pot(
                    amount: last.amount + pot.amount,
                    eligiblePlayers: last.eligiblePlayers
                )
            } else {
                merged.append(pot)
            }
        }
        return merged
    }
}
