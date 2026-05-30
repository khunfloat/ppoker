#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct CardView: View {
    public let card: Card
    public let width: CGFloat

    public init(card: Card, width: CGFloat = 56) {
        self.card = card
        self.width = width
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(PPTheme.cardFace)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(PPTheme.cardBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

            // Suit small in top-left
            VStack {
                HStack {
                    Text(card.suit.glyph)
                        .font(.system(size: width * 0.30, weight: .semibold))
                        .foregroundStyle(suitColor)
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, width * 0.10)
            .padding(.top, width * 0.06)

            // Rank big in the center
            Text(card.rank.shortName)
                .font(.system(size: width * 0.62, weight: .bold, design: .rounded))
                .foregroundStyle(suitColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: width, height: width * 1.4)
    }

    private var suitColor: Color {
        switch card.suit {
        case .spades: return PPTheme.spades
        case .hearts: return PPTheme.hearts
        case .diamonds: return PPTheme.diamonds
        case .clubs: return PPTheme.clubs
        }
    }
}

public struct CardBackView: View {
    public let width: CGFloat
    public init(width: CGFloat = 56) { self.width = width }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(PPTheme.cardBack)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            // Subtle diagonal pattern
            GeometryReader { proxy in
                Path { p in
                    let s: CGFloat = 8
                    var y: CGFloat = -proxy.size.width
                    while y < proxy.size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: proxy.size.width, y: y + proxy.size.width))
                        y += s
                    }
                }
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(width: width, height: width * 1.4)
    }
}

public struct CardPlaceholderView: View {
    public let width: CGFloat
    public init(width: CGFloat = 56) { self.width = width }
    public var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(width: width, height: width * 1.4)
    }
}
#endif
