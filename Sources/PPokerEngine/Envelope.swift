import Foundation

public enum EnvelopeError: Error, Equatable, Sendable {
    case missingSignature
    case verificationFailed
    case signerMismatch
    case encodingFailed
}

public enum Envelope {
    /// Canonical bytes that are signed. Excludes the signature field itself.
    public static func canonicalBytes(
        sequence: Int,
        timestamp: TimeInterval,
        signerID: PlayerID,
        event: GameEvent
    ) throws -> Data {
        struct Payload: Codable {
            let sequence: Int
            let timestamp: TimeInterval
            let signerID: PlayerID
            let event: GameEvent
        }
        let payload = Payload(
            sequence: sequence, timestamp: timestamp, signerID: signerID, event: event
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }

    /// Build a signed envelope using the given identity.
    public static func sign(
        event: GameEvent,
        sequence: Int,
        timestamp: TimeInterval,
        identity: PeerIdentity
    ) throws -> SignedEvent {
        let data = try canonicalBytes(
            sequence: sequence,
            timestamp: timestamp,
            signerID: identity.playerID,
            event: event
        )
        let sig = try identity.sign(data)
        return SignedEvent(
            sequence: sequence,
            timestamp: timestamp,
            signerID: identity.playerID,
            event: event,
            signature: sig
        )
    }

    /// Verify a SignedEvent against a PeerRegistry. Returns nothing on success, throws otherwise.
    public static func verify(_ event: SignedEvent, registry: PeerRegistry) throws {
        guard let signature = event.signature else { throw EnvelopeError.missingSignature }
        let data = try canonicalBytes(
            sequence: event.sequence,
            timestamp: event.timestamp,
            signerID: event.signerID,
            event: event.event
        )
        guard registry.verify(signature: signature, for: data, by: event.signerID) else {
            throw EnvelopeError.verificationFailed
        }
    }
}
