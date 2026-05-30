import Foundation
import PPokerEngine

public enum HostElection {
    /// Deterministic host election.
    /// Rules:
    /// 1. Among `candidates`, prefer the one with the earliest joinTimestamp.
    /// 2. Ties broken by lexicographic PlayerID raw UUID — deterministic across peers.
    public static func elect(
        candidates: Set<PlayerID>,
        joinTimestamps: [PlayerID: TimeInterval]
    ) -> PlayerID? {
        let ranked = candidates.sorted { a, b in
            let ta = joinTimestamps[a] ?? .greatestFiniteMagnitude
            let tb = joinTimestamps[b] ?? .greatestFiniteMagnitude
            if ta != tb { return ta < tb }
            return a.raw.uuidString < b.raw.uuidString
        }
        return ranked.first
    }
}

public enum MigrationOutcome: Sendable, Equatable {
    case becameHost
    case waitingForNewHost(PlayerID)
    case sessionDead
}
