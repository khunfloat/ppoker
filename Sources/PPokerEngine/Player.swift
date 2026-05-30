import Foundation

public struct PlayerID: Hashable, Codable, Sendable, CustomStringConvertible, Identifiable {
    public let raw: UUID

    public init(_ raw: UUID = UUID()) {
        self.raw = raw
    }

    public var id: UUID { raw }
    public var description: String { raw.uuidString.prefix(8).lowercased() }
}

public enum PlayerStatus: String, Codable, Sendable {
    case active        // in hand with chips remaining
    case allIn         // all chips committed this hand
    case folded
    case sittingOut    // not in this hand (no cards dealt)
}

public struct Player: Codable, Sendable, Identifiable, Hashable {
    public let id: PlayerID
    public var displayName: String
    public var stack: Int
    public var status: PlayerStatus
    public var holeCards: [Card]
    /// Chips contributed in the current betting round only.
    public var committedThisRound: Int
    /// Total chips contributed across all rounds of this hand (for side-pot math).
    public var totalCommitted: Int
    /// True if the player has acted at least once during the current round.
    public var hasActedThisRound: Bool
    public var pendingSitOut: Bool
    public var pendingSitIn: Bool

    public init(
        id: PlayerID = PlayerID(),
        displayName: String,
        stack: Int,
        status: PlayerStatus = .active,
        holeCards: [Card] = [],
        committedThisRound: Int = 0,
        totalCommitted: Int = 0,
        hasActedThisRound: Bool = false,
        pendingSitOut: Bool = false,
        pendingSitIn: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.stack = stack
        self.status = status
        self.holeCards = holeCards
        self.committedThisRound = committedThisRound
        self.totalCommitted = totalCommitted
        self.hasActedThisRound = hasActedThisRound
        self.pendingSitOut = pendingSitOut
        self.pendingSitIn = pendingSitIn
    }

    public var isInHand: Bool {
        status == .active || status == .allIn
    }

    public var canAct: Bool {
        status == .active
    }
}
