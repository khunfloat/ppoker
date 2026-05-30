#if canImport(SwiftUI) && canImport(UIKit)
import XCTest
import SwiftUI
import SnapshotTesting
@testable import PPokerUI
@testable import PPokerEngine

/// Snapshot baselines for primary card/UI components. Run on iOS simulator from Xcode.
/// CLI (`swift test`) skips these — they need a UIKit host.
final class CardViewSnapshotTests: XCTestCase {
    func testAceOfSpades() {
        let view = CardView(card: Card(.ace, .spades), width: 80)
            .frame(width: 100, height: 130)
            .background(Color.black)
        assertSnapshot(of: view, as: .image)
    }

    func testKingOfHearts() {
        let view = CardView(card: Card(.king, .hearts), width: 80)
            .frame(width: 100, height: 130)
            .background(Color.black)
        assertSnapshot(of: view, as: .image)
    }

    func testCardBack() {
        let view = CardBackView(width: 80)
            .frame(width: 100, height: 130)
            .background(Color.black)
        assertSnapshot(of: view, as: .image)
    }
}
#endif
