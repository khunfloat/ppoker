import Testing
@testable import PPokerEngine

@Suite("Card and Deck")
struct CardTests {
    @Test func deckHas52UniqueCards() {
        let deck = Deck()
        #expect(deck.count == 52)
        #expect(Set(deck.cards).count == 52)
    }

    @Test func drawReducesCount() {
        var deck = Deck()
        #expect(deck.draw() != nil)
        #expect(deck.count == 51)
    }

    @Test func drawMany() {
        var deck = Deck()
        let hand = deck.draw(5)
        #expect(hand.count == 5)
        #expect(deck.count == 47)
    }

    @Test func shuffleKeepsAllCards() {
        var deck = Deck()
        deck.shuffle()
        #expect(Set(deck.cards).count == 52)
    }

    @Test func rankOrdering() {
        #expect(Rank.ace > Rank.king)
        #expect(Rank.two < Rank.three)
    }

    @Test func cardDescription() {
        #expect(Card(.ace, .spades).description == "A♠")
    }
}
