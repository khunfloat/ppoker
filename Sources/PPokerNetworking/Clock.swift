import Foundation

public protocol Clock: Sendable {
    func now() -> TimeInterval
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> TimeInterval { Date().timeIntervalSince1970 }
}

public final class ManualClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval

    public init(start: TimeInterval = 0) { self.time = start }

    public func now() -> TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return time
    }

    public func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        time += seconds
    }
}
