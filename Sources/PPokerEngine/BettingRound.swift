import Foundation

public enum BettingAction: Codable, Sendable, Equatable {
    case fold
    case check
    case call
    /// Open the betting with `amount` (only when no current bet exists).
    case bet(Int)
    /// Raise to a total of `to` chips for this round (not raise-by).
    case raiseTo(Int)
    /// Commit all remaining stack.
    case allIn
}

public enum BettingError: Error, Equatable, Sendable {
    case notYourTurn
    case playerNotFound
    case playerCannotAct
    case checkNotAllowed
    case callNotAllowed
    case betNotAllowed
    case raiseNotAllowed
    case raiseTooSmall(minimum: Int)
    case betTooSmall(minimum: Int)
    case insufficientStack
    case invalidAmount
    case roundClosed
}

public struct BettingRound: Codable, Sendable {
    public var players: [Player]
    public var currentBet: Int            // amount each active player must match this round
    public var lastRaiseSize: Int         // most recent raise increment (for min-raise)
    public var bigBlind: Int              // floor for opening bet and min raise
    public var actorIndex: Int            // index into players
    public var aggressorIndex: Int?       // last to bet/raise, used for end-of-round logic
    public var isClosed: Bool

    public init(
        players: [Player],
        currentBet: Int,
        lastRaiseSize: Int,
        bigBlind: Int,
        actorIndex: Int,
        aggressorIndex: Int? = nil,
        isClosed: Bool = false
    ) {
        self.players = players
        self.currentBet = currentBet
        self.lastRaiseSize = lastRaiseSize
        self.bigBlind = bigBlind
        self.actorIndex = actorIndex
        self.aggressorIndex = aggressorIndex
        self.isClosed = isClosed
    }

    public var actor: Player { players[actorIndex] }

    public var activePlayers: [Player] {
        players.filter { $0.status == .active }
    }

    public var inHandPlayers: [Player] {
        players.filter { $0.isInHand }
    }

    /// Players who can still face action (not folded, not all-in).
    public var actionablePlayers: [Player] {
        players.filter { $0.canAct }
    }

    public mutating func apply(_ action: BettingAction, by playerID: PlayerID) throws {
        guard !isClosed else { throw BettingError.roundClosed }
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else {
            throw BettingError.playerNotFound
        }
        guard idx == actorIndex else { throw BettingError.notYourTurn }
        guard players[idx].canAct else { throw BettingError.playerCannotAct }

        switch action {
        case .fold:
            players[idx].status = .folded
            players[idx].hasActedThisRound = true

        case .check:
            guard players[idx].committedThisRound == currentBet else {
                throw BettingError.checkNotAllowed
            }
            players[idx].hasActedThisRound = true

        case .call:
            let owed = currentBet - players[idx].committedThisRound
            guard owed > 0 else { throw BettingError.callNotAllowed }
            let pay = min(owed, players[idx].stack)
            commit(pay, atIndex: idx)
            if players[idx].stack == 0 {
                players[idx].status = .allIn
            }
            players[idx].hasActedThisRound = true

        case .bet(let amount):
            guard currentBet == 0 || players.allSatisfy({ $0.committedThisRound == 0 || $0.id == players[idx].id }) else {
                // there's already a bet — must raise
                throw BettingError.betNotAllowed
            }
            guard currentBet == 0 else { throw BettingError.betNotAllowed }
            guard amount >= bigBlind else { throw BettingError.betTooSmall(minimum: bigBlind) }
            guard amount <= players[idx].stack + players[idx].committedThisRound else {
                throw BettingError.insufficientStack
            }
            let pay = amount - players[idx].committedThisRound
            commit(pay, atIndex: idx)
            currentBet = amount
            lastRaiseSize = amount
            aggressorIndex = idx
            resetActedFlagsExcept(idx)
            if players[idx].stack == 0 { players[idx].status = .allIn }
            players[idx].hasActedThisRound = true

        case .raiseTo(let target):
            guard currentBet > 0 else { throw BettingError.raiseNotAllowed }
            let minRaiseTotal = currentBet + lastRaiseSize
            guard target >= minRaiseTotal else {
                throw BettingError.raiseTooSmall(minimum: minRaiseTotal)
            }
            let maxTotal = players[idx].stack + players[idx].committedThisRound
            guard target <= maxTotal else { throw BettingError.insufficientStack }
            let pay = target - players[idx].committedThisRound
            guard pay > 0 else { throw BettingError.invalidAmount }
            let raiseIncrement = target - currentBet
            commit(pay, atIndex: idx)
            currentBet = target
            lastRaiseSize = raiseIncrement
            aggressorIndex = idx
            resetActedFlagsExcept(idx)
            if players[idx].stack == 0 { players[idx].status = .allIn }
            players[idx].hasActedThisRound = true

        case .allIn:
            let stack = players[idx].stack
            guard stack > 0 else { throw BettingError.insufficientStack }
            let newTotal = players[idx].committedThisRound + stack
            commit(stack, atIndex: idx)
            players[idx].status = .allIn
            players[idx].hasActedThisRound = true
            // If this all-in raises the bet, it acts as a raise (even if short).
            if newTotal > currentBet {
                let raiseIncrement = newTotal - currentBet
                // Short all-in (less than min-raise) does NOT reopen action for prior callers,
                // but per simplification we still update currentBet and aggressor.
                let isFullRaise = raiseIncrement >= lastRaiseSize
                currentBet = newTotal
                if isFullRaise {
                    lastRaiseSize = raiseIncrement
                    aggressorIndex = idx
                    resetActedFlagsExcept(idx)
                }
            }
        }

        advanceActor()
    }

    /// True if the round is complete (one player left, or all in-hand actors have matched & acted).
    public var isRoundComplete: Bool {
        let nonFolded = players.filter { $0.status != .folded && $0.status != .sittingOut }
        if nonFolded.count <= 1 { return true }
        let needAction = players.filter { $0.canAct }
        if needAction.isEmpty { return true }
        let allMatched = needAction.allSatisfy { $0.committedThisRound == currentBet }
        let allActed = needAction.allSatisfy { $0.hasActedThisRound }
        return allMatched && allActed
    }

    private mutating func commit(_ amount: Int, atIndex idx: Int) {
        precondition(amount >= 0)
        precondition(players[idx].stack >= amount)
        players[idx].stack -= amount
        players[idx].committedThisRound += amount
        players[idx].totalCommitted += amount
    }

    private mutating func resetActedFlagsExcept(_ aggressor: Int) {
        for i in players.indices where i != aggressor {
            if players[i].canAct {
                players[i].hasActedThisRound = false
            }
        }
    }

    private mutating func advanceActor() {
        let n = players.count
        for step in 1...n {
            let cand = (actorIndex + step) % n
            if players[cand].canAct && players[cand].committedThisRound != currentBet {
                actorIndex = cand
                return
            }
            if players[cand].canAct && !players[cand].hasActedThisRound {
                actorIndex = cand
                return
            }
        }
        // No one left to act this round.
        isClosed = true
    }
}
