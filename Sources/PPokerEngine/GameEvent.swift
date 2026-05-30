import Foundation

public enum GameEvent: Codable, Sendable, Equatable {
    case sessionStarted(config: TableConfig, hostID: PlayerID, sessionID: UUID)
    case playerJoined(player: Player, joinTimestamp: TimeInterval)
    case playerLeft(playerID: PlayerID)
    case handStarted(handNumber: Int, buttonIndex: Int, deckSeed: UInt64, participants: [PlayerID])
    case playerAction(playerID: PlayerID, action: BettingAction, handNumber: Int)
    case sitOutRequested(playerID: PlayerID)
    case sitInRequested(playerID: PlayerID)
    case topUp(playerID: PlayerID, amount: Int)
    case handAborted(handNumber: Int, reason: String)
    case handSettled(handNumber: Int, finalStacks: [PlayerID: Int])
    case gamePaused(by: PlayerID)
    case gameResumed(by: PlayerID)
    case sessionEnded
    case configUpdated(config: TableConfig)
}

public struct SignedEvent: Codable, Sendable, Equatable {
    public let sequence: Int
    public let timestamp: TimeInterval
    public let signerID: PlayerID
    public let event: GameEvent
    /// Populated by the SignedEnvelope layer once Ed25519 signing is wired in.
    public var signature: Data?

    public init(
        sequence: Int,
        timestamp: TimeInterval,
        signerID: PlayerID,
        event: GameEvent,
        signature: Data? = nil
    ) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.signerID = signerID
        self.event = event
        self.signature = signature
    }
}
