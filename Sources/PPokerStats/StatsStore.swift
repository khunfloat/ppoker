import Foundation
import GRDB
import PPokerEngine

public enum StatsError: Error {
    case databaseUnavailable(String)
}

public struct StoredGameSession: Codable, Hashable, Sendable {
    public var id: String
    public var startedAt: Date
    public var endedAt: Date?
    public var hostID: String
    public var configJSON: String

    public init(id: String, startedAt: Date, endedAt: Date?, hostID: String, configJSON: String) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.hostID = hostID
        self.configJSON = configJSON
    }
}

public struct StoredPlayerSession: Codable, Hashable, Sendable {
    public var id: Int64?
    public var sessionID: String
    public var playerID: String
    public var displayName: String
    public var totalBuyIn: Int
    public var finalStack: Int
    public var handsPlayed: Int

    public init(id: Int64?, sessionID: String, playerID: String, displayName: String,
                totalBuyIn: Int, finalStack: Int, handsPlayed: Int) {
        self.id = id
        self.sessionID = sessionID
        self.playerID = playerID
        self.displayName = displayName
        self.totalBuyIn = totalBuyIn
        self.finalStack = finalStack
        self.handsPlayed = handsPlayed
    }
}

public struct StoredHandRecord: Codable, Hashable, Sendable {
    public var id: Int64?
    public var sessionID: String
    public var handNumber: Int
    public var boardCardsJSON: String
    public var winnersJSON: String
    public var pot: Int
    public var startedAt: Date

    public init(id: Int64?, sessionID: String, handNumber: Int, boardCardsJSON: String,
                winnersJSON: String, pot: Int, startedAt: Date) {
        self.id = id
        self.sessionID = sessionID
        self.handNumber = handNumber
        self.boardCardsJSON = boardCardsJSON
        self.winnersJSON = winnersJSON
        self.pot = pot
        self.startedAt = startedAt
    }
}

public actor StatsStore {
    private let dbQueue: DatabaseQueue

    public static func make(at url: URL? = nil) async throws -> StatsStore {
        let fm = FileManager.default
        let directory: URL
        if let url {
            directory = url
        } else {
            directory = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("PPoker", isDirectory: true)
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let dbURL = directory.appendingPathComponent("stats.sqlite")
        let queue = try DatabaseQueue(path: dbURL.path)
        let store = StatsStore(dbQueue: queue)
        try await store.migrate()
        return store
    }

    public static func makeInMemory() async throws -> StatsStore {
        let queue = try DatabaseQueue()
        let store = StatsStore(dbQueue: queue)
        try await store.migrate()
        return store
    }

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "game_sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("started_at", .datetime).notNull()
                t.column("ended_at", .datetime)
                t.column("host_id", .text).notNull()
                t.column("config_json", .text).notNull()
            }
            try db.create(table: "player_sessions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("session_id", .text).notNull()
                    .references("game_sessions", onDelete: .cascade)
                t.column("player_id", .text).notNull()
                t.column("display_name", .text).notNull()
                t.column("total_buy_in", .integer).notNull().defaults(to: 0)
                t.column("final_stack", .integer).notNull().defaults(to: 0)
                t.column("hands_played", .integer).notNull().defaults(to: 0)
                t.uniqueKey(["session_id", "player_id"])
            }
            try db.create(table: "hand_records") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("session_id", .text).notNull()
                    .references("game_sessions", onDelete: .cascade)
                t.column("hand_number", .integer).notNull()
                t.column("board_cards_json", .text).notNull()
                t.column("winners_json", .text).notNull()
                t.column("pot", .integer).notNull().defaults(to: 0)
                t.column("started_at", .datetime).notNull()
            }
        }
        try migrator.migrate(dbQueue)
    }

    // MARK: - Writes

    public func upsertSession(_ s: StoredGameSession) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO game_sessions(id, started_at, ended_at, host_id, config_json)
                VALUES(?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    started_at = excluded.started_at,
                    ended_at = excluded.ended_at,
                    host_id = excluded.host_id,
                    config_json = excluded.config_json
                """,
                arguments: [s.id, s.startedAt, s.endedAt, s.hostID, s.configJSON]
            )
        }
    }

    public func upsertPlayerSession(_ ps: StoredPlayerSession) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO player_sessions(session_id, player_id, display_name, total_buy_in, final_stack, hands_played)
                VALUES(?, ?, ?, ?, ?, ?)
                ON CONFLICT(session_id, player_id) DO UPDATE SET
                    display_name = excluded.display_name,
                    total_buy_in = excluded.total_buy_in,
                    final_stack = excluded.final_stack,
                    hands_played = excluded.hands_played
                """,
                arguments: [ps.sessionID, ps.playerID, ps.displayName,
                            ps.totalBuyIn, ps.finalStack, ps.handsPlayed]
            )
        }
    }

    public func recordHand(_ h: StoredHandRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO hand_records(session_id, hand_number, board_cards_json, winners_json, pot, started_at)
                VALUES(?, ?, ?, ?, ?, ?)
                """,
                arguments: [h.sessionID, h.handNumber, h.boardCardsJSON,
                            h.winnersJSON, h.pot, h.startedAt]
            )
        }
    }

    // MARK: - Reads

    public func listSessions() throws -> [StoredGameSession] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT id, started_at, ended_at, host_id, config_json FROM game_sessions ORDER BY started_at DESC"
            )
            return rows.map { row in
                StoredGameSession(
                    id: row["id"],
                    startedAt: row["started_at"],
                    endedAt: row["ended_at"],
                    hostID: row["host_id"],
                    configJSON: row["config_json"]
                )
            }
        }
    }

    public func playerSessions(for sessionID: String) throws -> [StoredPlayerSession] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT id, session_id, player_id, display_name, total_buy_in, final_stack, hands_played FROM player_sessions WHERE session_id = ?",
                arguments: [sessionID]
            )
            return rows.map { row in
                StoredPlayerSession(
                    id: row["id"],
                    sessionID: row["session_id"],
                    playerID: row["player_id"],
                    displayName: row["display_name"],
                    totalBuyIn: row["total_buy_in"],
                    finalStack: row["final_stack"],
                    handsPlayed: row["hands_played"]
                )
            }
        }
    }
}
