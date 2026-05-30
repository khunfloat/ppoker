#if canImport(SwiftUI)
import SwiftUI

/// SceneBuilder used by the iOS app shell.
/// In the Xcode app target, write:
///
/// ```swift
/// @main struct PPokerApp: App {
///     var body: some Scene { PPokerScene() }
/// }
/// ```
public struct PPokerScene: Scene {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
#endif
