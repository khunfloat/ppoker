#if canImport(SwiftUI)
import SwiftUI
import PPokerNetworking

public struct BrowseRoomsView: View {
    @EnvironmentObject var app: AppState

    public init() {}

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                content
                Spacer()
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack {
            Button { app.goHome() } label: {
                Image(systemName: "chevron.left").foregroundStyle(.white).font(.system(size: 18, weight: .semibold))
            }
            Spacer()
            Text("Nearby Tables").foregroundStyle(.white).font(.headline)
            Spacer()
            Color.clear.frame(width: 18, height: 18)
        }
    }

    private var content: some View {
        Group {
            if app.availableRooms.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Looking for nearby rooms…")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(app.availableRooms.keys.sorted { $0.raw < $1.raw }), id: \.self) { peer in
                            let info = app.availableRooms[peer] ?? [:]
                            roomCell(peer: peer, info: info)
                        }
                    }
                }
            }
        }
    }

    private func roomCell(peer: TransportPeerID, info: [String: String]) -> some View {
        Button {
            Task {
                await app.joinRoom(peer)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info["roomName"] ?? peer.raw)
                        .foregroundStyle(.white)
                        .font(.system(size: 17, weight: .semibold))
                    Text(peer.raw)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PPTheme.panel)
            .cornerRadius(10)
        }
    }
}
#endif
