#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct HoleCardsView: View {
    public let cards: [Card]
    public let width: CGFloat
    @State private var revealed: Bool = false

    public init(cards: [Card], width: CGFloat = 72) {
        self.cards = cards
        self.width = width
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Group {
                    if revealed, i < cards.count {
                        CardView(card: cards[i], width: width)
                    } else {
                        CardBackView(width: width)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: revealed)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !revealed {
                Image(systemName: "eye")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !revealed { revealed = true }
                }
                .onEnded { _ in
                    revealed = false
                }
        )
    }
}
#endif
