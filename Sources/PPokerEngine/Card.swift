import Foundation

public enum Suit: Int, CaseIterable, Codable, Sendable, Comparable {
    case clubs = 0, diamonds, hearts, spades

    public var glyph: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }

    public static func < (lhs: Suit, rhs: Suit) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum Rank: Int, CaseIterable, Codable, Sendable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    public var shortName: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "T"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Card: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rank: Rank
    public let suit: Suit

    public init(_ rank: Rank, _ suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    public var description: String { "\(rank.shortName)\(suit.glyph)" }
}
