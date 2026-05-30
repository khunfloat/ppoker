import Testing
@testable import PPokerEngine

@Suite("Pot calculator")
struct PotTests {
    @Test func singlePotEqualContribs() {
        let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
        let pots = PotCalculator.compute(contributions: [
            .init(player: a, amount: 100, folded: false),
            .init(player: b, amount: 100, folded: false),
            .init(player: c, amount: 100, folded: false),
        ])
        #expect(pots.count == 1)
        #expect(pots[0].amount == 300)
        #expect(pots[0].eligiblePlayers == [a, b, c])
    }

    @Test func sidePotShortStackAllIn() {
        let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
        // A all-in 100, B/C 200 each
        let pots = PotCalculator.compute(contributions: [
            .init(player: a, amount: 100, folded: false),
            .init(player: b, amount: 200, folded: false),
            .init(player: c, amount: 200, folded: false),
        ])
        #expect(pots.count == 2)
        #expect(pots[0].amount == 300)
        #expect(pots[0].eligiblePlayers == [a, b, c])
        #expect(pots[1].amount == 200)
        #expect(pots[1].eligiblePlayers == [b, c])
    }

    @Test func foldedPlayerContributesButCantWin() {
        let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
        // A folded after 50, B/C 100 each
        let pots = PotCalculator.compute(contributions: [
            .init(player: a, amount: 50, folded: true),
            .init(player: b, amount: 100, folded: false),
            .init(player: c, amount: 100, folded: false),
        ])
        // Level 50: 50*3=150, eligible={b,c}
        // Level 100: 50*2=100, eligible={b,c}
        // Merged because same eligible set → single pot 250
        #expect(pots.count == 1)
        #expect(pots[0].amount == 250)
        #expect(pots[0].eligiblePlayers == [b, c])
    }

    @Test func threeWayAllInDifferentStacks() {
        let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
        // A all-in 30, B all-in 60, C calls 60
        let pots = PotCalculator.compute(contributions: [
            .init(player: a, amount: 30, folded: false),
            .init(player: b, amount: 60, folded: false),
            .init(player: c, amount: 60, folded: false),
        ])
        #expect(pots.count == 2)
        #expect(pots[0].amount == 90)   // 30*3
        #expect(pots[0].eligiblePlayers == [a, b, c])
        #expect(pots[1].amount == 60)   // 30*2
        #expect(pots[1].eligiblePlayers == [b, c])
    }

    @Test func zeroContributorsReturnsEmpty() {
        #expect(PotCalculator.compute(contributions: []).isEmpty)
    }
}
