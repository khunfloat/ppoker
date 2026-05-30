import Foundation

public enum GameLogError: Error, Equatable, Sendable {
    case outOfOrderSequence(expected: Int, got: Int)
    case duplicateSequence(Int)
    case empty
}

/// Append-only ordered event log. Every peer holds a replica; host produces, others sync.
public struct GameLog: Codable, Sendable {
    public private(set) var events: [SignedEvent]

    public init(events: [SignedEvent] = []) {
        self.events = events
    }

    public var nextSequence: Int {
        events.last.map { $0.sequence + 1 } ?? 0
    }

    public var count: Int { events.count }

    public var isEmpty: Bool { events.isEmpty }

    public mutating func append(_ event: SignedEvent, verifyingWith registry: PeerRegistry? = nil) throws {
        if event.sequence != nextSequence {
            if events.contains(where: { $0.sequence == event.sequence }) {
                throw GameLogError.duplicateSequence(event.sequence)
            }
            throw GameLogError.outOfOrderSequence(expected: nextSequence, got: event.sequence)
        }
        if let registry {
            try Envelope.verify(event, registry: registry)
        }
        events.append(event)
    }

    /// Merge another log into this one. Used during host migration / peer sync.
    /// Returns the count of newly applied events.
    @discardableResult
    public mutating func merge(_ other: GameLog, verifyingWith registry: PeerRegistry? = nil) throws -> Int {
        var added = 0
        for ev in other.events where ev.sequence >= nextSequence {
            try append(ev, verifyingWith: registry)
            added += 1
        }
        return added
    }

    /// SHA-style fingerprint of the log so peers can verify they're in sync without sending full content.
    public func fingerprint() -> Data {
        // Simple FNV-1a 64-bit over canonical event encoding.
        // (Cryptographic Merkle root will land with the signing iteration.)
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        for ev in events {
            guard let bytes = try? encoder.encode(ev) else { continue }
            for b in bytes {
                hash ^= UInt64(b)
                hash = hash &* prime
            }
        }
        var data = Data(count: 8)
        for i in 0..<8 {
            data[i] = UInt8((hash >> (8 * UInt64(i))) & 0xFF)
        }
        return data
    }
}
