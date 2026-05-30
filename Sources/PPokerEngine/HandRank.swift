import Foundation

public enum HandCategory: Int, Comparable, Codable, Sendable {
    case highCard = 1
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush

    public var displayName: String {
        switch self {
        case .highCard: return "High Card"
        case .onePair: return "One Pair"
        case .twoPair: return "Two Pair"
        case .threeOfAKind: return "Three of a Kind"
        case .straight: return "Straight"
        case .flush: return "Flush"
        case .fullHouse: return "Full House"
        case .fourOfAKind: return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        }
    }

    public static func < (lhs: HandCategory, rhs: HandCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct HandRank: Comparable, Hashable, Codable, Sendable {
    public let category: HandCategory
    /// Ranks of the hand in priority order for tie-breaking
    /// (e.g. trips first, then kickers; full house: trips, then pair; etc.)
    public let tiebreakers: [Rank]
    /// The exact 5 cards used to form this rank (best 5 of 7).
    public let bestFive: [Card]

    public init(category: HandCategory, tiebreakers: [Rank], bestFive: [Card]) {
        self.category = category
        self.tiebreakers = tiebreakers
        self.bestFive = bestFive
    }

    public static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (l, r) in zip(lhs.tiebreakers, rhs.tiebreakers) {
            if l != r { return l < r }
        }
        return false
    }

    public static func == (lhs: HandRank, rhs: HandRank) -> Bool {
        lhs.category == rhs.category && lhs.tiebreakers == rhs.tiebreakers
    }
}
