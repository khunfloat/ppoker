import Testing
import Foundation
@testable import PPokerEngine

@Suite("Game log and replay")
struct GameLogTests {
    func makeLog() throws -> (GameLog, host: PlayerID, players: [Player], sessionID: UUID) {
        let host = PlayerID()
        let alice = Player(id: PlayerID(), displayName: "Alice", stack: 100)
        let bob = Player(id: PlayerID(), displayName: "Bob", stack: 100)
        let carol = Player(id: PlayerID(), displayName: "Carol", stack: 100)
        let sid = UUID()
        var log = GameLog()
        try log.append(.init(sequence: 0, timestamp: 0, signerID: host,
            event: .sessionStarted(config: .default, hostID: host, sessionID: sid)))
        try log.append(.init(sequence: 1, timestamp: 1, signerID: host,
            event: .playerJoined(player: alice, joinTimestamp: 1)))
        try log.append(.init(sequence: 2, timestamp: 2, signerID: host,
            event: .playerJoined(player: bob, joinTimestamp: 2)))
        try log.append(.init(sequence: 3, timestamp: 3, signerID: host,
            event: .playerJoined(player: carol, joinTimestamp: 3)))
        return (log, host, [alice, bob, carol], sid)
    }

    @Test func appendIncrementsSequence() throws {
        let (log, _, _, _) = try makeLog()
        #expect(log.count == 4)
        #expect(log.nextSequence == 4)
    }

    @Test func outOfOrderRejected() throws {
        var (log, host, _, _) = try makeLog()
        #expect(throws: GameLogError.self) {
            try log.append(.init(sequence: 99, timestamp: 5, signerID: host,
                event: .sessionEnded))
        }
    }

    @Test func duplicateRejected() throws {
        var (log, host, _, _) = try makeLog()
        #expect(throws: GameLogError.self) {
            try log.append(.init(sequence: 2, timestamp: 5, signerID: host,
                event: .sessionEnded))
        }
    }

    @Test func replayProducesState() throws {
        let (log, _, _, sid) = try makeLog()
        let state = GameState.replay(log)
        #expect(state.sessionID == sid)
        #expect(state.players.count == 3)
        #expect(state.currentHand == nil)  // no hand started yet
    }

    @Test func handStartedReplayCreatesHand() throws {
        var (log, host, players, _) = try makeLog()
        try log.append(.init(sequence: 4, timestamp: 4, signerID: host,
            event: .handStarted(handNumber: 1, buttonIndex: 0, deckSeed: 42,
                participants: players.map(\.id))))
        let state = GameState.replay(log)
        #expect(state.currentHand != nil)
        #expect(state.handCount == 1)
        #expect(state.preHandSnapshot?.count == 3)
    }

    @Test func fingerprintMatchesAcrossClonedLogs() throws {
        let (log, _, _, _) = try makeLog()
        let clone = log
        #expect(log.fingerprint() == clone.fingerprint())
    }

    @Test func mergeBringsEmptyUpToSync() throws {
        let (log, _, _, _) = try makeLog()
        var fresh = GameLog()
        let added = try fresh.merge(log)
        #expect(added == log.count)
        #expect(fresh.fingerprint() == log.fingerprint())
    }
}
