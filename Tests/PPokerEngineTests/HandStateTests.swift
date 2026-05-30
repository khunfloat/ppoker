import Testing
@testable import PPokerEngine

@Suite("Hand state lifecycle")
struct HandStateTests {
    func setup(stacks: [Int] = [100, 100, 100], button: Int = 0) -> HandState {
        let players = stacks.enumerated().map { i, s in
            Player(displayName: "P\(i)", stack: s)
        }
        var rng = SeededRNG(seed: 42)
        return HandState.start(
            config: .default,
            players: players,
            buttonIndex: button,
            handNumber: 1,
            rng: &rng
        )
    }

    @Test func dealsTwoCardsPerActivePlayer() {
        let hand = setup()
        #expect(hand.players.allSatisfy { $0.holeCards.count == 2 })
    }

    @Test func postsBlinds() {
        let hand = setup()
        // 3-player: P0=button, P1=SB, P2=BB
        #expect(hand.players[1].committedThisRound == 1)
        #expect(hand.players[2].committedThisRound == 2)
        #expect(hand.bettingRound.currentBet == 2)
    }

    @Test func headsUpButtonActsFirstPreflop() {
        let hand = setup(stacks: [100, 100], button: 0)
        // HU: button=SB=P0; first to act preflop = P0
        #expect(hand.bettingRound.actorIndex == 0)
        #expect(hand.players[0].committedThisRound == 1)
        #expect(hand.players[1].committedThisRound == 2)
    }

    @Test func foldOutEndsHand() throws {
        var hand = setup()
        try hand.apply(.fold, by: hand.bettingRound.actor.id)
        try hand.apply(.fold, by: hand.bettingRound.actor.id)
        #expect(hand.street == .complete)
        // BB takes the small blind (1) so stack = 101
        #expect(hand.players[2].stack == 101)
    }

    @Test func fullHandZeroSum() throws {
        var hand = setup()
        // call/call/check preflop
        try hand.apply(.call, by: hand.bettingRound.actor.id)
        try hand.apply(.call, by: hand.bettingRound.actor.id)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        while hand.street != .complete {
            try hand.apply(.check, by: hand.bettingRound.actor.id)
        }
        #expect(hand.players.map(\.stack).reduce(0, +) == 300)
        #expect(!hand.winners.isEmpty)
    }

    @Test func boardSizesPerStreet() throws {
        var hand = setup()
        try hand.apply(.call, by: hand.bettingRound.actor.id)
        try hand.apply(.call, by: hand.bettingRound.actor.id)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        #expect(hand.board.count == 3)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        #expect(hand.board.count == 4)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        try hand.apply(.check, by: hand.bettingRound.actor.id)
        #expect(hand.board.count == 5)
    }
}
