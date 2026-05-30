#if canImport(SwiftUI)
import SwiftUI
import Combine
import PPokerEngine
import PPokerNetworking

public enum SessionRole: Equatable {
    case none
    case hosting
    case joining
}

public enum AppRoute: Equatable {
    case home
    case hostSetup
    case lobby
    case browse
    case table
    case stats
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var route: AppRoute = .home
    @Published public var role: SessionRole = .none
    @Published public var displayName: String = ""
    @Published public var pendingConfig: TableConfig = .default

    // Mirror of coordinator state, refreshed on event ticks.
    @Published public var lobbyPlayers: [LobbyPlayer] = []
    @Published public var gameState: GameState = GameState()
    @Published public var myPlayer: Player?
    @Published public var availableRooms: [TransportPeerID: [String: String]] = [:]
    @Published public var hapticEnabled: Bool = true
    @Published public var migrationOutcome: MigrationOutcome?
    @Published public var sessionStats: [PlayerSessionStats] = []
    @Published public var currentLog: GameLog = GameLog()
    @Published public var actorTimerStart: TimeInterval?
    @Published public var handCompleteAt: TimeInterval?
    private var lastTrackedActorKey: String?
    private var lastHandStreet: Street?

    public private(set) var host: HostCoordinator?
    public private(set) var client: ClientCoordinator?
    public private(set) var transport: Transport?

    private var refreshTask: Task<Void, Never>?

    public init() {}

    public func goHome() {
        teardown()
        route = .home
        role = .none
    }

    public func beginHosting() async {
        let identity = PeerIdentity.loadOrCreate()
        #if canImport(MultipeerConnectivity)
        let t = MultipeerTransport(displayName: displayName.isEmpty ? "Host" : displayName)
        #else
        let bus = MockTransport.Bus()
        let t = MockTransport(localPeer: TransportPeerID(displayName), bus: bus)
        #endif
        transport = t
        let host = HostCoordinator(
            displayName: displayName, config: pendingConfig,
            transport: t, identity: identity
        )
        self.host = host
        do {
            try await host.start(roomName: "\(displayName)'s table")
            role = .hosting
            route = .lobby
            startRefresh()
        } catch {
            // surface error to UI eventually
        }
    }

    public func beginJoining() async {
        let identity = PeerIdentity.loadOrCreate()
        #if canImport(MultipeerConnectivity)
        let t = MultipeerTransport(displayName: displayName.isEmpty ? "Player" : displayName)
        #else
        let bus = MockTransport.Bus()
        let t = MockTransport(localPeer: TransportPeerID(displayName), bus: bus)
        #endif
        transport = t
        let client = ClientCoordinator(
            displayName: displayName, transport: t, identity: identity
        )
        self.client = client
        do {
            try await client.startBrowsing()
            role = .joining
            route = .browse
            startRefresh()
        } catch {}
    }

    public func joinRoom(_ peer: TransportPeerID) async {
        guard let client else { return }
        try? await client.join(host: peer)
        route = .lobby
    }

    public func startGame() async {
        try? await host?.startGame()
    }

    public func endSession() async {
        try? await host?.endSession()
        route = .stats
    }

    public func sendAction(_ action: BettingAction) async {
        if let host {
            try? await host.applyOwnAction(action)
            return
        }
        try? await client?.sendAction(action)
    }

    public func sitOut() async {
        if let host { try? await host.requestSitOut(); return }
        try? await client?.sendSitOut()
    }

    public func sitIn() async {
        if let host { try? await host.requestSitIn(); return }
        try? await client?.sendSitIn()
    }

    public func topUp(amount: Int) async {
        if let host { try? await host.topUp(amount: amount); return }
        try? await client?.sendTopUp(amount: amount)
    }

    // MARK: - Refresh

    private func startRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshSnapshot()
                try? await Task.sleep(nanoseconds: 100_000_000)   // 10 Hz
            }
        }
    }

    private func refreshSnapshot() async {
        if let host {
            let lobby = await Array(host.lobbyPlayers.values)
            let state = await host.state
            let log = await host.log
            self.lobbyPlayers = lobby
            self.gameState = state
            self.currentLog = log
            self.sessionStats = SessionAggregator.aggregate(state: state, log: log)
            autoRoute()
        } else if let client {
            let snap = await client.snapshot()
            let lobby = Array(snap.lobbyPlayers.values)
            let state = await client.state
            let log = await client.log
            let me = await client.myPlayer
            let outcome = await client.migrationOutcome
            let rooms = await client.availableRooms
            self.lobbyPlayers = lobby
            self.gameState = state
            self.currentLog = log
            self.sessionStats = SessionAggregator.aggregate(state: state, log: log)
            self.myPlayer = me
            self.migrationOutcome = outcome
            self.availableRooms = rooms
            autoRoute()
        }
    }

    private func autoRoute() {
        // Lobby → Table when first hand starts.
        if route == .lobby && gameState.currentHand != nil {
            route = .table
        }
        // Anywhere → Stats when session ends.
        if gameState.ended && route != .stats {
            route = .stats
        }
        // Reset actor timer whenever the actor or hand changes.
        let key: String
        if let hand = gameState.currentHand, hand.street != .complete {
            key = "\(hand.handNumber)-\(hand.street.rawValue)-\(hand.bettingRound.actorIndex)"
        } else {
            key = "idle"
        }
        if key != lastTrackedActorKey {
            lastTrackedActorKey = key
            if key == "idle" || gameState.isPaused {
                actorTimerStart = nil
            } else {
                actorTimerStart = Date().timeIntervalSince1970
            }
        }

        // Track hand-complete transition for the countdown modal.
        let curStreet = gameState.currentHand?.street
        if curStreet == .complete && lastHandStreet != .complete {
            handCompleteAt = Date().timeIntervalSince1970
        }
        if curStreet != .complete && lastHandStreet == .complete {
            handCompleteAt = nil
        }
        lastHandStreet = curStreet
    }

    public func teardown() {
        refreshTask?.cancel()
        refreshTask = nil
        transport?.stop()
        host = nil
        client = nil
        transport = nil
        lobbyPlayers = []
        gameState = GameState()
        myPlayer = nil
    }
}
#endif
