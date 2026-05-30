import Foundation

/// In-process transport used by tests and the coordinator-level simulator.
/// All instances created with the same `bus` share a global routing table.
public final class MockTransport: Transport, @unchecked Sendable {
    public final class Bus: @unchecked Sendable {
        private let queue = DispatchQueue(label: "ppoker.mockbus")
        private var transports: [TransportPeerID: MockTransport] = [:]

        public init() {}

        func register(_ t: MockTransport) {
            queue.sync { transports[t.localPeer] = t }
        }

        func unregister(_ t: MockTransport) {
            queue.sync { transports[t.localPeer] = nil }
        }

        func announce(_ event: PeerEvent, except originator: TransportPeerID) {
            let snapshot: [MockTransport] = queue.sync {
                transports.values.filter { $0.localPeer != originator }
            }
            for t in snapshot { t.deliverEvent(event) }
        }

        func deliver(_ message: TransportMessage, to peer: TransportPeerID?) {
            let targets: [MockTransport] = queue.sync {
                if let peer { return [transports[peer]].compactMap { $0 } }
                return transports.values.filter { $0.localPeer != message.from }
            }
            for t in targets { t.deliverMessage(message) }
        }

        var allPeers: [TransportPeerID] {
            queue.sync { Array(transports.keys) }
        }
    }

    public let localPeer: TransportPeerID
    public private(set) var mode: TransportMode = .idle

    private let bus: Bus
    private let messageContinuation: AsyncStream<TransportMessage>.Continuation
    private let eventContinuation: AsyncStream<PeerEvent>.Continuation

    public let messageStream: AsyncStream<TransportMessage>
    public let peerEventStream: AsyncStream<PeerEvent>

    public init(localPeer: TransportPeerID, bus: Bus) {
        self.localPeer = localPeer
        self.bus = bus
        var mc: AsyncStream<TransportMessage>.Continuation!
        self.messageStream = AsyncStream { mc = $0 }
        self.messageContinuation = mc

        var ec: AsyncStream<PeerEvent>.Continuation!
        self.peerEventStream = AsyncStream { ec = $0 }
        self.eventContinuation = ec
    }

    public func startHosting(roomName: String, discoveryInfo: [String: String]) throws {
        mode = .hosting(roomName: roomName)
        bus.register(self)
        bus.announce(.discovered(localPeer, info: discoveryInfo), except: localPeer)
    }

    public func startBrowsing(discoveryInfo: [String: String]) throws {
        mode = .browsing
        bus.register(self)
        // Notify any hosts that are currently registered so they "see" the browser too.
        for peer in bus.allPeers where peer != localPeer {
            deliverEvent(.discovered(peer, info: [:]))
        }
    }

    public func connect(to peer: TransportPeerID, context: Data?) throws {
        bus.announce(.connecting(localPeer), except: localPeer)
        // Simulate immediate connection.
        deliverEvent(.connected(peer))
        bus.announce(.connected(localPeer), except: localPeer)
    }

    public func stop() {
        bus.announce(.disconnected(localPeer), except: localPeer)
        bus.unregister(self)
        mode = .idle
    }

    public func send(_ data: Data, to peer: TransportPeerID?) throws {
        bus.deliver(TransportMessage(from: localPeer, data: data), to: peer)
    }

    fileprivate func deliverMessage(_ msg: TransportMessage) {
        messageContinuation.yield(msg)
    }

    fileprivate func deliverEvent(_ ev: PeerEvent) {
        eventContinuation.yield(ev)
    }
}
