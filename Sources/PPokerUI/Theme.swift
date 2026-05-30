#if canImport(SwiftUI)
import SwiftUI

public enum PPTheme {
    // Backgrounds
    public static let appBackground = Color(red: 10/255, green: 10/255, blue: 10/255)
    public static let tableBackground = Color(red: 30/255, green: 36/255, blue: 32/255)
    public static let panel = Color(red: 22/255, green: 22/255, blue: 22/255)
    public static let divider = Color.white.opacity(0.08)

    // Cards
    public static let cardFace = Color(red: 250/255, green: 250/255, blue: 250/255)
    public static let cardBack = Color(red: 30/255, green: 58/255, blue: 95/255)
    public static let cardBorder = Color(red: 224/255, green: 224/255, blue: 224/255)

    // Suits (4-color deck)
    public static let spades = Color(red: 26/255, green: 26/255, blue: 26/255)
    public static let hearts = Color(red: 211/255, green: 47/255, blue: 47/255)
    public static let diamonds = Color(red: 25/255, green: 118/255, blue: 210/255)
    public static let clubs = Color(red: 46/255, green: 125/255, blue: 50/255)

    // Actions
    public static let actionPrimary = Color.white
    public static let actionDanger = Color(red: 211/255, green: 47/255, blue: 47/255)
    public static let actionPositive = Color(red: 46/255, green: 125/255, blue: 50/255)

    // P/L
    public static let plPositive = Color(red: 76/255, green: 175/255, blue: 80/255)
    public static let plNegative = Color(red: 244/255, green: 67/255, blue: 54/255)
}

public extension Font {
    static func chipNumber(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
            .monospacedDigit()
    }
}
#endif
