import Testing
import Foundation
@testable import PPokerNetworking
@testable import PPokerEngine

@Suite("Lobby coder roundtrip")
struct LobbyCoderTests {
    @Test func helloRoundtrip() throws {
        let pid = PlayerID()
        let key = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let msg: LobbyMessage = .hello(playerID: pid, displayName: "Alice", publicKey: key, version: lobbyProtocolVersion)
        let data = try LobbyCoder.encode(msg)
        let decoded = try LobbyCoder.decode(data)
        if case let .hello(p, name, pk, v) = decoded {
            #expect(p == pid && name == "Alice" && pk == key && v == lobbyProtocolVersion)
        } else {
            Issue.record("Wrong case")
        }
    }

    @Test func roomInfoRoundtrip() throws {
        let host = PlayerID()
        let msg: LobbyMessage = .roomInfo(
            hostID: host, hostName: "Host",
            config: .default,
            players: [LobbyPlayer(id: host, name: "Host", joinTimestamp: 0)]
        )
        let data = try LobbyCoder.encode(msg)
        let decoded = try LobbyCoder.decode(data)
        if case let .roomInfo(h, n, _, ps) = decoded {
            #expect(h == host && n == "Host" && ps.count == 1)
        } else {
            Issue.record("Wrong case")
        }
    }

    @Test func eventRoundtrip() throws {
        let alice = PeerIdentity()
        let signed = try Envelope.sign(
            event: .sessionEnded, sequence: 0, timestamp: 0, identity: alice
        )
        let data = try LobbyCoder.encode(.event(signed))
        let decoded = try LobbyCoder.decode(data)
        if case let .event(ev) = decoded {
            #expect(ev.signerID == alice.playerID)
            #expect(ev.signature == signed.signature)
        } else {
            Issue.record("Wrong case")
        }
    }
}

@Suite("Mock transport")
struct MockTransportTests {
    @Test func twoPeersExchangeMessages() async throws {
        let bus = MockTransport.Bus()
        let host = MockTransport(localPeer: TransportPeerID("host"), bus: bus)
        let client = MockTransport(localPeer: TransportPeerID("client"), bus: bus)
        try host.startHosting(roomName: "Room", discoveryInfo: [:])
        try client.startBrowsing(discoveryInfo: [:])

        try client.connect(to: host.localPeer, context: nil)

        let payload = "ping".data(using: .utf8)!
        try host.send(payload, to: client.localPeer)

        var iter = client.messageStream.makeAsyncIterator()
        let received = await iter.next()
        #expect(received?.data == payload)
        #expect(received?.from == host.localPeer)

        host.stop(); client.stop()
    }
}
