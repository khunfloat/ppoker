import Foundation

public struct Deck: Sendable, Codable {
    public private(set) var cards: [Card]

    public init() {
        self.cards = Suit.allCases.flatMap { suit in
            Rank.allCases.map { Card($0, suit) }
        }
    }

    public init(cards: [Card]) {
        self.cards = cards
    }

    public var count: Int { cards.count }

    public mutating func shuffle<G: RandomNumberGenerator>(using generator: inout G) {
        cards.shuffle(using: &generator)
    }

    public mutating func shuffle() {
        var system = SystemRandomNumberGenerator()
        shuffle(using: &system)
    }

    public mutating func draw() -> Card? {
        cards.popLast()
    }

    public mutating func draw(_ n: Int) -> [Card] {
        var out: [Card] = []
        out.reserveCapacity(n)
        for _ in 0..<n {
            guard let c = draw() else { break }
            out.append(c)
        }
        return out
    }
}
