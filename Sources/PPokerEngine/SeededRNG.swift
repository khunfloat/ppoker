import Foundation

/// Deterministic LCG-based RNG for tests / replayable games.
/// Not cryptographically secure.
public struct SeededRNG: RandomNumberGenerator {
    public var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed
    }

    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
