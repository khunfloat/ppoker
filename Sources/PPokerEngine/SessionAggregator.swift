import Foundation

public struct PlayerSessionStats: Sendable, Hashable {
    public let playerID: PlayerID
    public let displayName: String
    public let totalBuyIn: Int
    public let currentStack: Int
    public let handsPlayed: Int

    public var profitLoss: Int { currentStack - totalBuyIn }
}

public enum SessionAggregator {
    /// Computes per-player stats from the current state plus the full event log.
    public static func aggregate(state: GameState, log: GameLog) -> [PlayerSessionStats] {
        var totalBuyIn: [PlayerID: Int] = [:]
        var handsPlayed: [PlayerID: Int] = [:]
        var displayNames: [PlayerID: String] = [:]

        for env in log.events {
            switch env.event {
            case let .playerJoined(player, _):
                totalBuyIn[player.id, default: 0] += state.config.defaultBuyIn
                displayNames[player.id] = player.displayName
            case let .topUp(playerID, amount):
                totalBuyIn[playerID, default: 0] += amount
            case let .handStarted(_, _, _, participants):
                for pid in participants {
                    handsPlayed[pid, default: 0] += 1
                }
            default:
                break
            }
        }

        return state.players.map { p in
            PlayerSessionStats(
                playerID: p.id,
                displayName: displayNames[p.id] ?? p.displayName,
                totalBuyIn: totalBuyIn[p.id] ?? state.config.defaultBuyIn,
                currentStack: p.stack,
                handsPlayed: handsPlayed[p.id] ?? 0
            )
        }
    }
}
