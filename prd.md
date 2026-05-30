# PRD — PPoker

**Status:** Draft v1
**Owner:** Float
**Last updated:** 2026-05-21
**Target platform:** iOS 16+, TestFlight distribution

---

## 1. Problem & Opportunity

เวลานั่งดื่ม / แคมป์ / อยู่ในที่ไม่มี internet กับเพื่อนกลุ่มเล็ก (2–8 คน) แล้วอยากเล่น poker — ตัวเลือกที่มีตอนนี้คือ:

- **ไพ่จริง + ชิปจริง** → พกพายาก, นับเงินยาก, ใครหายไปกลางทางก็เซ็ง
- **แอพ poker ออนไลน์** → ต้อง internet, มักจะมี matchmaking กับคนแปลกหน้า, ไม่ใช่ "เล่นกับเพื่อน" จริงๆ
- **แอพ poker offline แบบ pass-and-play** → ต้องส่งโทรศัพท์กันไปมา ช้า เสียอรรถรส

ยังไม่มีแอพไหนที่ "ทุกคนถือ iPhone ของตัวเอง + เล่นด้วยกันสดๆ ในห้องเดียวกัน + ไม่ต้องใช้ internet" ได้ดี.

**Opportunity:** iOS มี Multipeer Connectivity framework ที่ใช้ Bluetooth + peer-to-peer Wi-Fi ในตัว ไม่ต้องมี router/internet — เหมาะกับ scenario นี้พอดี.

---

## 2. Target User

- กลุ่มเพื่อน 2–8 คน ที่ใช้ iPhone ทุกคน
- เล่น poker เป็น (ไม่ต้องสอนกฎ)
- เน้น casual / party play — ไม่ใช่จริงจังระดับ tournament
- เป็น "วงเพื่อนที่ trust กันได้" — ไม่ใช่เล่นกับคนแปลกหน้า

**Non-users (v1):** คนที่อยากเล่นกับคนไกล / คนที่ต้องการ tournament / คนใช้ Android

---

## 3. Core Principles

1. **Offline-first** — ทำงานได้ 100% ในห้องที่ไม่มี internet
2. **Minimal friction** — เปิดแอพ → ห้องโผล่มา → กดเข้า → เล่น (3 tap)
3. **Trust your friends** — ออกแบบบนสมมติฐานว่าเล่นกับเพื่อนกลุ่มเล็ก ไม่ต้องป้องกัน cheating ทางเทคนิคแบบ casino-grade
4. **Couch-friendly UX** — ผู้เล่นนั่งติดกันได้ ดูจอกันได้ → ไพ่ส่วนตัวต้องป้องกันการเห็นโดยไม่ตั้งใจ
5. **Minimal aesthetic** — ไม่ใช่ casino-feel, เป็น productivity-tool feel ดูเป็นผู้ใหญ่

---

## 4. Scope

### 4.1 In Scope (v1)
- Texas Hold'em No-Limit, cash game format
- 2–8 ผู้เล่นต่อโต๊ะ
- Peer-to-peer networking via Multipeer Connectivity (Bluetooth + P2P Wi-Fi)
- Host migration เมื่อ host disconnect
- Action buttons: Fold, Check, Call, Raise
- Raise UI: preset (1/3, 1/2, 2/3, pot) + stepper (±1 BB) + slider (min raise → all-in)
- Sit-out / sit-in mid-session
- Host pause / resume game
- Auto-fold ตาม action timer
- Stats per session: buy-in, stack, P/L per player
- Settings (host-configurable): blinds, buy-in, max buy-in, action timer
- Press-and-hold เพื่อดูไพ่ตัวเอง
- Privacy mode: blur หน้าจอเมื่อ app background

### 4.2 Out of Scope (v1)
- Tournaments / blind levels increasing
- Multi-table
- Spectator mode
- Hand history / replay viewer
- iCloud sync of stats across devices
- Apple Watch companion
- Voice chat, emotes, chat
- Poker variants อื่น (Omaha, Stud, etc.)
- Android version
- Internet-based matchmaking
- Real money / in-app purchases

---

## 5. Architecture Overview

### 5.1 Trust Model
**Trusted-host model** — host เป็นผู้คำนวณทั้งหมด (shuffle, deal, phase transition, showdown). ผู้เล่น trust ว่า host (เพื่อนตัวเอง) ไม่โกง.

### 5.2 System Layers
```
┌─────────────────────────────────────────┐
│ UI Layer (SwiftUI)                      │
├─────────────────────────────────────────┤
│ Game Engine (pure Swift, no UI/network) │
├─────────────────────────────────────────┤
│ Host Coordinator   |  Client State      │
│ (only on host)     |  (only on clients) │
├─────────────────────────────────────────┤
│ State Replication (for host migration)  │
├─────────────────────────────────────────┤
│ Signed Message Envelope (Ed25519)       │
├─────────────────────────────────────────┤
│ Transport (MultipeerConnectivity)       │
└─────────────────────────────────────────┘
        ↕ Bluetooth / P2P Wi-Fi
```

### 5.3 Host Migration
ทุก peer เก็บ state replica แบบ append-only (signed action log). เมื่อ host disconnect:

- ทุก peer detect ผ่าน Multipeer disconnect callback
- Election: peer ที่ join เร็วที่สุด (เรียงตาม join timestamp) ที่ยังเชื่อมต่ออยู่ → เป็น host ใหม่
- ถ้ากำลังอยู่กลางมือ → host ใหม่ abort มือ, คืน chips ตามสภาพก่อนเริ่มมือ, เริ่มมือใหม่
- ถ้าระหว่างมือ → host ใหม่ขึ้นทันที, เริ่มมือถัดไปปกติ

### 5.4 Identity & Authentication
- แต่ละ peer สร้าง Ed25519 keypair ที่ session join
- แลก public key ใน lobby handshake
- ทุก message signed → ป้องกัน client ปลอม action ของคนอื่น

---

## 6. User Flows

### 6.1 Start a Game
```
1. Open app → Home screen
2. Tap "Host Game"
3. Configure: blinds, buy-in, max buy-in, action timer → "Open Room"
4. Wait for joiners to appear → see joiner list with names
5. Tap "Start Game" when 2+ players present
```

### 6.2 Join a Game
```
1. Open app → Home screen
2. Tap "Join Game"
3. See list of nearby rooms (host name + player count)
4. Tap a room → enter display name → joined
5. Wait for host to start game
```

### 6.3 Play a Hand
```
1. Cards dealt (face-down on screen)
2. Press-and-hold own cards to peek → release to hide
3. On your turn: action panel appears
   - Fold / Check / Call buttons
   - Raise: preset buttons + stepper + slider
   - Timer countdown shown if enabled
4. Tap action → broadcast → next player's turn
5. At showdown: non-folded players' cards revealed automatically
6. Pot distributed, hand ends
```

### 6.4 Sit Out / Sit In
```
- Tap "Sit Out" button anytime
- If during own active hand: counts as fold immediately + flagged out
- Next hand: skipped (no cards, no blinds)
- Tap "Sit In" to return → joins from next hand
- Stack persists throughout
```

### 6.5 Top Up
```
- Between hands only
- "Top Up" button visible if stack < max buy-in
- Tap → enter amount (capped at max buy-in - current stack) → confirmed
- Buy-in added to stats
```

### 6.6 End Session
```
- Host taps "End Session" → confirmation
- Final stacks recorded
- All players see summary: total buy-ins, final stack, P/L per player
```

---

## 7. Feature Detail

### 7.1 Settings (host-configurable, locked after game start)

| Setting | Default | Range/Options |
|---|---|---|
| Small Blind | 1 | integer ≥ 1 |
| Big Blind | 2 | integer ≥ 2× SB |
| Default Buy-in | 100 | integer, in chips |
| Max Buy-in | 200 | integer ≥ default buy-in |
| Action Timer | 30s | 15 / 30 / 60 / ∞ |

### 7.2 Action Panel

**Always visible when it's your turn:**
- **Fold** — outlined button, left
- **Check** หรือ **Call X** — solid button, center (shows current bet amount if call)
- **Raise** — solid button, right → expands raise panel

**Raise panel:**
- 4 preset buttons in a row: `1/3` `1/2` `2/3` `POT`
- Stepper: `[−] amount [+]`, increments of 1 BB
- Slider: min raise → all-in, full width
- Confirm button: "Raise to X"

**Action timer:** circular progress around your avatar / action panel, counts down. หมดเวลา → auto-fold (หรือ auto-check ถ้า check ได้ฟรี)

### 7.3 Hole Cards Display

**Default:** ปิด (โชว์หลังไพ่ลายเรียบๆ minimal)

**Peek:**
- Press-and-hold ที่พื้นที่ไพ่ทั้งสองใบรวมกัน
- Release → ปิดทันที
- ถ้านิ้วเลื่อนออกนอก hit area → ปิดทันที
- ไอคอน 👁 ที่มุมไพ่ตอน default (ใบ้ว่ากดได้)

**Showdown:** ไพ่ของคนที่ไม่ fold เปิดอัตโนมัติ, ค้างไว้จนเริ่มมือถัดไป

### 7.4 Side Pot Calculation
- คำนวณอัตโนมัติตามมาตรฐาน poker
- แสดงให้เห็นชัด ตอน all-in: "Main Pot: 240 / Side Pot: 100"
- ตอน showdown: แต่ละ pot แสดงผู้ชนะแยกกัน

### 7.5 Stats Screen

**Per-session view (default):**
- Table แสดงทุก player:
  - Display name
  - Total buy-in (sum of all top-ups)
  - Current/final stack
  - P/L (+/-, colored: green/red)
  - Number of hands played

**Hand log (P2):** scrollable list of all hands ใน session — board cards, winner, pot

**History (P2):** list ของ past sessions, ดู P/L ย้อนหลังได้

### 7.6 Privacy Mode
- เมื่อ `scenePhase` ≠ `.active` → blur ทั้งหน้าจอด้วย `UIBlurEffect` style `.systemMaterial`
- ครอบทุกหน้า (lobby, table, settings, stats)
- กลับมาเปิด → blur หายอัตโนมัติ

### 7.7 Sit Out / Sit In Logic
- กด Sit Out ระหว่างมือตัวเอง → fold ทันที + ตั้ง flag `pendingSitOut`
- มือถัดไป: skip ผู้เล่นนี้ทั้งหมด ไม่ deal ไพ่ ไม่โพสต์ blind (ยอม trade-off ว่าหนี blind ได้)
- กด Sit In → ตั้ง flag `pendingSitIn` → มือถัดไปกลับมาเล่นปกติ
- Stack คงเดิมตลอด

### 7.8 Pause / Resume (Host-only)
**ใครกดได้:** เฉพาะ host

**Pause behavior:**
- Action timer freeze ที่ค่าปัจจุบัน
- ทุก action ถูก reject (broadcast "game paused")
- Overlay บนทุก peer: "Game Paused by [Host Name]" + freeze countdown ของ current actor
- State มือคงไว้: pot, current actor, bets, hole cards, board
- ผู้เล่นยัง press-and-hold ดูไพ่ตัวเองได้

**During pause:**
- Host เห็นปุ่ม **Resume** กับ **End Session**
- Players เห็น "Waiting for host…"
- Sit-out / Sit-in ยังกดได้ (เก็บ flag ไว้)
- Top-up ห้าม (กัน abuse: pause → top up → resume)
- Pause timeout: 30 นาที → auto-end session

**Resume behavior:**
- Host กด Resume → broadcast resume event
- Timer count ต่อจากที่ freeze (ไม่รีเซ็ต)
- Current actor กด action ได้อีกครั้ง

**Edge cases:**
- Host disconnect ตอน paused → migration ทำงาน + new host รับสถานะ paused + กด resume เอง
- Player disconnect ตอน paused → action timer ของ player freeze; กลับมาก่อน resume = ปกติ; ไม่กลับ = นับ disconnect timer หลัง resume

---

## 8. Visual Design Direction

### 8.1 Tone
**ไม่ใช่ Vegas casino** — ไม่มีโทนแดง/ทอง, ไม่มี animation ฉูดฉาด, ไม่มี chip stack 3D
**คือ productivity app ที่บังเอิญเล่น poker ได้** — ดูเป็นผู้ใหญ่, calm, ใช้นาน-ไม่เหนื่อยตา

### 8.2 Color
- Dark mode เป็นหลัก (เริ่ม v1 ไม่มี light mode)
- Background: near-black (`#0A0A0A` หรือ system black)
- Accent (โต๊ะ): muted green หรือ neutral gray — ไม่ใช่ felt green ฉูดฉาด
- Action buttons: high contrast white/system blue
- P/L colors: system green / red, muted saturation

### 8.3 Typography
- SF Pro (system font)
- น้ำหนัก: regular / medium / bold เท่านั้น
- ตัวเลข chip/pot: tabular nums, ใหญ่อ่านง่ายในระยะแขน
- Spacing generous

### 8.4 Cards
- Flat, ไม่มี gradient (ยกเว้น subtle drop shadow ใต้ไพ่ — exception ของ "no skeuomorphism")
- หน้าไพ่: rank ใหญ่บนซ้าย, suit glyph เล็กใต้, suit ใหญ่กลางไพ่
- มุมโค้ง 8pt
- Border 0.5pt สีเทาอ่อน `#E0E0E0` (ขับขอบให้เห็นบนพื้นเข้ม)

**Card background: light (off-white)** — สร้าง contrast กับ dark app, ทำให้ไพ่เด่นเป็น focal point เหมือนไพ่จริงบนโต๊ะมืด
- Card face background: `#FAFAFA`
- Card back: pattern พื้นเข้ม (navy `#1E3A5F` หรือ deep neutral) + diagonal lines minimal

**4-color deck** (default ใน v1, บนพื้นไพ่ขาว):

| Suit | Color name | Hex |
|---|---|---|
| ♠ Spades | ดำ | `#1A1A1A` |
| ♥ Hearts | แดง | `#D32F2F` |
| ♦ Diamonds | น้ำเงิน | `#1976D2` |
| ♣ Clubs | เขียว | `#2E7D32` |

- Rank ตัวอักษร + suit glyph ใช้สีเดียวกัน (อ่านสี = รู้ดอกทันที)
- Saturation/brightness ลดลงจาก vibrant version เพราะบนพื้นขาว สีฉูดจะแสบตา
- ตอน showdown: hand strength text ใช้สีดอกหลัก เช่น "Flush ♥" สีแดง
- Settings toggle: **"Classic 2-color deck"** (P2 — ♠♣ ดำ, ♥♦ แดง สำหรับ color-blind หรือคนชอบดั้งเดิม)

### 8.5 Animation
- Subtle slides เมื่อ community cards เปิด (0.25s ease-out)
- Card peek flip: 0.15s
- ไม่มี: confetti, fireworks, chip stacking animation, sound effects ยุ่งเหยิง
- มี: nominal click haptic ตอนกดปุ่ม, single chime ตอนชนะมือ (toggle off ได้)

---

## 9. Testing Strategy

### 9.1 Stack

| Tool | Purpose | Scope |
|---|---|---|
| **Swift Testing** | Unit + integration tests | Game engine, betting, hand eval, state replication, all logic |
| **swift-snapshot-testing** (pointfreeco) | SwiftUI view regression | Card, action panel, lobby, settings views |
| **XCTest** | Performance only | Hand evaluator benchmark (if needed) |
| **SwiftLint + SwiftFormat** | Static analysis | All code, pre-commit hook |

**Excluded จาก v1:**
- XCUITest (E2E UI flows) — เพิ่มตอน polish phase ถ้ามีเวลา
- Mock libraries (Cuckoo, Mockingbird) — ใช้ protocol + manual stub แทน

### 9.2 ทำไมเลือก Swift Testing เป็นหลัก
- มาพร้อม Xcode 16 / Swift 6 อัตโนมัติ ไม่ต้อง install
- `@Test` + `#expect` syntax สะอาด อ่าน/เขียนเร็ว
- Rich failure messages โชว์ actual values — debug ง่าย
- Parallel by default — รัน test เร็ว
- Parameterized tests ทำง่าย (เหมาะกับ hand evaluator: ป้อน 7 ใบ → expect rank)

### 9.3 ข้อจำกัดต้องระวัง
- **XCTest และ Swift Testing ไม่ interoperable** → อย่ามิกซ์ assertion ของสอง framework ใน file เดียว
- UI tests ยังเป็นของ XCTest เท่านั้น
- `TimeLimitTrait` ต้อง iOS 16+ (เรา target iOS 16 อยู่แล้ว ใช้ได้)

### 9.4 Snapshot Testing Strategy
- ติดตั้งตั้งแต่ M0 (ลงทุน setup ก่อน)
- Snapshot per SwiftUI view ที่ visual matters (cards, action panel, lobby cells)
- Record mode เปิดตอน design epoch เปลี่ยน → review รูปก่อน commit
- Snapshots commit เข้า repo (PNG files) — ใช้ Git LFS ถ้าขนาดโต

### 9.5 TDD Workflow (per ticket)
```
🔴 Red    เขียน @Test → swift test --filter X → fail with AssertionError
🟢 Green  เขียน production code → swift test → ผ่าน
🔵 Blue   refactor → swift test ยังเขียว → commit
📸 Snap   UI ticket → record snapshot → review รูป → commit baseline
```

### 9.6 CI Commands
```bash
swift test --parallel                       # full suite
swift test --filter HandEvaluatorTests      # focused
swift build                                 # compile check
swift package resolve                       # update deps
swiftlint --strict                          # lint
swiftformat --lint .                        # format check
```

### 9.7 Coverage Targets
- Game engine (HandState, betting, side pots): **100% line coverage**
- Hand evaluator: **100% line coverage** (use parameterized tests across all hand categories)
- Transport layer: **80%+** (mocked transport for unit tests, real transport tested manually)
- UI: snapshot coverage of all primary screens; no line-coverage target

---

## 10. Success Metrics

### 10.1 Quantitative (post-TestFlight)
- เกม session ที่เริ่ม → ≥80% เล่นจบ 1 มือขึ้นไป (vs. crash/disconnect/abandon ตอน setup)
- Median session length ≥ 30 นาที (เล่นเสร็จ ไม่ใช่กดดูแล้วปิด)
- Host migration trigger rate < 10% ของ sessions (กรณีจริง host หาย vs. ทั้งหมด)
- Average action time < 15s (ใน 30s timer setting)

### 10.2 Qualitative
- เพื่อนกลุ่ม TestFlight feedback: "พกพาง่ายกว่าไพ่จริง" / "เล่นต่อจากตรงไหนก็ได้"
- ไม่มี feedback ว่า "งง UI" หรือ "เห็นไพ่คนอื่นไม่ได้ตั้งใจ"

---

## 11. Technical Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Multipeer Bluetooth-only โหมดช้าเกินไปสำหรับ 8 peers | High | SPIKE ตอนต้น; ถ้าช้า → ต้องการ Wi-Fi on (ไม่ต่อ network ก็ได้) |
| iOS suspend Multipeer session ตอน app background | Medium | UI warn ก่อน background, Privacy mode blur อย่างเดียวไม่ suspend; ถ้า suspend จริง → auto-fold |
| Host migration race conditions (2 peer เป็น host พร้อมกัน) | High | Election ใช้ deterministic ordering (oldest join timestamp), tied-breaking ด้วย peerID hash |
| State replica diverge ระหว่าง host เก่าและใหม่ | High | Append-only signed action log + Merkle root sync ตอน peer join |
| TestFlight review reject เพราะมี gambling-like UI | Medium | ไม่มี real money, ไม่มี IAP, ระบุชัด "play money / chips have no value" ใน App Store description |
| BigInt / crypto perf บน iPhone รุ่นเก่า (iPhone 11) | Low | ใช้ Ed25519 จาก CryptoKit (hardware-accelerated), ไม่ใช่ raw BigInt |

---

## 12. Resolved Configuration

| Item | Decision |
|---|---|
| **App name** | **PPoker** |
| **Minimum iOS** | **iOS 16** |
| **Orientation** | Portrait only |
| **Theme** | Dark mode only |
| **Haptic feedback** | Light haptic on actions, user-toggleable in settings |
| **Local storage** | **GRDB** (SQLite-based, type-safe, Codable-friendly) |
| **Testing** | Swift Testing + swift-snapshot-testing |
| Logo / icon direction | TBD — likely minimal monogram "P" or chip glyph |

### Implications of iOS 16 target

- ❌ **SwiftData ใช้ไม่ได้** (ต้องการ iOS 17+) → ใช้ GRDB แทน
- ❌ **`@Observable` macro ใช้ไม่ได้** → ต้องใช้ `ObservableObject` + `@Published`
- ✅ NavigationStack, Swift Charts, async/await — รองรับ
- ✅ Multipeer Connectivity, CryptoKit — รองรับเต็มที่
- ✅ Swift Testing + TimeLimitTrait — รองรับ (iOS 16+ minimum)

### Storage architecture (GRDB)
- SQLite database, ไฟล์เดียวต่อ user, เก็บที่ `Application Support/`
- Tables: `game_sessions`, `player_sessions`, `hand_records`, `player_actions`
- Migration system พร้อมใช้สำหรับ schema evolution
- Type-safe Records (Codable structs map directly to rows)
- ไม่มี sync ใน v1 (local-only)

---

## 13. Milestones

| M | Theme | Deliverable |
|---|---|---|
| M0 | Foundations | Transport spike, signing, identity, lobby handshake, **snapshot testing setup** |
| M1 | Single-host MVP | เล่น 1 มือจริงได้, ไม่มี migration, ไม่มี stats screen |
| M2 | Host Migration | State replication + election + abort/resume |
| M3 | Polish | Stats screen, settings, privacy mode, design tuning |
| TF1 | TestFlight beta 1 | ปล่อยให้เพื่อนทดสอบหลัง M3 |

---

## 14. Decisions Log

ทุกการตัดสินใจที่สรุปแล้วใน design conversation:

| # | Decision | Rationale |
|---|---|---|
| 1 | Trusted host (ไม่ใช่ mental poker) | เล่นกับเพื่อน, ลด complexity 70% |
| 2 | Multipeer Connectivity | Native iOS, Bluetooth + Wi-Fi auto |
| 3 | 1 device : 1 player | UX สะดวก ไม่ต้องมี player selector |
| 4 | Sit-out ระหว่างมือ = fold + flag out | เขียนง่ายสุด |
| 5 | Sit-out ไม่มี dead blind | Party-friendly |
| 6 | Host migration ตั้งแต่ v1 | ผู้ใช้ยืนยัน, ยอม complexity |
| 7 | Side pot auto-calculate | มาตรฐาน poker |
| 8 | ไม่โชว์ไพ่หลังมือจบ | มาตรฐาน poker |
| 9 | Action timer host ปรับ 15/30/60/∞ | Flexible per group |
| 10 | Raise: preset + stepper ±1BB + slider | ครอบคลุมทุก use case |
| 11 | Display chips เป็นหลัก, BB ตัวเล็ก | คุ้นเคยกว่าสำหรับผู้เล่นทั่วไป |
| 12 | Hole cards: press-and-hold to peek | ป้องกันคนข้างๆ เห็น |
| 13 | Privacy mode: blur ตอน background | ป้องกันแอบดูตอนวางโทรศัพท์ |
| 14 | Ed25519 message signing | กัน action ปลอม แม้ใน trusted-host model |
| 15 | GRDB สำหรับ stats local | iOS 16 target → SwiftData ใช้ไม่ได้; ไม่มี sync ใน v1 |
| 16 | Dark mode only | ลด scope, fit design tone |
| 17 | Portrait only | ลด scope, mobile-native |
| 18 | App name: PPoker | ผู้ใช้กำหนด |
| 19 | iOS 16 minimum | ครอบคลุมผู้ใช้กว้างขึ้น (iPhone 8 ขึ้นไป) |
| 20 | Haptic feedback toggleable | ผู้ใช้บางคนไม่ชอบ haptic |
| 21 | Host pause/resume game | Party-friendly (เข้าห้องน้ำ, กินข้าว) |
| 22 | เฉพาะ host กด pause ได้ | กัน abuse, party game นั่งติดกันร้องด้วยปากได้ |
| 23 | Pause timeout 30 นาที | กันลืม |
| 24 | 4-color deck (♠ดำ ♥แดง ♦น้ำเงิน ♣เขียว) | แยกดอกได้เร็วในเสี้ยววินาที |
| 25 | Light card background บน dark app | ไพ่เด่นเป็น focal point, สีดอกตรงตามมาตรฐาน (ดำ/แดง/น้ำเงิน/เขียว) |
| 26 | Classic 2-color toggle (P2) | สำหรับ color-blind หรือคนชอบดั้งเดิม |
| 27 | Swift Testing เป็น test framework หลัก | Modern syntax, parallel default, rich failure msg, Claude Code อ่านเข้าใจ |
| 28 | swift-snapshot-testing ตั้งแต่ M0 | ลงทุน setup ก่อน ได้ป้องกัน UI regression ตลอดโปรเจค |
| 29 | ข้าม XCUITest ใน v1 | เพิ่มตอน polish ถ้ามีเวลา |
| 30 | ไม่ใช้ mock library | Manual protocol + stub อ่านง่ายกว่า, Claude Code debug ได้ |
