import Foundation
import PPokerEngine

public struct LobbyPlayer: Codable, Sendable, Hashable {
    public let id: PlayerID
    public let name: String
    public let joinTimestamp: TimeInterval

    public init(id: PlayerID, name: String, joinTimestamp: TimeInterval) {
        self.id = id
        self.name = name
        self.joinTimestamp = joinTimestamp
    }
}

public enum LobbyMessage: Codable, Sendable {
    /// Client → host: initial introduction with identity + public key.
    case hello(playerID: PlayerID, displayName: String, publicKey: Data, version: Int)
    /// Host → client: current lobby snapshot (config, host info, joined players).
    case roomInfo(hostID: PlayerID, hostName: String, config: TableConfig, players: [LobbyPlayer])
    /// Host → client: join accepted with full registry of known public keys.
    case joinAccepted(player: Player, registry: [PlayerID: Data])
    /// Host → client: join rejected with a human-readable reason.
    case joinRejected(reason: String)
    /// Host → all: kick off the first hand.
    case startGame
    /// Host → all: a signed game event.
    case event(SignedEvent)
    /// New host → peers: request log catch-up since a given sequence.
    case syncRequest(sinceSequence: Int)
    /// Peer → requester: bundle of signed events from sequence onward.
    case syncResponse(events: [SignedEvent])
    /// Heartbeat / liveness probe.
    case ping
    case pong
}

public enum LobbyCoder {
    public static func encode(_ message: LobbyMessage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(message)
    }

    public static func decode(_ data: Data) throws -> LobbyMessage {
        try JSONDecoder().decode(LobbyMessage.self, from: data)
    }
}

public let lobbyProtocolVersion = 1
public let lobbyServiceType = "ppoker-lb1"
