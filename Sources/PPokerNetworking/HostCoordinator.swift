import Foundation
import PPokerEngine

public enum HostError: Error, Sendable {
    case notReady
    case sessionEnded
    case invalidJoiner
    case logAppendFailed(String)
}

/// Host-side orchestration: accepts joiners, signs authoritative events, broadcasts.
public actor HostCoordinator {
    public let identity: PeerIdentity
    public let displayName: String
    public private(set) var config: TableConfig
    public private(set) var registry: PeerRegistry
    public private(set) var log: GameLog
    public private(set) var state: GameState
    public private(set) var lobbyPlayers: [PlayerID: LobbyPlayer] = [:]
    public private(set) var clientPeers: [PlayerID: TransportPeerID] = [:]

    private let transport: Transport
    private let clock: Clock
    private var sessionStarted = false
    private var deckSeedSource: UInt64

    public init(
        displayName: String,
        config: TableConfig,
        transport: Transport,
        identity: PeerIdentity = PeerIdentity(),
        clock: Clock = SystemClock(),
        deckSeedSource: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) {
        self.identity = identity
        self.displayName = displayName
        self.config = config
        self.registry = PeerRegistry()
        self.log = GameLog()
        self.state = GameState()
        self.transport = transport
        self.clock = clock
        self.deckSeedSource = deckSeedSource
    }

    /// Promote from a client snapshot when migrating.
    public init(
        promotedFrom snapshot: SessionSnapshot,
        identity: PeerIdentity,
        displayName: String,
        transport: Transport,
        clock: Clock = SystemClock(),
        deckSeedSource: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) {
        self.identity = identity
        self.displayName = displayName
        self.config = snapshot.state.config
        self.registry = snapshot.registry
        self.log = snapshot.log
        self.state = snapshot.state
        self.transport = transport
        self.clock = clock
        self.deckSeedSource = deckSeedSource
        self.lobbyPlayers = snapshot.lobbyPlayers
        self.sessionStarted = (snapshot.state.handCount > 0)
    }

    /// Take over hosting after election. If a hand was in progress, abort it and refund stacks.
    public func takeoverAfterMigration(roomName: String) async throws {
        try transport.startHosting(roomName: roomName, discoveryInfo: ["roomName": roomName])
        if state.currentHand != nil {
            try appendAndBroadcast(.handAborted(
                handNumber: state.handCount, reason: "Host migration"
            ))
        }
        Task { await consumeMessages() }
        if sessionStarted {
            try await startNextHand()
        }
    }

    public func start(roomName: String) async throws {
        try transport.startHosting(roomName: roomName, discoveryInfo: ["roomName": roomName])
        registry.register(playerID: identity.playerID, publicKeyRaw: identity.publicKeyData)

        let host = Player(
            id: identity.playerID, displayName: displayName, stack: config.defaultBuyIn
        )
        lobbyPlayers[identity.playerID] = LobbyPlayer(
            id: identity.playerID, name: displayName, joinTimestamp: clock.now()
        )

        try appendAndBroadcast(.sessionStarted(
            config: config, hostID: identity.playerID, sessionID: UUID()
        ))
        try appendAndBroadcast(.playerJoined(player: host, joinTimestamp: clock.now()))

        Task { await consumeMessages() }
        Task { await consumePeerEvents() }
    }

    public func startGame() async throws {
        guard !sessionStarted else { return }
        guard lobbyPlayers.count >= 2 else { throw HostError.notReady }
        sessionStarted = true
        startActionTimerLoop()
        try await startNextHand()
    }

    private func startActionTimerLoop() {
        actionTimerTask?.cancel()
        guard let timer = config.actionTimerSeconds else { return }   // nil = ∞
        let timerSeconds = TimeInterval(timer)
        actionTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.tickActionTimer(timerSeconds: timerSeconds)
            }
        }
    }

    private func tickActionTimer(timerSeconds: TimeInterval) async {
        guard !state.isPaused else { return }
        guard let hand = state.currentHand, hand.street != .complete else {
            trackedActorKey = nil
            return
        }
        let key = "\(hand.handNumber)-\(hand.street.rawValue)-\(hand.bettingRound.actorIndex)"
        if key != trackedActorKey {
            trackedActorKey = key
            actorStartedAt = clock.now()
            return
        }
        if clock.now() - actorStartedAt < timerSeconds { return }

        // Timeout fires: auto-check if free, else auto-fold.
        let idx = hand.bettingRound.actorIndex
        guard hand.players.indices.contains(idx) else { return }
        let actor = hand.players[idx]
        let action: BettingAction =
            (actor.committedThisRound == hand.bettingRound.currentBet) ? .check : .fold
        do {
            try appendAndBroadcast(.playerAction(
                playerID: actor.id, action: action, handNumber: hand.handNumber
            ))
            if state.currentHand?.street == .complete {
                try settleAndAdvance()
            }
        } catch {
            return
        }
        trackedActorKey = nil
    }

    public func endSession() async throws {
        try appendAndBroadcast(.sessionEnded)
    }

    /// Public entry so the UI can advance to the next hand after a winner is shown.
    public func startNextHandPublic() async throws {
        try await startNextHand()
    }

    private var pauseTimeoutTask: Task<Void, Never>?
    private var actionTimerTask: Task<Void, Never>?
    private var trackedActorKey: String?
    private var actorStartedAt: TimeInterval = 0

    public func pause() async throws {
        try appendAndBroadcast(.gamePaused(by: identity.playerID))
        // Auto-end the session after 30 minutes of pause, per PRD §7.8.
        pauseTimeoutTask?.cancel()
        pauseTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.timeoutPauseIfStillPaused()
        }
    }

    public func resume() async throws {
        try appendAndBroadcast(.gameResumed(by: identity.playerID))
        pauseTimeoutTask?.cancel()
        pauseTimeoutTask = nil
    }

    private func timeoutPauseIfStillPaused() async {
        if state.isPaused {
            try? appendAndBroadcast(.sessionEnded)
        }
    }

    /// Host's own player taking a betting action — bypasses transport, applies directly.
    public func applyOwnAction(_ action: BettingAction) async throws {
        guard !state.isPaused else { return }
        guard let hand = state.currentHand, hand.street != .complete else { return }
        var trial = hand
        try trial.apply(action, by: identity.playerID)
        try appendAndBroadcast(.playerAction(
            playerID: identity.playerID, action: action, handNumber: hand.handNumber
        ))
        if state.currentHand?.street == .complete {
            try settleAndAdvance()
        }
    }

    public func requestSitOut() async throws {
        try appendAndBroadcast(.sitOutRequested(playerID: identity.playerID))
    }

    public func requestSitIn() async throws {
        try appendAndBroadcast(.sitInRequested(playerID: identity.playerID))
    }

    public func topUp(amount: Int) async throws {
        try appendAndBroadcast(.topUp(playerID: identity.playerID, amount: amount))
        await resumeIfStalled()
    }

    /// Update table settings. Applies immediately if no hand is active, otherwise at the next hand.
    public func updateConfig(_ newConfig: TableConfig) async throws {
        self.config = newConfig
        try appendAndBroadcast(.configUpdated(config: newConfig))
    }

    // MARK: - Event flow

    private func consumeMessages() async {
        for await msg in transport.messageStream {
            await handleIncoming(msg)
        }
    }

    private func consumePeerEvents() async {
        for await event in transport.peerEventStream {
            switch event {
            case let .disconnected(peer), let .lost(peer):
                if let pid = clientPeers.first(where: { $0.value == peer })?.key {
                    clientPeers[pid] = nil
                    lobbyPlayers[pid] = nil
                    try? appendAndBroadcast(.playerLeft(playerID: pid))
                }
            default:
                break
            }
        }
    }

    private func handleIncoming(_ msg: TransportMessage) async {
        guard let message = try? LobbyCoder.decode(msg.data) else { return }
        switch message {
        case let .hello(playerID, displayName, publicKey, version):
            guard version == lobbyProtocolVersion else {
                try? sendLobby(.joinRejected(reason: "Protocol version mismatch"), to: msg.from)
                return
            }
            await acceptJoiner(playerID: playerID, name: displayName, publicKey: publicKey, peer: msg.from)
        case let .event(signed):
            await ingestClientAction(signed)
        case .syncRequest(let since):
            let pending = log.events.filter { $0.sequence >= since }
            try? sendLobby(.syncResponse(events: pending), to: msg.from)
        default:
            break  // host generally drives lobby messages; ignore unsolicited
        }
    }

    private func acceptJoiner(playerID: PlayerID, name: String, publicKey: Data, peer: TransportPeerID) async {
        // Re-attach: same identity rejoining (e.g. after going back to home + rejoining).
        // Update peer mapping + replay the log so the client can rebuild state.
        if lobbyPlayers[playerID] != nil {
            clientPeers[playerID] = peer
            if let existingPlayer = state.players.first(where: { $0.id == playerID }) {
                try? sendLobby(.joinAccepted(player: existingPlayer, registry: registry.keys), to: peer)
                try? sendLobby(.syncResponse(events: log.events), to: peer)
                try? sendLobby(.roomInfo(
                    hostID: identity.playerID,
                    hostName: displayName,
                    config: config,
                    players: Array(lobbyPlayers.values)
                ), to: peer)
            }
            await resumeIfStalled()
            return
        }

        registry.register(playerID: playerID, publicKeyRaw: publicKey)
        let player = Player(id: playerID, displayName: name, stack: config.defaultBuyIn)
        let joinTime = clock.now()
        lobbyPlayers[playerID] = LobbyPlayer(id: playerID, name: name, joinTimestamp: joinTime)
        clientPeers[playerID] = peer

        do {
            try appendAndBroadcast(.playerJoined(player: player, joinTimestamp: joinTime))
            try sendLobby(.joinAccepted(player: player, registry: registry.keys), to: peer)
            try sendLobby(.syncResponse(events: log.events), to: peer)
            try broadcastLobby(.roomInfo(
                hostID: identity.playerID,
                hostName: displayName,
                config: config,
                players: Array(lobbyPlayers.values)
            ))
        } catch {
            // swallow; client will retry on next handshake
        }
        await resumeIfStalled()
    }

    /// Called when a player joins/rejoins. If the table was waiting for a 2nd player
    /// after the previous hand finished, start the next hand now.
    private func resumeIfStalled() async {
        guard sessionStarted, !state.ended, !state.isPaused else { return }
        let needsNewHand = state.currentHand == nil || state.currentHand?.street == .complete
        guard needsNewHand else { return }
        guard viablePlayerCount >= 2 else { return }
        try? await startNextHand()
    }

    private func ingestClientAction(_ event: SignedEvent) async {
        do {
            try Envelope.verify(event, registry: registry)
        } catch {
            return  // reject invalid signature silently
        }
        // Pause gate: drop player actions and top-ups; allow sit-out/in flags to queue.
        if state.isPaused {
            switch event.event {
            case .sitOutRequested, .sitInRequested:
                break   // allowed
            default:
                return
            }
        }
        switch event.event {
        case let .playerAction(playerID, action, handNumber):
            guard handNumber == state.handCount else { return }
            guard playerID == event.signerID else { return }
            guard var trial = state.currentHand, trial.street != .complete else { return }
            do {
                try trial.apply(action, by: playerID)
            } catch {
                return
            }
            try? appendAndBroadcast(.playerAction(
                playerID: playerID, action: action, handNumber: handNumber
            ))
            if state.currentHand?.street == .complete {
                try? settleAndAdvance()
            }
        case let .sitOutRequested(playerID):
            guard playerID == event.signerID else { return }
            try? appendAndBroadcast(.sitOutRequested(playerID: playerID))
            if state.currentHand?.street == .complete {
                try? settleAndAdvance()
            }
        case let .sitInRequested(playerID):
            guard playerID == event.signerID else { return }
            try? appendAndBroadcast(.sitInRequested(playerID: playerID))
        case let .topUp(playerID, amount):
            guard playerID == event.signerID else { return }
            try? appendAndBroadcast(.topUp(playerID: playerID, amount: amount))
            await resumeIfStalled()
        default:
            return
        }
    }

    private func startNextHand() async throws {
        let participants = lobbyPlayers.values
            .sorted { $0.joinTimestamp < $1.joinTimestamp }
            .map(\.id)
        guard participants.count >= 2 else { throw HostError.notReady }

        let nextHandNumber = state.handCount + 1
        let buttonIndex = (state.buttonIndex + 1) % max(1, state.players.count)
        deckSeedSource &+= 1
        let seed = deckSeedSource ^ UInt64(nextHandNumber)

        try appendAndBroadcast(.handStarted(
            handNumber: nextHandNumber,
            buttonIndex: buttonIndex,
            deckSeed: seed,
            participants: participants
        ))
    }

    private func settleAndAdvance() throws {
        guard let hand = state.currentHand, hand.street == .complete else { return }
        let stacks = Dictionary(uniqueKeysWithValues: hand.players.map { ($0.id, $0.stack) })
        try appendAndBroadcast(.handSettled(handNumber: hand.handNumber, finalStacks: stacks))
        scheduleAutoAdvance()
    }

    private func scheduleAutoAdvance() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await self?.autoAdvanceIfPossible()
        }
    }

    private func autoAdvanceIfPossible() async {
        guard sessionStarted, !state.ended, !state.isPaused else { return }
        guard viablePlayerCount >= 2 else { return }
        try? await startNextHand()
    }

    private var viablePlayerCount: Int {
        lobbyPlayers.keys.compactMap { id in
            state.players.first(where: { $0.id == id })
        }.filter { p in
            p.stack + (state.pendingTopUps[p.id] ?? 0) > 0
        }.count
    }

    // MARK: - Helpers

    private func appendAndBroadcast(_ event: GameEvent) throws {
        let sequence = log.nextSequence
        let envelope = try Envelope.sign(
            event: event,
            sequence: sequence,
            timestamp: clock.now(),
            identity: identity
        )
        try log.append(envelope, verifyingWith: registry)
        state.apply(envelope)
        try broadcastLobby(.event(envelope))
    }

    private func broadcastLobby(_ message: LobbyMessage) throws {
        let data = try LobbyCoder.encode(message)
        try transport.send(data, to: nil)
    }

    private func sendLobby(_ message: LobbyMessage, to peer: TransportPeerID) throws {
        let data = try LobbyCoder.encode(message)
        try transport.send(data, to: peer)
    }
}
