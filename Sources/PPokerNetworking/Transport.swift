import Foundation
import PPokerEngine

public struct TransportPeerID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

public struct TransportMessage: Sendable {
    public let from: TransportPeerID
    public let data: Data

    public init(from: TransportPeerID, data: Data) {
        self.from = from
        self.data = data
    }
}

public enum PeerEvent: Sendable, Equatable {
    case discovered(TransportPeerID, info: [String: String])
    case lost(TransportPeerID)
    case connecting(TransportPeerID)
    case connected(TransportPeerID)
    case disconnected(TransportPeerID)
}

public enum TransportMode: Sendable, Equatable {
    case idle
    case hosting(roomName: String)
    case browsing
}

public enum TransportError: Error, Sendable, Equatable {
    case notConnected
    case unknownPeer(TransportPeerID)
    case invalidMode
    case sendFailed(String)
}

/// Abstract transport so the rest of the app doesn't depend on MultipeerConnectivity directly.
/// Concrete implementations: `MultipeerTransport` (production) and `MockTransport` (tests).
public protocol Transport: AnyObject, Sendable {
    var localPeer: TransportPeerID { get }
    var mode: TransportMode { get }

    var messageStream: AsyncStream<TransportMessage> { get }
    var peerEventStream: AsyncStream<PeerEvent> { get }

    func startHosting(roomName: String, discoveryInfo: [String: String]) throws
    func startBrowsing(discoveryInfo: [String: String]) throws
    func connect(to peer: TransportPeerID, context: Data?) throws
    func stop()

    /// Send to a specific peer, or broadcast when `to == nil`.
    func send(_ data: Data, to peer: TransportPeerID?) throws
}
