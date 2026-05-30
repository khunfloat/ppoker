import Testing
import Foundation
@testable import PPokerNetworking
@testable import PPokerEngine

@Suite("Host election")
struct HostElectionTests {
    @Test func picksEarliestJoiner() {
        let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
        let result = HostElection.elect(
            candidates: [a, b, c],
            joinTimestamps: [a: 100, b: 50, c: 200]
        )
        #expect(result == b)
    }

    @Test func tieBreakerByLexUUID() {
        let a = PlayerID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let b = PlayerID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let result = HostElection.elect(
            candidates: [a, b],
            joinTimestamps: [a: 100, b: 100]
        )
        #expect(result == a)
    }

    @Test func missingTimestampSinksToBottom() {
        let a = PlayerID(); let b = PlayerID()
        let result = HostElection.elect(
            candidates: [a, b],
            joinTimestamps: [b: 100]   // a missing
        )
        #expect(result == b)
    }

    @Test func emptyCandidatesReturnsNil() {
        #expect(HostElection.elect(candidates: [], joinTimestamps: [:]) == nil)
    }

    @Test func deterministicAcrossPeers() {
        let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
        let ts: [PlayerID: TimeInterval] = [a: 1, b: 2, c: 3]
        let first = HostElection.elect(candidates: [a, b, c], joinTimestamps: ts)
        let second = HostElection.elect(candidates: [c, a, b], joinTimestamps: ts)
        #expect(first == second)
    }
}
