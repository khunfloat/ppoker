#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct TableView: View {
    @EnvironmentObject var app: AppState
    @State private var showingTopUp = false
    @State private var showingSettings = false
    @State private var statsPlayerID: PlayerID?

    public init() {}

    public var body: some View {
        ZStack {
            PPTheme.tableBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                topBar
                opponentsArea
                feltCenter
                Spacer(minLength: 0)
                myArea
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if app.gameState.isPaused {
                PauseOverlayView(
                    hostName: hostName,
                    isHost: app.role == .hosting,
                    onResume: { Task { try? await app.host?.resume() } },
                    onEnd: { Task { await app.endSession() } }
                )
            }

            if let endedAt = app.handCompleteAt, !app.gameState.ended {
                NextHandCountdownModal(
                    startedAt: endedAt,
                    winners: app.gameState.currentHand?.winners ?? [],
                    players: app.gameState.players,
                    canTopUp: mySeat.map(canTopUp) ?? false,
                    onTopUp: { showingTopUp = true }
                )
            }
        }
        .sheet(isPresented: $showingTopUp) {
            if let me = mySeat {
                TopUpSheet(currentStack: me.stack, maxBuyIn: app.gameState.config.maxBuyIn)
                    .environmentObject(app)
            }
        }
        .sheet(item: $statsPlayerID) { id in
            PlayerStatsSheet(playerID: id)
                .environmentObject(app)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(current: app.gameState.config)
                .environmentObject(app)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { app.goHome() } label: {
                Image(systemName: "chevron.left").foregroundStyle(.white)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Hand #\(app.gameState.handCount)")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                if let next = app.gameState.pendingConfig {
                    Text("Blinds \(app.gameState.config.smallBlind)/\(app.gameState.config.bigBlind) → \(next.smallBlind)/\(next.bigBlind)")
                        .font(.caption2).foregroundStyle(.yellow.opacity(0.8))
                } else {
                    Text("Blinds \(app.gameState.config.smallBlind)/\(app.gameState.config.bigBlind)")
                        .font(.caption2).foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            Menu {
                if let me = mySeat {
                    if me.status == .sittingOut || me.pendingSitOut {
                        Button("Sit In") { Task { await app.sitIn() } }
                    } else {
                        Button("Sit Out") { Task { await app.sitOut() } }
                    }
                    if me.stack < app.gameState.config.maxBuyIn && betweenHands {
                        Button("Top Up") { showingTopUp = true }
                    }
                }
                if app.role == .hosting {
                    Button("Settings") { showingSettings = true }
                    if app.gameState.isPaused {
                        Button("Resume") { Task { try? await app.host?.resume() } }
                    } else {
                        Button("Pause") { Task { try? await app.host?.pause() } }
                    }
                    Button("End Session", role: .destructive) {
                        Task { await app.endSession() }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.white)
            }
        }
    }

    // MARK: - Opponents row

    private var opponentsArea: some View {
        let opponents = otherPlayers
        return HStack(spacing: 10) {
            ForEach(opponents, id: \.id) { p in
                opponentSeat(p)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
    }

    @ViewBuilder
    private func opponentSeat(_ player: Player) -> some View {
        VStack(spacing: 6) {
            if showOpponentCards(for: player) {
                HStack(spacing: 4) {
                    ForEach(0..<min(player.holeCards.count, 2), id: \.self) { i in
                        CardView(card: player.holeCards[i], width: 30)
                    }
                }
            } else if player.isInHand {
                HStack(spacing: 4) {
                    CardBackView(width: 26)
                    CardBackView(width: 26)
                }
            } else {
                Color.clear.frame(height: 36)
            }
            Button { statsPlayerID = player.id } label: {
                PlayerSeatView(
                    player: player,
                    isActor: isActor(player.id),
                    isButton: isButton(player.id),
                    isMe: false,
                    timerStart: isActor(player.id) ? app.actorTimerStart : nil,
                    timerDuration: isActor(player.id) ? timerDuration : nil
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Felt center (board + pot)

    private var feltCenter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    if i < (app.gameState.currentHand?.board.count ?? 0) {
                        CardView(card: app.gameState.currentHand!.board[i], width: 42)
                    } else {
                        CardPlaceholderView(width: 42)
                    }
                }
            }
            potDisplay
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.3))
        )
    }

    private var potDisplay: some View {
        let pots = app.gameState.currentHand?.pots ?? []
        let live = liveContributions()
        return VStack(spacing: 2) {
            Text("POT").font(.caption2).foregroundStyle(.white.opacity(0.5))
            if pots.isEmpty {
                Text("\(live)")
                    .font(.chipNumber(size: 22))
                    .foregroundStyle(.white)
            } else {
                HStack(spacing: 12) {
                    ForEach(Array(pots.enumerated()), id: \.offset) { (i, pot) in
                        VStack {
                            Text(i == 0 ? "Main" : "Side \(i)")
                                .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            Text("\(pot.amount)")
                                .font(.chipNumber(size: 18))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    // MARK: - My area (bottom)

    @ViewBuilder
    private var myArea: some View {
        if let me = mySeat {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    HoleCardsView(cards: me.holeCards, width: 56)
                    Button { statsPlayerID = me.id } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(me.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                if isButton(me.id) {
                                    Text("D")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.black)
                                        .frame(width: 16, height: 16)
                                        .background(Circle().fill(.white))
                                }
                            }
                            Text("\(me.stack)")
                                .font(.chipNumber(size: 18))
                                .foregroundStyle(.white)
                            if let pending = app.gameState.pendingTopUps[me.id], pending > 0 {
                                Text("+\(pending) next hand")
                                    .font(.caption2)
                                    .foregroundStyle(PPTheme.plPositive)
                            }
                            if me.committedThisRound > 0 {
                                Text("→ \(me.committedThisRound)")
                                    .font(.caption2)
                                    .foregroundStyle(PPTheme.actionPositive)
                            }
                            if me.status == .allIn {
                                Text("ALL-IN").font(.caption2).bold().foregroundStyle(PPTheme.actionDanger)
                            } else if me.status == .folded {
                                Text("FOLDED").font(.caption2).foregroundStyle(.white.opacity(0.5))
                            } else if me.status == .sittingOut {
                                Text("SITTING OUT").font(.caption2).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if canTopUp(me) {
                        Button { showingTopUp = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Top Up").font(.caption.bold())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(PPTheme.divider)
                            .cornerRadius(8)
                        }
                    }
                    if isActor(me.id), let timerStart = app.actorTimerStart, let dur = timerDuration {
                        myTimerRing(start: timerStart, duration: dur)
                    }
                }
                if myTurn, let hand = app.gameState.currentHand {
                    ActionPanelView(hand: hand, myPlayer: me) { action in
                        Task { await app.sendAction(action) }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(PPTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isActor(me.id) ? Color.yellow.opacity(0.8) : Color.clear, lineWidth: 2)
                    )
            )
        }
    }

    private func myTimerRing(start: TimeInterval, duration: TimeInterval) -> some View {
        TimelineView(.animation(minimumInterval: 0.1)) { ctx in
            let elapsed = ctx.date.timeIntervalSince1970 - start
            let remaining = max(0, min(1, 1 - elapsed / duration))
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: remaining)
                    .stroke(timerColor(remaining: remaining),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(ceil(duration - elapsed)))")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
        }
    }

    private func timerColor(remaining: Double) -> Color {
        if remaining > 0.5 { return .yellow }
        if remaining > 0.2 { return .orange }
        return PPTheme.actionDanger
    }

    // MARK: - Helpers

    private var otherPlayers: [Player] {
        let source = app.gameState.currentHand?.players ?? app.gameState.players
        return source.filter { $0.id != myID }
    }

    private var mySeat: Player? {
        guard let id = myID else { return nil }
        return app.gameState.currentHand?.players.first { $0.id == id }
            ?? app.gameState.players.first { $0.id == id }
    }

    private var myID: PlayerID? {
        if app.role == .hosting { return app.gameState.hostID }
        return app.myPlayer?.id
    }

    private var myTurn: Bool {
        guard let hand = app.gameState.currentHand, let id = myID else { return false }
        guard hand.street != .complete else { return false }
        return hand.players.indices.contains(hand.bettingRound.actorIndex)
            && hand.players[hand.bettingRound.actorIndex].id == id
    }

    private var betweenHands: Bool {
        app.gameState.currentHand == nil || app.gameState.currentHand?.street == .complete
    }

    private func canTopUp(_ player: Player) -> Bool {
        guard !app.gameState.isPaused else { return false }
        let pending = app.gameState.pendingTopUps[player.id] ?? 0
        return player.stack + pending < app.gameState.config.maxBuyIn
    }

    private var hostName: String {
        guard let hostID = app.gameState.hostID else { return "Host" }
        return app.gameState.players.first { $0.id == hostID }?.displayName ?? "Host"
    }

    private var timerDuration: TimeInterval? {
        app.gameState.config.actionTimerSeconds.map { TimeInterval($0) }
    }

    private func showOpponentCards(for player: Player) -> Bool {
        guard let hand = app.gameState.currentHand else { return false }
        return hand.street == .complete && player.status != .folded
    }

    private func isActor(_ id: PlayerID) -> Bool {
        guard let hand = app.gameState.currentHand, hand.street != .complete else { return false }
        let idx = hand.bettingRound.actorIndex
        return hand.players.indices.contains(idx) && hand.players[idx].id == id
    }

    private func isButton(_ id: PlayerID) -> Bool {
        guard let hand = app.gameState.currentHand else { return false }
        let idx = hand.buttonIndex
        return hand.players.indices.contains(idx) && hand.players[idx].id == id
    }

    private func liveContributions() -> Int {
        guard let hand = app.gameState.currentHand else { return 0 }
        return hand.players.map(\.totalCommitted).reduce(0, +)
    }
}

// MARK: - Countdown modal

public struct NextHandCountdownModal: View {
    public let startedAt: TimeInterval
    public let total: TimeInterval = 4
    public let winners: [HandWinner]
    public let players: [Player]
    public let canTopUp: Bool
    public let onTopUp: () -> Void

    public init(
        startedAt: TimeInterval,
        winners: [HandWinner],
        players: [Player],
        canTopUp: Bool,
        onTopUp: @escaping () -> Void
    ) {
        self.startedAt = startedAt
        self.winners = winners
        self.players = players
        self.canTopUp = canTopUp
        self.onTopUp = onTopUp
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Hand Complete")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                ForEach(winners, id: \.potIndex) { (w: HandWinner) in
                    winnerLine(w)
                }
                Divider().background(Color.white.opacity(0.15))
                TimelineView(.animation(minimumInterval: 0.2)) { ctx in
                    let elapsed = ctx.date.timeIntervalSince1970 - startedAt
                    let remaining = max(0, total - elapsed)
                    Text("Next hand in \(Int(ceil(remaining)))s")
                        .font(.system(size: 16, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                }
                if canTopUp {
                    Button(action: onTopUp) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Top Up").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(PPTheme.panel)
            )
        }
    }

    private func winnerLine(_ w: HandWinner) -> some View {
        let names = w.winners
            .compactMap { id in players.first { $0.id == id }?.displayName }
            .joined(separator: ", ")
        let suffix = w.handDescription.map { " — \($0)" } ?? ""
        return VStack(spacing: 2) {
            Text("\(names)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text("+\(w.perWinner) chips\(suffix)")
                .font(.system(size: 13))
                .foregroundStyle(PPTheme.plPositive)
        }
    }
}
#endif
