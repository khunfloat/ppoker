import Testing
@testable import PPokerEngine

@Suite("Betting Round")
struct BettingRoundTests {
    func makePlayers(stacks: [Int]) -> [Player] {
        stacks.enumerated().map { i, s in
            Player(displayName: "P\(i)", stack: s)
        }
    }

    @Test func checkAroundWhenNoBet() throws {
        let players = makePlayers(stacks: [100, 100, 100])
        var round = BettingRound(
            players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
        )
        try round.apply(.check, by: players[0].id)
        try round.apply(.check, by: players[1].id)
        try round.apply(.check, by: players[2].id)
        #expect(round.isRoundComplete)
    }

    @Test func betCallCall() throws {
        let players = makePlayers(stacks: [100, 100, 100])
        var round = BettingRound(
            players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
        )
        try round.apply(.bet(10), by: players[0].id)
        #expect(round.currentBet == 10)
        try round.apply(.call, by: players[1].id)
        try round.apply(.call, by: players[2].id)
        #expect(round.isRoundComplete)
        #expect(round.players[0].stack == 90)
        #expect(round.players[1].stack == 90)
        #expect(round.players[2].stack == 90)
    }

    @Test func foldRemoves() throws {
        let players = makePlayers(stacks: [100, 100, 100])
        var round = BettingRound(
            players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
        )
        try round.apply(.bet(10), by: players[0].id)
        try round.apply(.fold, by: players[1].id)
        try round.apply(.call, by: players[2].id)
        #expect(round.isRoundComplete)
        #expect(round.players[1].status == .folded)
    }

    @Test func raiseEnforcesMinSize() throws {
        let players = makePlayers(stacks: [100, 100])
        var round = BettingRound(
            players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
        )
        try round.apply(.bet(10), by: players[0].id)
        // min raise = currentBet + lastRaiseSize = 10 + 10 = 20
        #expect(throws: BettingError.raiseTooSmall(minimum: 20)) {
            try round.apply(.raiseTo(15), by: players[1].id)
        }
        try round.apply(.raiseTo(25), by: players[1].id)
        #expect(round.currentBet == 25)
        #expect(round.lastRaiseSize == 15)
    }

    @Test func raiseReopensActionForPriorCallers() throws {
        let players = makePlayers(stacks: [100, 100, 100])
        var round = BettingRound(
            players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
        )
        try round.apply(.bet(10), by: players[0].id)
        try round.apply(.call, by: players[1].id)
        try round.apply(.raiseTo(30), by: players[2].id)
        // Now P0 must face the raise again
        #expect(round.actorIndex == 0)
        #expect(!round.isRoundComplete)
        try round.apply(.call, by: players[0].id)
        try round.apply(.call, by: players[1].id)
        #expect(round.isRoundComplete)
    }

    @Test func allInShortBecomesAllInStatus() throws {
        let players = [
            Player(displayName: "Short", stack: 15),
            Player(displayName: "Big", stack: 100),
        ]
        var round = BettingRound(
            players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
        )
        try round.apply(.allIn, by: players[0].id)
        #expect(round.players[0].status == .allIn)
        #expect(round.currentBet == 15)
        try round.apply(.call, by: players[1].id)
        #expect(round.players[1].committedThisRound == 15)
        #expect(round.isRoundComplete)
    }

    @Test func cannotActOutOfTurn() throws {
        let players = makePlayers(stacks: [100, 100])
        var round = BettingRound(
            players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
        )
        #expect(throws: BettingError.notYourTurn) {
            try round.apply(.check, by: players[1].id)
        }
    }

    @Test func cannotCheckWhenFacingBet() throws {
        let players = makePlayers(stacks: [100, 100])
        var round = BettingRound(
            players: players, currentBet: 10, lastRaiseSize: 10, bigBlind: 2, actorIndex: 0
        )
        #expect(throws: BettingError.checkNotAllowed) {
            try round.apply(.check, by: players[0].id)
        }
    }
}
