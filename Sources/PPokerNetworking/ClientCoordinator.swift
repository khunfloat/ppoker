import Foundation
import PPokerEngine

public enum ClientError: Error, Sendable {
    case noHost
    case notJoined
    case rejected(String)
}

public actor ClientCoordinator {
    public let identity: PeerIdentity
    public let displayName: String
    public private(set) var registry: PeerRegistry
    public private(set) var log: GameLog
    public private(set) var state: GameState
    public private(set) var hostPeer: TransportPeerID?
    public private(set) var myPlayer: Player?
    public private(set) var availableRooms: [TransportPeerID: [String: String]] = [:]
    public private(set) var connectedPlayerIDs: Set<PlayerID> = []
    public private(set) var migrationOutcome: MigrationOutcome?

    public let migrationStream: AsyncStream<MigrationOutcome>
    private let migrationContinuation: AsyncStream<MigrationOutcome>.Continuation

    private let transport: Transport
    private let clock: Clock
    private var pendingHelloFor: TransportPeerID?

    public init(
        displayName: String,
        transport: Transport,
        identity: PeerIdentity = PeerIdentity(),
        clock: Clock = SystemClock()
    ) {
        self.identity = identity
        self.displayName = displayName
        self.transport = transport
        self.clock = clock
        self.registry = PeerRegistry()
        self.log = GameLog()
        self.state = GameState()
        var mc: AsyncStream<MigrationOutcome>.Continuation!
        self.migrationStream = AsyncStream { mc = $0 }
        self.migrationContinuation = mc
    }

    public func startBrowsing() async throws {
        try transport.startBrowsing(discoveryInfo: [:])
        Task { await consumePeers() }
        Task { await consumeMessages() }
    }

    public func join(host: TransportPeerID) async throws {
        hostPeer = host
        pendingHelloFor = host
        try transport.connect(to: host, context: nil)
        // HELLO is sent from the .connected peer event below to avoid a race
        // where session.send runs before MCSession finishes the handshake.
    }

    private func sendHello(to host: TransportPeerID) {
        let hello = LobbyMessage.hello(
            playerID: identity.playerID,
            displayName: displayName,
            publicKey: identity.publicKeyData,
            version: lobbyProtocolVersion
        )
        if let data = try? LobbyCoder.encode(hello) {
            try? transport.send(data, to: host)
        }
    }

    public func snapshot() -> SessionSnapshot {
        SessionSnapshot(
            log: log, registry: registry, state: state,
            lobbyPlayers: state.players.reduce(into: [:]) { dict, p in
                dict[p.id] = LobbyPlayer(
                    id: p.id, name: p.displayName,
                    joinTimestamp: state.joinTimestamps[p.id] ?? 0
                )
            }
        )
    }

    public func sendAction(_ action: BettingAction) async throws {
        guard let hand = state.currentHand else { throw ClientError.notJoined }
        try await sendSigned(.playerAction(
            playerID: identity.playerID, action: action, handNumber: hand.handNumber
        ))
    }

    public func sendSitOut() async throws {
        try await sendSigned(.sitOutRequested(playerID: identity.playerID))
    }

    public func sendSitIn() async throws {
        try await sendSigned(.sitInRequested(playerID: identity.playerID))
    }

    public func sendTopUp(amount: Int) async throws {
        try await sendSigned(.topUp(playerID: identity.playerID, amount: amount))
    }

    private func sendSigned(_ event: GameEvent) async throws {
        guard let host = hostPeer else { throw ClientError.noHost }
        let signed = try Envelope.sign(
            event: event, sequence: -1, timestamp: clock.now(), identity: identity
        )
        try transport.send(LobbyCoder.encode(.event(signed)), to: host)
    }

    // MARK: - Streams

    private func consumePeers() async {
        for await event in transport.peerEventStream {
            await handlePeerEvent(event)
        }
    }

    private func consumeMessages() async {
        for await msg in transport.messageStream {
            await handleIncoming(msg)
        }
    }

    private func handlePeerEvent(_ event: PeerEvent) async {
        switch event {
        case let .discovered(peer, info):
            availableRooms[peer] = info
        case let .lost(peer):
            availableRooms[peer] = nil
            if peer == hostPeer { await handleHostDisconnect() }
        case let .connected(peer):
            if peer == pendingHelloFor {
                sendHello(to: peer)
                pendingHelloFor = nil
            }
        case let .disconnected(peer):
            if peer == hostPeer { await handleHostDisconnect() }
        default:
            break
        }
    }

    private func handleHostDisconnect() async {
        // Election among players whose public key we know AND who weren't the dead host.
        let deadHostID = state.hostID
        var candidates = Set(registry.keys.keys)
        if let deadHostID { candidates.remove(deadHostID) }

        // Without an explicit connectivity probe, we treat anyone registered as a candidate.
        // The HostCoordinator (after promotion) will resync.
        guard let newHost = HostElection.elect(
            candidates: candidates, joinTimestamps: state.joinTimestamps
        ) else {
            migrationOutcome = .sessionDead
            migrationContinuation.yield(.sessionDead)
            return
        }
        let outcome: MigrationOutcome = (newHost == identity.playerID)
            ? .becameHost
            : .waitingForNewHost(newHost)
        migrationOutcome = outcome
        migrationContinuation.yield(outcome)
    }

    private func handleIncoming(_ msg: TransportMessage) async {
        guard let message = try? LobbyCoder.decode(msg.data) else { return }
        switch message {
        case let .joinAccepted(player, keys):
            myPlayer = player
            registry = PeerRegistry(keys: keys)
        case let .joinRejected(reason):
            _ = reason
            hostPeer = nil
        case .roomInfo:
            // Host periodically rebroadcasts lobby snapshot; could surface to UI.
            break
        case let .event(signed):
            await ingest(signed)
        case let .syncResponse(events):
            for ev in events { await ingest(ev) }
        case .syncRequest, .hello, .startGame, .ping, .pong:
            break
        }
    }

    private func ingest(_ event: SignedEvent) async {
        if event.sequence < log.nextSequence { return }   // already have it
        do {
            try Envelope.verify(event, registry: registry)
        } catch {
            return  // drop unverifiable
        }
        do {
            try log.append(event)
            state.apply(event)
        } catch {
            // Out-of-order or unknown error: ask host for sync.
            if let host = hostPeer {
                let sync = LobbyMessage.syncRequest(sinceSequence: log.nextSequence)
                if let data = try? LobbyCoder.encode(sync) {
                    try? transport.send(data, to: host)
                }
            }
        }
    }
}
