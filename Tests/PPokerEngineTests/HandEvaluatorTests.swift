import Testing
@testable import PPokerEngine

@Suite("Hand Evaluator")
struct HandEvaluatorTests {
    func cards(_ shorthand: String) -> [Card] {
        let parts = shorthand.split(separator: " ")
        return parts.map { Self.parseCard(String($0)) }
    }

    static func parseCard(_ s: String) -> Card {
        let rankChar = s.first!
        let suitChar = s.last!
        let rank: Rank = {
            switch rankChar {
            case "2": return .two
            case "3": return .three
            case "4": return .four
            case "5": return .five
            case "6": return .six
            case "7": return .seven
            case "8": return .eight
            case "9": return .nine
            case "T": return .ten
            case "J": return .jack
            case "Q": return .queen
            case "K": return .king
            case "A": return .ace
            default: fatalError("bad rank \(rankChar)")
            }
        }()
        let suit: Suit = {
            switch suitChar {
            case "s": return .spades
            case "h": return .hearts
            case "d": return .diamonds
            case "c": return .clubs
            default: fatalError("bad suit \(suitChar)")
            }
        }()
        return Card(rank, suit)
    }

    @Test func highCard() {
        let r = HandEvaluator.evaluate(cards("As Kd 9c 7h 3s"))
        #expect(r.category == .highCard)
        #expect(r.tiebreakers == [.ace, .king, .nine, .seven, .three])
    }

    @Test func onePair() {
        let r = HandEvaluator.evaluate(cards("As Ad Kh 7c 3s"))
        #expect(r.category == .onePair)
        #expect(r.tiebreakers == [.ace, .king, .seven, .three])
    }

    @Test func twoPair() {
        let r = HandEvaluator.evaluate(cards("Ks Kd 7h 7c 3s"))
        #expect(r.category == .twoPair)
        #expect(r.tiebreakers == [.king, .seven, .three])
    }

    @Test func threeOfAKind() {
        let r = HandEvaluator.evaluate(cards("Ks Kd Kh 7c 3s"))
        #expect(r.category == .threeOfAKind)
        #expect(r.tiebreakers == [.king, .seven, .three])
    }

    @Test func straight() {
        let r = HandEvaluator.evaluate(cards("9s 8d 7h 6c 5s"))
        #expect(r.category == .straight)
        #expect(r.tiebreakers == [.nine])
    }

    @Test func wheelStraight() {
        let r = HandEvaluator.evaluate(cards("As 2d 3h 4c 5s"))
        #expect(r.category == .straight)
        #expect(r.tiebreakers == [.five])
    }

    @Test func broadwayStraight() {
        let r = HandEvaluator.evaluate(cards("As Kd Qh Jc Ts"))
        #expect(r.category == .straight)
        #expect(r.tiebreakers == [.ace])
    }

    @Test func flush() {
        let r = HandEvaluator.evaluate(cards("Ah Kh 9h 4h 2h"))
        #expect(r.category == .flush)
        #expect(r.tiebreakers == [.ace, .king, .nine, .four, .two])
    }

    @Test func fullHouse() {
        let r = HandEvaluator.evaluate(cards("As Ad Ah 7c 7s"))
        #expect(r.category == .fullHouse)
        #expect(r.tiebreakers == [.ace, .seven])
    }

    @Test func fourOfAKind() {
        let r = HandEvaluator.evaluate(cards("As Ad Ah Ac 7s"))
        #expect(r.category == .fourOfAKind)
        #expect(r.tiebreakers == [.ace, .seven])
    }

    @Test func straightFlush() {
        let r = HandEvaluator.evaluate(cards("9h 8h 7h 6h 5h"))
        #expect(r.category == .straightFlush)
        #expect(r.tiebreakers == [.nine])
    }

    @Test func royalFlush() {
        let r = HandEvaluator.evaluate(cards("Ah Kh Qh Jh Th"))
        #expect(r.category == .straightFlush)
        #expect(r.tiebreakers == [.ace])
    }

    @Test func sevenCardBestFive() {
        // hole: AsKs, board: Qs Js Ts 2c 3d → royal flush
        let r = HandEvaluator.evaluate(cards("As Ks Qs Js Ts 2c 3d"))
        #expect(r.category == .straightFlush)
        #expect(r.tiebreakers == [.ace])
    }

    @Test func sevenCardFullHouseOverFlushDraw() {
        // AA over 22 should be full house even if 3+ same suit available
        let r = HandEvaluator.evaluate(cards("As Ad 2h 2s 2c Kh Qh"))
        #expect(r.category == .fullHouse)
        #expect(r.tiebreakers == [.two, .ace])
    }

    @Test func flushBeatsStraight() {
        let straight = HandEvaluator.evaluate(cards("9s 8d 7h 6c 5s"))
        let flush = HandEvaluator.evaluate(cards("Ah Kh 9h 4h 2h"))
        #expect(flush > straight)
    }

    @Test func higherKickerWinsHighCard() {
        let a = HandEvaluator.evaluate(cards("As Kd 9c 7h 3s"))
        let b = HandEvaluator.evaluate(cards("As Kd 9c 7h 2s"))
        #expect(a > b)
    }

    @Test func tiedHands() {
        let a = HandEvaluator.evaluate(cards("As Ad Kh 7c 3s"))
        let b = HandEvaluator.evaluate(cards("Ah Ac Kd 7s 3d"))
        #expect(!(a < b) && !(b < a))
    }
}
