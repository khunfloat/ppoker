import Foundation
import CryptoKit

/// Local keypair held by a peer. Private key never leaves the device.
public struct PeerIdentity: Sendable {
    public let playerID: PlayerID
    public let privateKey: Curve25519.Signing.PrivateKey
    public var publicKey: Curve25519.Signing.PublicKey { privateKey.publicKey }
    public var publicKeyData: Data { publicKey.rawRepresentation }

    public init(playerID: PlayerID = PlayerID()) {
        self.playerID = playerID
        self.privateKey = Curve25519.Signing.PrivateKey()
    }

    public init(playerID: PlayerID, privateKeyRaw: Data) throws {
        self.playerID = playerID
        self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyRaw)
    }

    public func sign(_ data: Data) throws -> Data {
        try privateKey.signature(for: data)
    }

    /// Load a stable identity from UserDefaults, or create + persist one if absent.
    /// Same device → same PlayerID across launches, so reconnects don't duplicate seats.
    public static func loadOrCreate(defaults: UserDefaults = .standard) -> PeerIdentity {
        let idKey = "ppoker.identity.playerID"
        let keyKey = "ppoker.identity.privateKey"
        if let idString = defaults.string(forKey: idKey),
           let uuid = UUID(uuidString: idString),
           let keyData = defaults.data(forKey: keyKey),
           let identity = try? PeerIdentity(playerID: PlayerID(uuid), privateKeyRaw: keyData) {
            return identity
        }
        let fresh = PeerIdentity()
        defaults.set(fresh.playerID.raw.uuidString, forKey: idKey)
        defaults.set(fresh.privateKey.rawRepresentation, forKey: keyKey)
        return fresh
    }
}

/// Maps PlayerID → public key. Built up during lobby handshake and frozen at game start.
public struct PeerRegistry: Sendable {
    public private(set) var keys: [PlayerID: Data]

    public init(keys: [PlayerID: Data] = [:]) {
        self.keys = keys
    }

    public mutating func register(playerID: PlayerID, publicKeyRaw: Data) {
        keys[playerID] = publicKeyRaw
    }

    public func publicKey(for player: PlayerID) -> Curve25519.Signing.PublicKey? {
        guard let raw = keys[player] else { return nil }
        return try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
    }

    public func verify(signature: Data, for data: Data, by player: PlayerID) -> Bool {
        guard let key = publicKey(for: player) else { return false }
        return key.isValidSignature(signature, for: data)
    }
}
