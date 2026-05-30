# PPoker

Offline P2P Texas Hold'em for iOS 16+, built on Multipeer Connectivity. See [prd.md](prd.md) for the full spec.

## Layout

```
Sources/
  PPokerEngine/      Pure Swift game engine (cards, hand eval, betting, side pots, hand lifecycle, signed log replay)
  PPokerNetworking/  Transport abstraction, MultipeerConnectivity transport, Host/Client coordinators, host election
  PPokerStats/       GRDB-backed local stats persistence
  PPokerUI/          SwiftUI views, AppState, theme — wraps engine + networking for the iOS shell
  PPokerSmoke/       CLI smoke runner for engine + transport (validates logic without iOS)
Tests/
  PPokerEngineTests/      Engine unit tests (Swift Testing)
  PPokerNetworkingTests/  Coordinator + election tests
  PPokerUITests/          Snapshot tests (run via Xcode iOS simulator)
```

## Building

```bash
swift build              # compile all libs + smoke runner
swift run PPokerSmoke    # validate engine/transport/log/crypto/stats at runtime
swift test               # unit tests (requires Xcode toolchain for Swift Testing / XCTest runtime)
```

The CLI smoke runner is the fastest way to verify the engine is wired correctly. Swift Testing tests require running through Xcode (Apple's command-line tools alone ship the framework but not the runtime loader).

## Linting / formatting

```bash
swiftlint --strict
swiftformat --lint .
```

Configs are at `.swiftlint.yml` and `.swiftformat`.

## iOS app shell

The libraries here ship everything you need; the final iOS `.app` bundle is built by an Xcode project that imports `PPokerUI` and uses `PPokerScene`:

```swift
import SwiftUI
import PPokerUI

@main
struct PPokerApp: App {
    var body: some Scene {
        PPokerScene()
    }
}
```

To create the Xcode shell:

1. `File → New → Project → iOS App` (Interface: SwiftUI, Lifecycle: SwiftUI App).
2. In the new project, `File → Add Package Dependencies → Add Local…` and point at this repo.
3. Add `PPokerUI` to your app target dependencies.
4. Replace the generated `App` struct with the snippet above.
5. In the target's `Info.plist`, add Multipeer entitlements (Bonjour services + local network usage descriptions):
   - `NSBonjourServices` → array containing `_ppoker-lb1._tcp`, `_ppoker-lb1._udp`
   - `NSLocalNetworkUsageDescription` → `"Find nearby players for an offline poker game."`

## Architecture notes

- **Trusted-host model:** host performs all dealing/settling; clients send signed action intents.
- **Ed25519 signing:** every event is signed; the host's `GameLog.append(_:verifyingWith:)` verifies before applying.
- **Append-only log:** `GameLog` + `GameState.replay(_:)` lets new hosts reconstruct authoritative state after migration.
- **Deterministic election:** earliest joinTimestamp wins; UUID lex order breaks ties — so all peers pick the same new host without coordination.
- **Replication on join:** new joiners receive the full log via `syncResponse` immediately after `joinAccepted`.
- **Pause is host-only:** clients still peek hole cards, but actions and top-ups are rejected mid-pause. Auto-end after 30 minutes.

## Status

v1 milestones (see PRD §13):

- M0 Foundations ✓ (transport, signing, identity, lobby handshake, snapshot scaffolding)
- M1 Single-host MVP ✓ (one hand end-to-end)
- M2 Host migration ✓ (election + abort/restart)
- M3 Polish ✓ (stats, settings, privacy mode)
- TF1 TestFlight ↻ (pending Xcode signing + uploads)
# ppoker
