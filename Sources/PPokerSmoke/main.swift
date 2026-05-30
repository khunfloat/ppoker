import Foundation
import PPokerEngine
import PPokerNetworking
import PPokerStats

@MainActor
final class Runner {
    var failures = 0

    func check(_ name: String, _ cond: @autoclosure () -> Bool) {
        if cond() {
            print("  ✓ \(name)")
        } else {
            print("  ✗ \(name)")
            failures += 1
        }
    }

    func parse(_ s: String) -> Card {
        let rankChar = s.first!
        let suitChar = s.last!
        let rank: Rank
        switch rankChar {
        case "2": rank = .two
        case "3": rank = .three
        case "4": rank = .four
        case "5": rank = .five
        case "6": rank = .six
        case "7": rank = .seven
        case "8": rank = .eight
        case "9": rank = .nine
        case "T": rank = .ten
        case "J": rank = .jack
        case "Q": rank = .queen
        case "K": rank = .king
        case "A": rank = .ace
        default: fatalError()
        }
        let suit: Suit
        switch suitChar {
        case "s": suit = .spades
        case "h": suit = .hearts
        case "d": suit = .diamonds
        case "c": suit = .clubs
        default: fatalError()
        }
        return Card(rank, suit)
    }

    func cards(_ s: String) -> [Card] {
        s.split(separator: " ").map { parse(String($0)) }
    }

    func run() -> Int32 {
        print("Card/Deck smoke")
        do {
            let deck = Deck()
            check("52 cards", deck.count == 52)
            check("unique", Set(deck.cards).count == 52)
        }

        print("\nHand Evaluator smoke")
        check("high card",
            HandEvaluator.evaluate(cards("As Kd 9c 7h 3s")).category == .highCard)
        check("one pair",
            HandEvaluator.evaluate(cards("As Ad Kh 7c 3s")).category == .onePair)
        check("two pair",
            HandEvaluator.evaluate(cards("Ks Kd 7h 7c 3s")).category == .twoPair)
        check("trips",
            HandEvaluator.evaluate(cards("Ks Kd Kh 7c 3s")).category == .threeOfAKind)
        check("straight",
            HandEvaluator.evaluate(cards("9s 8d 7h 6c 5s")).category == .straight)
        check("wheel straight",
            HandEvaluator.evaluate(cards("As 2d 3h 4c 5s")).category == .straight)
        check("broadway",
            HandEvaluator.evaluate(cards("As Kd Qh Jc Ts")).tiebreakers == [.ace])
        check("flush",
            HandEvaluator.evaluate(cards("Ah Kh 9h 4h 2h")).category == .flush)
        check("full house",
            HandEvaluator.evaluate(cards("As Ad Ah 7c 7s")).category == .fullHouse)
        check("quads",
            HandEvaluator.evaluate(cards("As Ad Ah Ac 7s")).category == .fourOfAKind)
        check("straight flush",
            HandEvaluator.evaluate(cards("9h 8h 7h 6h 5h")).category == .straightFlush)
        check("royal flush",
            HandEvaluator.evaluate(cards("Ah Kh Qh Jh Th")).tiebreakers == [.ace])
        check("7-card royal",
            HandEvaluator.evaluate(cards("As Ks Qs Js Ts 2c 3d")).category == .straightFlush)
        check("flush beats straight",
            HandEvaluator.evaluate(cards("Ah Kh 9h 4h 2h"))
            > HandEvaluator.evaluate(cards("9s 8d 7h 6c 5s")))
        check("ties are equal",
            !(HandEvaluator.evaluate(cards("As Ad Kh 7c 3s"))
              < HandEvaluator.evaluate(cards("Ah Ac Kd 7s 3d")))
            && !(HandEvaluator.evaluate(cards("Ah Ac Kd 7s 3d"))
              < HandEvaluator.evaluate(cards("As Ad Kh 7c 3s"))))

        print("\nPot calculator smoke")
        do {
            let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
            let pots = PotCalculator.compute(contributions: [
                .init(player: a, amount: 100, folded: false),
                .init(player: b, amount: 100, folded: false),
                .init(player: c, amount: 100, folded: false),
            ])
            check("equal contribs → 1 pot", pots.count == 1 && pots[0].amount == 300)
        }
        do {
            let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
            let pots = PotCalculator.compute(contributions: [
                .init(player: a, amount: 100, folded: false),
                .init(player: b, amount: 200, folded: false),
                .init(player: c, amount: 200, folded: false),
            ])
            check("short all-in → 2 pots",
                pots.count == 2 && pots[0].amount == 300 && pots[1].amount == 200)
        }
        do {
            let a = PlayerID(); let b = PlayerID(); let c = PlayerID()
            let pots = PotCalculator.compute(contributions: [
                .init(player: a, amount: 50, folded: true),
                .init(player: b, amount: 100, folded: false),
                .init(player: c, amount: 100, folded: false),
            ])
            check("folded contributor merges", pots.count == 1 && pots[0].amount == 250
                && pots[0].eligiblePlayers == [b, c])
        }

        print("\nBetting round smoke")
        do {
            let players = [
                Player(displayName: "P0", stack: 100),
                Player(displayName: "P1", stack: 100),
                Player(displayName: "P2", stack: 100),
            ]
            var round = BettingRound(
                players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
            )
            do {
                try round.apply(.bet(10), by: players[0].id)
                try round.apply(.call, by: players[1].id)
                try round.apply(.raiseTo(30), by: players[2].id)
                check("raise reopens action", round.actorIndex == 0)
                try round.apply(.call, by: players[0].id)
                try round.apply(.call, by: players[1].id)
                check("round closes after all call", round.isRoundComplete)
                check("stacks decremented", round.players[0].stack == 70 && round.players[1].stack == 70 && round.players[2].stack == 70)
            } catch {
                check("betting flow no error: \(error)", false)
            }
        }
        do {
            let players = [
                Player(displayName: "Short", stack: 15),
                Player(displayName: "Big", stack: 100),
            ]
            var round = BettingRound(
                players: players, currentBet: 0, lastRaiseSize: 2, bigBlind: 2, actorIndex: 0
            )
            do {
                try round.apply(.allIn, by: players[0].id)
                check("short all-in → status", round.players[0].status == .allIn)
                try round.apply(.call, by: players[1].id)
                check("big calls all-in", round.isRoundComplete)
            } catch {
                check("all-in flow no error: \(error)", false)
            }
        }

        print("\nHandState smoke")
        do {
            let cfg = TableConfig(smallBlind: 1, bigBlind: 2, defaultBuyIn: 100, maxBuyIn: 200, actionTimerSeconds: 30)
            let p0 = Player(displayName: "P0", stack: 100)
            let p1 = Player(displayName: "P1", stack: 100)
            let p2 = Player(displayName: "P2", stack: 100)
            var rng = SeededRNG(seed: 42)
            var hand = HandState.start(
                config: cfg, players: [p0, p1, p2], buttonIndex: 0, handNumber: 1, rng: &rng
            )
            check("initial stacks total - blinds = expected", hand.players.map(\.stack).reduce(0,+) == 300 - 3)
            check("street=preflop", hand.street == .preflop)
            check("each player has 2 hole cards",
                hand.players.allSatisfy { $0.holeCards.count == 2 })

            // 3-player: button=P0, SB=P1, BB=P2, first to act = P0
            do {
                try hand.apply(.call, by: hand.bettingRound.actor.id)   // P0 calls
                try hand.apply(.call, by: hand.bettingRound.actor.id)   // P1 (SB) calls
                try hand.apply(.check, by: hand.bettingRound.actor.id)  // P2 (BB) checks
                check("advanced to flop", hand.street == .flop)
                check("board=3", hand.board.count == 3)

                // Check around the flop
                while hand.street == .flop {
                    try hand.apply(.check, by: hand.bettingRound.actor.id)
                }
                check("advanced to turn", hand.street == .turn)
                check("board=4", hand.board.count == 4)

                while hand.street == .turn {
                    try hand.apply(.check, by: hand.bettingRound.actor.id)
                }
                check("advanced to river", hand.street == .river)
                check("board=5", hand.board.count == 5)

                while hand.street == .river {
                    try hand.apply(.check, by: hand.bettingRound.actor.id)
                }
                check("hand complete", hand.street == .complete)
                check("zero-sum: stacks total = 300",
                    hand.players.map(\.stack).reduce(0,+) == 300)
                check("at least one winner", !hand.winners.isEmpty)
            } catch {
                check("hand flow no error: \(error)", false)
            }
        }
        do {
            // Fold-out scenario: 3 players, two fold preflop, third wins blinds.
            let cfg = TableConfig.default
            let p0 = Player(displayName: "P0", stack: 100)
            let p1 = Player(displayName: "P1", stack: 100)
            let p2 = Player(displayName: "P2", stack: 100)
            var rng = SeededRNG(seed: 7)
            var hand = HandState.start(
                config: cfg, players: [p0, p1, p2], buttonIndex: 0, handNumber: 1, rng: &rng
            )
            do {
                try hand.apply(.fold, by: hand.bettingRound.actor.id)   // P0
                try hand.apply(.fold, by: hand.bettingRound.actor.id)   // P1 (SB)
                check("hand ends on fold-out", hand.street == .complete)
                check("BB takes blinds", hand.players[2].stack == 100 + 1)
            } catch {
                check("fold-out no error: \(error)", false)
            }
        }

        print("\nGameLog + replay smoke")
        do {
            var log = GameLog()
            let host = PlayerID()
            let alice = Player(id: PlayerID(), displayName: "Alice", stack: 100)
            let bob = Player(id: PlayerID(), displayName: "Bob", stack: 100)
            let carol = Player(id: PlayerID(), displayName: "Carol", stack: 100)
            let sid = UUID()

            do {
                try log.append(.init(sequence: 0, timestamp: 0, signerID: host,
                    event: .sessionStarted(config: .default, hostID: host, sessionID: sid)))
                try log.append(.init(sequence: 1, timestamp: 1, signerID: host,
                    event: .playerJoined(player: alice, joinTimestamp: 1)))
                try log.append(.init(sequence: 2, timestamp: 2, signerID: host,
                    event: .playerJoined(player: bob, joinTimestamp: 2)))
                try log.append(.init(sequence: 3, timestamp: 3, signerID: host,
                    event: .playerJoined(player: carol, joinTimestamp: 3)))
                try log.append(.init(sequence: 4, timestamp: 4, signerID: host,
                    event: .handStarted(handNumber: 1, buttonIndex: 0,
                        deckSeed: 42, participants: [alice.id, bob.id, carol.id])))
                check("log size = 5", log.count == 5)
                check("nextSeq = 5", log.nextSequence == 5)
            } catch {
                check("append no error: \(error)", false)
            }

            let state = GameState.replay(log)
            check("replay sessionID matches", state.sessionID == sid)
            check("replay players = 3", state.players.count == 3)
            check("currentHand present", state.currentHand != nil)
            check("handCount = 1", state.handCount == 1)
            check("preHandSnapshot saved", state.preHandSnapshot?.count == 3)

            // Out-of-order rejection
            do {
                try log.append(.init(sequence: 99, timestamp: 5, signerID: host,
                    event: .sessionEnded))
                check("out-of-order rejected", false)
            } catch {
                check("out-of-order rejected", true)
            }

            // Fingerprint determinism
            let fp1 = log.fingerprint()
            let log2 = log
            let fp2 = log2.fingerprint()
            check("fingerprint deterministic", fp1 == fp2)

            // Merge
            var fresh = GameLog()
            do {
                try fresh.merge(log)
                check("merge brings empty log up to size",
                    fresh.count == log.count && fresh.fingerprint() == log.fingerprint())
            } catch {
                check("merge no error: \(error)", false)
            }
        }

        print("\nSigned envelope smoke")
        do {
            let alice = PeerIdentity()
            let bob = PeerIdentity()
            var registry = PeerRegistry()
            registry.register(playerID: alice.playerID, publicKeyRaw: alice.publicKeyData)
            registry.register(playerID: bob.playerID, publicKeyRaw: bob.publicKeyData)

            do {
                let event = try Envelope.sign(
                    event: .sessionEnded,
                    sequence: 0, timestamp: 1.0, identity: alice
                )
                check("signed event has signature", event.signature != nil)
                try Envelope.verify(event, registry: registry)
                check("verify alice's signature", true)
            } catch {
                check("alice sign/verify no error: \(error)", false)
            }

            // Tampered event should fail
            do {
                var event = try Envelope.sign(
                    event: .gamePaused(by: alice.playerID),
                    sequence: 0, timestamp: 1.0, identity: alice
                )
                event = SignedEvent(
                    sequence: event.sequence,
                    timestamp: event.timestamp,
                    signerID: event.signerID,
                    event: .gameResumed(by: alice.playerID),   // tamper with payload
                    signature: event.signature
                )
                do {
                    try Envelope.verify(event, registry: registry)
                    check("tampered event rejected", false)
                } catch {
                    check("tampered event rejected", true)
                }
            } catch {
                check("tamper-test sign no error: \(error)", false)
            }

            // GameLog rejects unsigned events when registry given
            do {
                var log = GameLog()
                let unsigned = SignedEvent(
                    sequence: 0, timestamp: 0, signerID: alice.playerID,
                    event: .sessionEnded, signature: nil
                )
                do {
                    try log.append(unsigned, verifyingWith: registry)
                    check("unsigned rejected by log", false)
                } catch {
                    check("unsigned rejected by log", true)
                }
            }

            // GameLog accepts valid signed events
            do {
                var log = GameLog()
                let event = try Envelope.sign(
                    event: .sessionEnded, sequence: 0, timestamp: 0, identity: alice
                )
                try log.append(event, verifyingWith: registry)
                check("verified append succeeds", log.count == 1)
            } catch {
                check("verified append no error: \(error)", false)
            }
        }

        print("\nLobby coder smoke")
        do {
            let alice = PeerIdentity()
            let event = try Envelope.sign(
                event: .sessionEnded, sequence: 0, timestamp: 0, identity: alice
            )
            let encoded = try LobbyCoder.encode(.event(event))
            let decoded = try LobbyCoder.decode(encoded)
            if case let .event(ev) = decoded {
                check("event roundtrip", ev.signerID == alice.playerID && ev.signature == event.signature)
            } else {
                check("event roundtrip case match", false)
            }
        } catch {
            check("lobby coder no error: \(error)", false)
        }

        print("\nMock transport smoke")
        do {
            let bus = MockTransport.Bus()
            let host = MockTransport(localPeer: TransportPeerID("host"), bus: bus)
            let client = MockTransport(localPeer: TransportPeerID("client"), bus: bus)
            try host.startHosting(roomName: "Room", discoveryInfo: [:])
            try client.startBrowsing(discoveryInfo: [:])
            try client.connect(to: host.localPeer, context: nil)

            // Sink to capture an inbound message.
            final class Sink: @unchecked Sendable {
                var payload: Data?
                let sem = DispatchSemaphore(value: 0)
            }
            let sink = Sink()
            let stream = client.messageStream
            Task.detached {
                for await msg in stream {
                    sink.payload = msg.data
                    sink.sem.signal()
                    break
                }
            }
            let payload = "ping".data(using: .utf8)!
            try host.send(payload, to: client.localPeer)
            _ = sink.sem.wait(timeout: .now() + 2)
            check("client received host msg", sink.payload == payload)

            host.stop()
            client.stop()
        } catch {
            check("mock transport no error: \(error)", false)
        }

        print("\nCoordinator smoke (host+client end-to-end)")
        do {
            final class Sink: @unchecked Sendable {
                var hostCount: Int = 0
                var clientCount: Int = 0
                let sem = DispatchSemaphore(value: 0)
            }
            let sink = Sink()

            Task.detached {
                do {
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
                    try await Task.sleep(nanoseconds: 200_000_000)
                    try await host.startGame()
                    try await Task.sleep(nanoseconds: 200_000_000)
                    sink.hostCount = await host.state.handCount
                    sink.clientCount = await client.state.handCount
                } catch {
                    // leave counts at 0
                }
                sink.sem.signal()
            }
            _ = sink.sem.wait(timeout: .now() + 5)
            check("host advanced to hand 1", sink.hostCount == 1)
            check("client mirrored hand 1", sink.clientCount == 1)
        }

        print("\nStats store smoke")
        do {
            final class Sink: @unchecked Sendable {
                var ok = false
                let sem = DispatchSemaphore(value: 0)
            }
            let sink = Sink()
            Task.detached {
                do {
                    let store = try await StatsStore.makeInMemory()
                    let session = StoredGameSession(
                        id: UUID().uuidString,
                        startedAt: Date(),
                        endedAt: nil,
                        hostID: "host-abc",
                        configJSON: "{}"
                    )
                    try await store.upsertSession(session)
                    try await store.upsertPlayerSession(StoredPlayerSession(
                        id: nil, sessionID: session.id, playerID: "p1",
                        displayName: "Alice", totalBuyIn: 100, finalStack: 150, handsPlayed: 5
                    ))
                    let sessions = try await store.listSessions()
                    let players = try await store.playerSessions(for: session.id)
                    sink.ok = (sessions.count == 1 && players.count == 1 && players.first?.finalStack == 150)
                } catch {
                    sink.ok = false
                }
                sink.sem.signal()
            }
            _ = sink.sem.wait(timeout: .now() + 5)
            check("session + player_session round-trip", sink.ok)
        }

        print("\nHost election smoke")
        do {
            let a = PlayerID()
            let b = PlayerID()
            let c = PlayerID()
            let elected = HostElection.elect(
                candidates: [a, b, c],
                joinTimestamps: [a: 30, b: 10, c: 20]
            )
            check("earliest joiner wins", elected == b)

            let aFixed = PlayerID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
            let bFixed = PlayerID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
            let tied = HostElection.elect(
                candidates: [aFixed, bFixed],
                joinTimestamps: [aFixed: 5, bFixed: 5]
            )
            check("tie → lex lower UUID wins", tied == aFixed)
        }

        print("\n\(failures == 0 ? "PASS" : "FAIL (\(failures))")")
        return failures == 0 ? 0 : 1
    }
}

exit(MainActor.assumeIsolated { Runner().run() })
