import Testing
import Foundation
@testable import PPokerEngine

@Suite("Signed envelope")
struct EnvelopeTests {
    @Test func signAndVerify() throws {
        let alice = PeerIdentity()
        var registry = PeerRegistry()
        registry.register(playerID: alice.playerID, publicKeyRaw: alice.publicKeyData)

        let event = try Envelope.sign(
            event: .sessionEnded, sequence: 0, timestamp: 1.0, identity: alice
        )
        #expect(event.signature != nil)
        try Envelope.verify(event, registry: registry)
    }

    @Test func tamperedPayloadRejected() throws {
        let alice = PeerIdentity()
        var registry = PeerRegistry()
        registry.register(playerID: alice.playerID, publicKeyRaw: alice.publicKeyData)

        let event = try Envelope.sign(
            event: .gamePaused(by: alice.playerID),
            sequence: 0, timestamp: 1.0, identity: alice
        )
        let tampered = SignedEvent(
            sequence: event.sequence,
            timestamp: event.timestamp,
            signerID: event.signerID,
            event: .gameResumed(by: alice.playerID),
            signature: event.signature
        )
        #expect(throws: EnvelopeError.self) {
            try Envelope.verify(tampered, registry: registry)
        }
    }

    @Test func unknownSignerRejected() throws {
        let alice = PeerIdentity()
        let bob = PeerIdentity()
        var registry = PeerRegistry()
        registry.register(playerID: alice.playerID, publicKeyRaw: alice.publicKeyData)
        // bob not registered

        let event = try Envelope.sign(
            event: .sessionEnded, sequence: 0, timestamp: 1.0, identity: bob
        )
        #expect(throws: EnvelopeError.self) {
            try Envelope.verify(event, registry: registry)
        }
    }

    @Test func unsignedFailsVerification() {
        let unsigned = SignedEvent(
            sequence: 0, timestamp: 0, signerID: PlayerID(),
            event: .sessionEnded, signature: nil
        )
        let registry = PeerRegistry()
        #expect(throws: EnvelopeError.self) {
            try Envelope.verify(unsigned, registry: registry)
        }
    }

    @Test func logRejectsUnsignedWhenRegistryProvided() throws {
        var log = GameLog()
        let alice = PeerIdentity()
        var registry = PeerRegistry()
        registry.register(playerID: alice.playerID, publicKeyRaw: alice.publicKeyData)
        let unsigned = SignedEvent(
            sequence: 0, timestamp: 0, signerID: alice.playerID,
            event: .sessionEnded, signature: nil
        )
        #expect(throws: EnvelopeError.self) {
            try log.append(unsigned, verifyingWith: registry)
        }
    }
}
