#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct TopUpSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Int = 0
    public let currentStack: Int
    public let maxBuyIn: Int

    public init(currentStack: Int, maxBuyIn: Int) {
        self.currentStack = currentStack
        self.maxBuyIn = maxBuyIn
    }

    private var cap: Int { max(0, maxBuyIn - currentStack) }

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Top Up").foregroundStyle(.white).font(.headline)
                    Text("Current \(currentStack) · Max \(maxBuyIn)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 24)

                VStack(spacing: 8) {
                    Text("\(amount)")
                        .font(.chipNumber(size: 44))
                        .foregroundStyle(.white)
                    Slider(value: Binding(get: { Double(amount) }, set: { amount = Int($0) }),
                           in: 0...Double(max(cap, 1)))
                        .tint(.white)
                        .disabled(cap == 0)
                }
                .padding(20)
                .background(PPTheme.panel)
                .cornerRadius(12)

                Button {
                    Task {
                        if amount > 0 { await app.topUp(amount: amount) }
                        dismiss()
                    }
                } label: {
                    Text("Confirm Top-Up").frame(maxWidth: .infinity)
                }
                .buttonStyle(PPPrimaryButton())
                .disabled(amount == 0)

                Button { dismiss() } label: {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(PPSecondaryButton())

                Spacer()
            }
            .padding(20)
        }
    }
}
#endif
