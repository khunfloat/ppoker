import Foundation

public enum Street: String, Codable, Sendable, CaseIterable {
    case preflop, flop, turn, river, showdown, complete
}

public struct HandWinner: Codable, Sendable, Hashable {
    public let potIndex: Int
    public let potAmount: Int
    public let perWinner: Int
    public let winners: [PlayerID]
    public let handDescription: String?     // nil if won by fold

    public init(
        potIndex: Int,
        potAmount: Int,
        perWinner: Int,
        winners: [PlayerID],
        handDescription: String?
    ) {
        self.potIndex = potIndex
        self.potAmount = potAmount
        self.perWinner = perWinner
        self.winners = winners
        self.handDescription = handDescription
    }
}

public struct HandState: Codable, Sendable {
    public var config: TableConfig
    public var players: [Player]
    public var buttonIndex: Int
    public var street: Street
    public var board: [Card]
    public var deck: Deck
    public var bettingRound: BettingRound
    public var pots: [Pot]
    public var winners: [HandWinner]
    public var handNumber: Int

    public static func start(
        config: TableConfig,
        players: [Player],
        buttonIndex: Int,
        handNumber: Int,
        rng: inout some RandomNumberGenerator
    ) -> HandState {
        var seated = players.map { p -> Player in
            var p = p
            // Apply pending flags
            if p.pendingSitOut {
                p.status = .sittingOut
                p.pendingSitOut = false
            }
            if p.pendingSitIn {
                p.status = .active
                p.pendingSitIn = false
            }
            // Reset hand-scoped fields
            if p.status != .sittingOut {
                p.status = (p.stack > 0) ? .active : .sittingOut
            }
            p.holeCards = []
            p.committedThisRound = 0
            p.totalCommitted = 0
            p.hasActedThisRound = false
            return p
        }

        let participants = seated.indices.filter { seated[$0].status == .active }
        precondition(participants.count >= 2, "Need at least 2 active players to start a hand")

        var deck = Deck()
        deck.shuffle(using: &rng)

        // Deal 2 hole cards, one at a time around starting after button.
        let dealOrder = orderedSeats(after: buttonIndex, includingButton: false, count: seated.count, filter: { seated[$0].status == .active })
        for _ in 0..<2 {
            for i in dealOrder {
                if let c = deck.draw() {
                    seated[i].holeCards.append(c)
                }
            }
        }

        // Blinds
        let activeIndices = participants
        let isHeadsUp = activeIndices.count == 2
        let sbIdx: Int
        let bbIdx: Int
        if isHeadsUp {
            sbIdx = buttonIndex
            bbIdx = activeIndices.first { $0 != buttonIndex }!
        } else {
            sbIdx = nextActive(after: buttonIndex, in: seated)
            bbIdx = nextActive(after: sbIdx, in: seated)
        }
        postBlind(amount: config.smallBlind, atIndex: sbIdx, in: &seated)
        postBlind(amount: config.bigBlind, atIndex: bbIdx, in: &seated)

        // First actor preflop
        let firstActor: Int
        if isHeadsUp {
            firstActor = sbIdx        // button (SB) acts first preflop in heads-up
        } else {
            firstActor = nextActive(after: bbIdx, in: seated)
        }

        let round = BettingRound(
            players: seated,
            currentBet: config.bigBlind,
            lastRaiseSize: config.bigBlind,
            bigBlind: config.bigBlind,
            actorIndex: firstActor,
            aggressorIndex: bbIdx
        )

        var hand = HandState(
            config: config,
            players: seated,
            buttonIndex: buttonIndex,
            street: .preflop,
            board: [],
            deck: deck,
            bettingRound: round,
            pots: [],
            winners: [],
            handNumber: handNumber
        )

        // If everyone is already all-in (blinds consumed all chips) or no one can act,
        // skip betting entirely and deal straight through to showdown.
        if hand.bettingRound.isRoundComplete || hand.cannotActFurther() {
            hand.advanceStreet()
        }
        return hand
    }

    // MARK: - Action application

    public mutating func apply(_ action: BettingAction, by playerID: PlayerID) throws {
        if street == .complete { throw BettingError.roundClosed }
        try bettingRound.apply(action, by: playerID)
        self.players = bettingRound.players

        if onlyOneNonFolded() {
            awardByFold()
            street = .complete
            return
        }

        // Keep draining streets while the round is finished — important when only
        // one (or zero) actor remains and post-action play is unnecessary.
        while street != .complete && bettingRound.isRoundComplete {
            advanceStreet()
        }
    }

    /// Process a sit-out request mid-hand. Treated as an immediate fold + flag for next hand.
    public mutating func requestSitOut(by playerID: PlayerID) throws {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else {
            throw BettingError.playerNotFound
        }
        players[idx].pendingSitOut = true
        bettingRound.players[idx].pendingSitOut = true
        // If they're the current actor and active, fold immediately.
        if players[idx].canAct && bettingRound.actorIndex == idx {
            try apply(.fold, by: playerID)
        } else if players[idx].canAct {
            // Not their turn — just mark them folded for this hand.
            players[idx].status = .folded
            bettingRound.players[idx].status = .folded
            if onlyOneNonFolded() {
                awardByFold()
                street = .complete
            }
        }
    }

    public mutating func requestSitIn(by playerID: PlayerID) throws {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else {
            throw BettingError.playerNotFound
        }
        players[idx].pendingSitIn = true
        bettingRound.players[idx].pendingSitIn = true
    }

    // MARK: - Streets

    mutating func advanceStreet() {
        // Move per-round chips into totalCommitted (already done as we go).
        // Reset per-round flags for next round.
        for i in players.indices {
            players[i].committedThisRound = 0
            players[i].hasActedThisRound = false
        }

        switch street {
        case .preflop:
            burnAndDeal(3); street = .flop
        case .flop:
            burnAndDeal(1); street = .turn
        case .turn:
            burnAndDeal(1); street = .river
        case .river:
            street = .showdown
            performShowdown()
            return
        case .showdown, .complete:
            return
        }

        // If all-but-one are all-in, deal remaining streets without further betting.
        if cannotActFurther() {
            while street != .showdown && street != .complete {
                switch street {
                case .preflop: burnAndDeal(3); street = .flop
                case .flop: burnAndDeal(1); street = .turn
                case .turn: burnAndDeal(1); street = .river
                case .river: street = .showdown
                default: break
                }
            }
            performShowdown()
            return
        }

        // Otherwise start a new betting round.
        let firstActor = firstToActPostflop()
        bettingRound = BettingRound(
            players: players,
            currentBet: 0,
            lastRaiseSize: config.bigBlind,
            bigBlind: config.bigBlind,
            actorIndex: firstActor,
            aggressorIndex: nil
        )
    }

    mutating func burnAndDeal(_ count: Int) {
        _ = deck.draw()  // burn
        let drawn = deck.draw(count)
        board.append(contentsOf: drawn)
    }

    mutating func performShowdown() {
        let contributions = players.map { p in
            PotCalculator.Contribution(
                player: p.id,
                amount: p.totalCommitted,
                folded: p.status == .folded
            )
        }
        pots = PotCalculator.compute(contributions: contributions)

        // For each pot, find best hand among eligible non-folded players.
        var awards: [HandWinner] = []
        var stackUpdates: [PlayerID: Int] = [:]

        for (i, pot) in pots.enumerated() {
            let contestants = players.filter {
                pot.eligiblePlayers.contains($0.id) && $0.status != .folded
            }
            // Evaluate each contestant's best 7-card hand
            let evaluations = contestants.map { p -> (Player, HandRank) in
                let combined = p.holeCards + board
                return (p, HandEvaluator.evaluate(combined))
            }
            guard !evaluations.isEmpty else { continue }
            let topRank = evaluations.map(\.1).max()!
            let winners = evaluations.filter { $0.1 == topRank }.map(\.0.id)
            let share = pot.amount / winners.count
            let remainder = pot.amount - share * winners.count
            for (j, wid) in winners.enumerated() {
                let extra = (j < remainder) ? 1 : 0
                stackUpdates[wid, default: 0] += share + extra
            }
            awards.append(HandWinner(
                potIndex: i,
                potAmount: pot.amount,
                perWinner: share,
                winners: winners,
                handDescription: topRank.category.displayName
            ))
        }

        for (id, amount) in stackUpdates {
            if let idx = players.firstIndex(where: { $0.id == id }) {
                players[idx].stack += amount
            }
        }

        winners = awards
        street = .complete
    }

    mutating func awardByFold() {
        // Only one non-folded player left; they win all chips committed.
        let contributions = players.map { p in
            PotCalculator.Contribution(
                player: p.id,
                amount: p.totalCommitted,
                folded: p.status == .folded
            )
        }
        pots = PotCalculator.compute(contributions: contributions)
        guard let winnerPlayer = players.first(where: { $0.status != .folded && $0.status != .sittingOut }) else {
            return
        }
        var awards: [HandWinner] = []
        for (i, pot) in pots.enumerated() where pot.eligiblePlayers.contains(winnerPlayer.id) {
            if let idx = players.firstIndex(where: { $0.id == winnerPlayer.id }) {
                players[idx].stack += pot.amount
            }
            awards.append(HandWinner(
                potIndex: i,
                potAmount: pot.amount,
                perWinner: pot.amount,
                winners: [winnerPlayer.id],
                handDescription: nil
            ))
        }
        winners = awards
    }

    // MARK: - Helpers

    func onlyOneNonFolded() -> Bool {
        let alive = players.filter { $0.status != .folded && $0.status != .sittingOut }
        return alive.count <= 1
    }

    func cannotActFurther() -> Bool {
        let actionable = players.filter { $0.canAct }
        return actionable.count <= 1
    }

    func firstToActPostflop() -> Int {
        let n = players.count
        for step in 1...n {
            let i = (buttonIndex + step) % n
            if players[i].canAct { return i }
        }
        return buttonIndex
    }
}

// MARK: - Free helpers

private func nextActive(after index: Int, in players: [Player]) -> Int {
    let n = players.count
    for step in 1...n {
        let i = (index + step) % n
        if players[i].status == .active { return i }
    }
    return index
}

private func postBlind(amount: Int, atIndex idx: Int, in players: inout [Player]) {
    let pay = min(amount, players[idx].stack)
    players[idx].stack -= pay
    players[idx].committedThisRound += pay
    players[idx].totalCommitted += pay
    if players[idx].stack == 0 {
        players[idx].status = .allIn
    }
}

private func orderedSeats(after start: Int, includingButton: Bool, count: Int, filter: (Int) -> Bool) -> [Int] {
    var result: [Int] = []
    for step in 1...count {
        let i = (start + step) % count
        if filter(i) { result.append(i) }
        if i == start && !includingButton { break }
    }
    if includingButton && filter(start) {
        result.append(start)
    }
    return result
}
