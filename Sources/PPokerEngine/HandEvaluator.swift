import Foundation

public enum HandEvaluator {
    /// Evaluate the best 5-card poker hand from the given cards.
    /// Accepts 5, 6, or 7 cards.
    public static func evaluate(_ cards: [Card]) -> HandRank {
        precondition(cards.count >= 5 && cards.count <= 7, "Need 5-7 cards")
        if cards.count == 5 { return rankFive(cards) }
        var best: HandRank?
        for combo in combinations(cards, k: 5) {
            let r = rankFive(combo)
            if let cur = best {
                if r > cur { best = r }
            } else {
                best = r
            }
        }
        return best!
    }

    static func rankFive(_ cards: [Card]) -> HandRank {
        precondition(cards.count == 5)
        let sorted = cards.sorted { $0.rank > $1.rank }
        let ranks = sorted.map(\.rank)
        let suits = sorted.map(\.suit)

        let isFlush = Set(suits).count == 1
        let straightHigh = straightHighRank(ranks: ranks)
        let isStraight = straightHigh != nil

        if isFlush && isStraight {
            let high = straightHigh!
            let ordered = orderStraight(sorted, high: high)
            return HandRank(category: .straightFlush, tiebreakers: [high], bestFive: ordered)
        }

        let groups = groupByRank(ranks: ranks)
        // groups sorted by (count desc, rank desc)

        if groups[0].count == 4 {
            let quadRank = groups[0].rank
            let kicker = groups[1].rank
            let ordered = sorted.filter { $0.rank == quadRank } + sorted.filter { $0.rank == kicker }
            return HandRank(category: .fourOfAKind, tiebreakers: [quadRank, kicker], bestFive: ordered)
        }

        if groups[0].count == 3 && groups[1].count >= 2 {
            let trips = groups[0].rank
            let pair = groups[1].rank
            let ordered = sorted.filter { $0.rank == trips } + sorted.filter { $0.rank == pair }
            return HandRank(category: .fullHouse, tiebreakers: [trips, pair], bestFive: ordered)
        }

        if isFlush {
            return HandRank(category: .flush, tiebreakers: ranks, bestFive: sorted)
        }

        if isStraight {
            let high = straightHigh!
            let ordered = orderStraight(sorted, high: high)
            return HandRank(category: .straight, tiebreakers: [high], bestFive: ordered)
        }

        if groups[0].count == 3 {
            let trips = groups[0].rank
            let kickers = ranks.filter { $0 != trips }.prefix(2)
            let ordered = sorted.filter { $0.rank == trips }
                + kickers.flatMap { rk in sorted.filter { $0.rank == rk } }
            return HandRank(category: .threeOfAKind, tiebreakers: [trips] + Array(kickers), bestFive: ordered)
        }

        if groups[0].count == 2 && groups[1].count == 2 {
            let hi = max(groups[0].rank, groups[1].rank)
            let lo = min(groups[0].rank, groups[1].rank)
            let kicker = ranks.first { $0 != hi && $0 != lo }!
            let ordered = sorted.filter { $0.rank == hi }
                + sorted.filter { $0.rank == lo }
                + sorted.filter { $0.rank == kicker }
            return HandRank(category: .twoPair, tiebreakers: [hi, lo, kicker], bestFive: ordered)
        }

        if groups[0].count == 2 {
            let pair = groups[0].rank
            let kickers = Array(ranks.filter { $0 != pair }.prefix(3))
            let ordered = sorted.filter { $0.rank == pair }
                + kickers.flatMap { rk in sorted.filter { $0.rank == rk } }
            return HandRank(category: .onePair, tiebreakers: [pair] + kickers, bestFive: ordered)
        }

        return HandRank(category: .highCard, tiebreakers: ranks, bestFive: sorted)
    }

    /// Returns high rank of a 5-card straight, or nil if not a straight.
    /// Handles A-2-3-4-5 wheel where high = 5.
    private static func straightHighRank(ranks: [Rank]) -> Rank? {
        let unique = Array(Set(ranks)).sorted(by: >)
        guard unique.count == 5 else { return nil }
        // Normal straight: 5 consecutive ranks
        if unique[0].rawValue - unique[4].rawValue == 4 {
            return unique[0]
        }
        // Wheel: A,5,4,3,2
        if unique == [.ace, .five, .four, .three, .two] {
            return .five
        }
        return nil
    }

    private static func orderStraight(_ cards: [Card], high: Rank) -> [Card] {
        // Wheel: A treated as low, so order 5,4,3,2,A
        if high == .five {
            let by: [Rank] = [.five, .four, .three, .two, .ace]
            return by.compactMap { r in cards.first { $0.rank == r } }
        }
        return cards.sorted { $0.rank > $1.rank }
    }

    struct RankGroup {
        let rank: Rank
        let count: Int
    }

    private static func groupByRank(ranks: [Rank]) -> [RankGroup] {
        var counts: [Rank: Int] = [:]
        for r in ranks { counts[r, default: 0] += 1 }
        return counts
            .map { RankGroup(rank: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.rank > b.rank
            }
    }

    static func combinations<T>(_ array: [T], k: Int) -> [[T]] {
        guard k > 0 else { return [[]] }
        guard k <= array.count else { return [] }
        if k == array.count { return [array] }
        var result: [[T]] = []
        var indices = Array(0..<k)
        let n = array.count
        while true {
            result.append(indices.map { array[$0] })
            var i = k - 1
            while i >= 0 && indices[i] == i + n - k { i -= 1 }
            if i < 0 { break }
            indices[i] += 1
            for j in (i + 1)..<k { indices[j] = indices[j - 1] + 1 }
        }
        return result
    }
}
