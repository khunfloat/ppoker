import Testing
import Foundation
@testable import PPokerNetworking
@testable import PPokerEngine

@Suite("Coordinator integration")
struct CoordinatorTests {
    @Test func twoPlayerLobbyAndHandStart() async throws {
        let bus = MockTransport.Bus()
        let hostT = MockTransport(localPeer: TransportPeerID("host"), bus: bus)
        let clientT = MockTransport(localPeer: TransportPeerID("client"), bus: bus)
        let clock = ManualClock(start: 0)

        let host = HostCoordinator(
            displayName: "Host", config: .default, transport: hostT,
            clock: clock, deckSeedSource: 12345
        )
        let client = ClientCoordinator(
            displayName: "Client", transport: clientT, clock: clock
        )

        try await host.start(roomName: "Test")
        try await client.startBrowsing()
        try await client.join(host: hostT.localPeer)

        // Allow async dispatch to flush.
        try await Task.sleep(nanoseconds: 200_000_000)

        let lobbyCount = await host.lobbyPlayers.count
        #expect(lobbyCount == 2)

        try await host.startGame()
        try await Task.sleep(nanoseconds: 200_000_000)

        let hostHandCount = await host.state.handCount
        #expect(hostHandCount == 1)
        let clientHandCount = await client.state.handCount
        #expect(clientHandCount == 1)
    }
}
