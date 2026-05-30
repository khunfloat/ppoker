import Foundation
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity

/// Production transport backed by MultipeerConnectivity.
public final class MultipeerTransport: NSObject, Transport, @unchecked Sendable {
    public let localPeer: TransportPeerID
    public private(set) var mode: TransportMode = .idle

    private let mcPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let serviceType: String

    private var peerLookup: [MCPeerID: TransportPeerID] = [:]

    public let messageStream: AsyncStream<TransportMessage>
    public let peerEventStream: AsyncStream<PeerEvent>
    private let messageContinuation: AsyncStream<TransportMessage>.Continuation
    private let eventContinuation: AsyncStream<PeerEvent>.Continuation

    public init(displayName: String, serviceType: String = lobbyServiceType) {
        self.serviceType = serviceType
        self.mcPeer = MCPeerID(displayName: displayName)
        self.localPeer = TransportPeerID(mcPeer.displayName)
        self.session = MCSession(
            peer: mcPeer, securityIdentity: nil, encryptionPreference: .required
        )

        var mc: AsyncStream<TransportMessage>.Continuation!
        self.messageStream = AsyncStream { mc = $0 }
        self.messageContinuation = mc
        var ec: AsyncStream<PeerEvent>.Continuation!
        self.peerEventStream = AsyncStream { ec = $0 }
        self.eventContinuation = ec

        super.init()
        session.delegate = self
    }

    public func startHosting(roomName: String, discoveryInfo: [String: String]) throws {
        var info = discoveryInfo
        info["roomName"] = roomName
        info["role"] = "host"
        let adv = MCNearbyServiceAdvertiser(
            peer: mcPeer, discoveryInfo: info, serviceType: serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        self.advertiser = adv
        self.mode = .hosting(roomName: roomName)
    }

    public func startBrowsing(discoveryInfo: [String: String]) throws {
        let br = MCNearbyServiceBrowser(peer: mcPeer, serviceType: serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        self.browser = br
        self.mode = .browsing
    }

    public func connect(to peer: TransportPeerID, context: Data?) throws {
        guard let mcPeer = peerLookup.first(where: { $0.value == peer })?.key else {
            throw TransportError.unknownPeer(peer)
        }
        browser?.invitePeer(mcPeer, to: session, withContext: context, timeout: 10)
    }

    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        advertiser = nil
        browser = nil
        mode = .idle
    }

    public func send(_ data: Data, to peer: TransportPeerID?) throws {
        let targets: [MCPeerID]
        if let peer {
            // Only consider currently-connected MCPeerIDs that map to this TransportPeerID.
            // Stale entries (from a prior session of the same display name) are filtered out.
            let candidates = session.connectedPeers.filter { peerLookup[$0] == peer }
            guard let mcPeer = candidates.first else {
                throw TransportError.unknownPeer(peer)
            }
            targets = [mcPeer]
        } else {
            targets = session.connectedPeers
        }
        guard !targets.isEmpty else {
            if peer == nil { return }
            throw TransportError.notConnected
        }
        do {
            try session.send(data, toPeers: targets, with: .reliable)
        } catch {
            throw TransportError.sendFailed(error.localizedDescription)
        }
    }

    private func register(_ mcPeer: MCPeerID) -> TransportPeerID {
        if let existing = peerLookup[mcPeer] { return existing }
        let id = TransportPeerID(mcPeer.displayName)
        peerLookup[mcPeer] = id
        return id
    }
}

extension MultipeerTransport: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let id = register(peerID)
        switch state {
        case .notConnected:
            peerLookup[peerID] = nil
            eventContinuation.yield(.disconnected(id))
        case .connecting:
            eventContinuation.yield(.connecting(id))
        case .connected:
            eventContinuation.yield(.connected(id))
        @unknown default: break
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let id = register(peerID)
        messageContinuation.yield(TransportMessage(from: id, data: data))
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        _ = register(peerID)
        // Auto-accept all invitations in the lobby; gate via LobbyMessage.joinRejected if needed.
        invitationHandler(true, session)
    }
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let id = register(peerID)
        eventContinuation.yield(.discovered(id, info: info ?? [:]))
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let id = register(peerID)
        eventContinuation.yield(.lost(id))
    }
}
#endif
