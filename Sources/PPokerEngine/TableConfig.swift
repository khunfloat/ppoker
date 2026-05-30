import Foundation

public struct TableConfig: Codable, Sendable, Hashable {
    public var smallBlind: Int
    public var bigBlind: Int
    public var defaultBuyIn: Int
    public var maxBuyIn: Int
    /// nil = unlimited (∞)
    public var actionTimerSeconds: Int?

    public static let `default` = TableConfig(
        smallBlind: 1,
        bigBlind: 2,
        defaultBuyIn: 500,
        maxBuyIn: 10000,
        actionTimerSeconds: 30
    )

    public init(
        smallBlind: Int,
        bigBlind: Int,
        defaultBuyIn: Int,
        maxBuyIn: Int,
        actionTimerSeconds: Int?
    ) {
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.defaultBuyIn = defaultBuyIn
        self.maxBuyIn = maxBuyIn
        self.actionTimerSeconds = actionTimerSeconds
    }
}
