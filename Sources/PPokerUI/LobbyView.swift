#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine
import PPokerNetworking

public struct LobbyView: View {
    @EnvironmentObject var app: AppState

    public init() {}

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                roomBanner
                roster
                Spacer()
                footer
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack {
            Button { Task { await leave() } } label: {
                Image(systemName: "chevron.left").foregroundStyle(.white).font(.system(size: 18, weight: .semibold))
            }
            Spacer()
            Text(app.role == .hosting ? "Hosting" : "Lobby")
                .foregroundStyle(.white).font(.headline)
            Spacer()
            Color.clear.frame(width: 18, height: 18)
        }
    }

    private var roomBanner: some View {
        VStack(spacing: 6) {
            Text(roomTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text("Blinds \(roomConfig.smallBlind)/\(roomConfig.bigBlind) · Buy-in \(roomConfig.defaultBuyIn)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(PPTheme.panel)
        .cornerRadius(12)
    }

    private var roomTitle: String {
        // Prefer the host's display name (works for both host and joiner).
        if let hostID = app.gameState.hostID,
           let host = app.gameState.players.first(where: { $0.id == hostID }) {
            return "\(host.displayName)'s table"
        }
        if !app.displayName.isEmpty { return "\(app.displayName)'s table" }
        return "Room"
    }

    private var roomConfig: TableConfig {
        // After joinAccepted/syncResponse, the authoritative config lives in gameState.
        app.gameState.config.bigBlind > 0 ? app.gameState.config : app.pendingConfig
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Players (\(app.lobbyPlayers.count))")
                .foregroundStyle(.white.opacity(0.6))
                .font(.subheadline)
            ForEach(sortedPlayers, id: \.id) { p in
                HStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(initialFor(p.name))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                    Text(p.name).foregroundStyle(.white)
                    Spacer()
                    if isHost(p.id) {
                        Text("HOST").font(.caption2).bold().padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.white.opacity(0.15)).foregroundStyle(.white).cornerRadius(4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PPTheme.panel)
                .cornerRadius(8)
            }
        }
    }

    private var footer: some View {
        Group {
            if app.role == .hosting {
                Button {
                    Task {
                        await app.startGame()
                        app.route = .table
                    }
                } label: {
                    Text(app.lobbyPlayers.count < 2 ? "Waiting for players..." : "Start Game")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PPPrimaryButton())
                .disabled(app.lobbyPlayers.count < 2)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for host to start…")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var sortedPlayers: [LobbyPlayer] {
        app.lobbyPlayers.sorted { $0.joinTimestamp < $1.joinTimestamp }
    }

    private func isHost(_ id: PlayerID) -> Bool {
        app.gameState.hostID == id
    }

    private func initialFor(_ name: String) -> String {
        String(name.prefix(1)).uppercased()
    }

    private func leave() async {
        app.goHome()
    }
}
#endif
