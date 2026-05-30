import Foundation

/// Derived from a GameLog by replay. All peers replay their replica independently to converge on state.
public struct GameState: Codable, Sendable {
    public var sessionID: UUID?
    public var hostID: PlayerID?
    public var config: TableConfig
    public var players: [Player]                       // ordered by join time
    public var joinTimestamps: [PlayerID: TimeInterval]
    public var buttonIndex: Int
    public var currentHand: HandState?
    public var preHandSnapshot: [PlayerID: Int]?       // stacks before current hand (used on abort)
    public var handCount: Int
    public var isPaused: Bool
    public var pausedBy: PlayerID?
    public var ended: Bool
    /// Top-ups requested while a hand is in progress. Applied at the next handStarted.
    public var pendingTopUps: [PlayerID: Int]
    /// Settings change queued while a hand is in progress. Applied at the next handStarted.
    public var pendingConfig: TableConfig?

    public init() {
        self.sessionID = nil
        self.hostID = nil
        self.config = .default
        self.players = []
        self.joinTimestamps = [:]
        self.buttonIndex = 0
        self.currentHand = nil
        self.preHandSnapshot = nil
        self.handCount = 0
        self.isPaused = false
        self.pausedBy = nil
        self.ended = false
        self.pendingTopUps = [:]
        self.pendingConfig = nil
    }

    /// Replays the log into a fresh GameState. Pure function — input log → output state.
    public static func replay(_ log: GameLog) -> GameState {
        var state = GameState()
        for ev in log.events {
            state.apply(ev)
        }
        return state
    }

    public mutating func apply(_ envelope: SignedEvent) {
        switch envelope.event {
        case let .sessionStarted(config, hostID, sessionID):
            self.config = config
            self.hostID = hostID
            self.sessionID = sessionID

        case let .playerJoined(player, joinTimestamp):
            if !players.contains(where: { $0.id == player.id }) {
                players.append(player)
                joinTimestamps[player.id] = joinTimestamp
            }

        case let .playerLeft(playerID):
            players.removeAll { $0.id == playerID }
            joinTimestamps[playerID] = nil

        case let .handStarted(handNumber, buttonIndex, deckSeed, participants):
            self.buttonIndex = buttonIndex
            self.handCount = handNumber
            // Apply pending settings change first so blind / buy-in caps reflect the new config.
            if let pc = pendingConfig {
                self.config = pc
                self.pendingConfig = nil
            }
            // Apply any pending top-ups before the new hand snapshots stacks.
            for (pid, amount) in pendingTopUps {
                if let idx = players.firstIndex(where: { $0.id == pid }) {
                    let cap = max(0, config.maxBuyIn - players[idx].stack)
                    players[idx].stack += min(amount, cap)
                }
            }
            pendingTopUps.removeAll()
            self.preHandSnapshot = Dictionary(
                uniqueKeysWithValues: players.map { ($0.id, $0.stack) }
            )
            let inHand = players.filter { participants.contains($0.id) }
            guard inHand.count >= 2 else { return }
            var rng = SeededRNG(seed: deckSeed)
            self.currentHand = HandState.start(
                config: config,
                players: players,
                buttonIndex: buttonIndex,
                handNumber: handNumber,
                rng: &rng
            )

        case let .playerAction(playerID, action, _):
            guard currentHand != nil else { return }
            try? currentHand?.apply(action, by: playerID)
            syncStacksFromHand()

        case let .sitOutRequested(playerID):
            if let idx = players.firstIndex(where: { $0.id == playerID }) {
                players[idx].pendingSitOut = true
            }
            try? currentHand?.requestSitOut(by: playerID)
            syncStacksFromHand()

        case let .sitInRequested(playerID):
            if let idx = players.firstIndex(where: { $0.id == playerID }) {
                players[idx].pendingSitIn = true
            }
            try? currentHand?.requestSitIn(by: playerID)

        case let .topUp(playerID, amount):
            if let idx = players.firstIndex(where: { $0.id == playerID }) {
                let cap = max(0, config.maxBuyIn - players[idx].stack
                              - (pendingTopUps[playerID] ?? 0))
                let added = min(amount, cap)
                if let hand = currentHand, hand.street != .complete {
                    // Mid-hand: queue, apply at next handStarted.
                    pendingTopUps[playerID, default: 0] += added
                } else {
                    // Between hands: apply immediately so UI reflects updated stack.
                    players[idx].stack += added
                }
            }

        case .handAborted:
            // Restore pre-hand stacks.
            if let snap = preHandSnapshot {
                for (id, stack) in snap {
                    if let idx = players.firstIndex(where: { $0.id == id }) {
                        players[idx].stack = stack
                    }
                }
            }
            currentHand = nil

        case let .handSettled(_, finalStacks):
            for (id, stack) in finalStacks {
                if let idx = players.firstIndex(where: { $0.id == id }) {
                    players[idx].stack = stack
                }
            }
            // Keep currentHand alive so the UI can show the winner banner.
            // It will be replaced when the next .handStarted event arrives.

        case let .gamePaused(by):
            isPaused = true
            pausedBy = by

        case .gameResumed:
            isPaused = false
            pausedBy = nil

        case .sessionEnded:
            ended = true

        case let .configUpdated(newConfig):
            if currentHand != nil && currentHand?.street != .complete {
                // Mid-hand: queue for next hand.
                pendingConfig = newConfig
            } else {
                config = newConfig
            }
        }
    }

    private mutating func syncStacksFromHand() {
        guard let hand = currentHand else { return }
        for hp in hand.players {
            if let idx = players.firstIndex(where: { $0.id == hp.id }) {
                players[idx].stack = hp.stack
                players[idx].status = hp.status
                players[idx].pendingSitOut = hp.pendingSitOut
                players[idx].pendingSitIn = hp.pendingSitIn
            }
        }
    }
}
