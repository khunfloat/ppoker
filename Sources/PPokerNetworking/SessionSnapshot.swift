import Foundation
import PPokerEngine

public struct SessionSnapshot: Sendable {
    public let log: GameLog
    public let registry: PeerRegistry
    public let state: GameState
    public let lobbyPlayers: [PlayerID: LobbyPlayer]

    public init(
        log: GameLog,
        registry: PeerRegistry,
        state: GameState,
        lobbyPlayers: [PlayerID: LobbyPlayer]
    ) {
        self.log = log
        self.registry = registry
        self.state = state
        self.lobbyPlayers = lobbyPlayers
    }
}
