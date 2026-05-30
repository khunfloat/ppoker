#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct HostSetupView: View {
    @EnvironmentObject var app: AppState

    @State private var smallBlind: Int = 1
    @State private var bigBlind: Int = 2
    @State private var defaultBuyIn: Int = 500
    @State private var maxBuyIn: Int = 10000
    @State private var timerOption: TimerOption = .seconds30

    enum TimerOption: Hashable {
        case seconds15, seconds30, seconds60, infinite

        var seconds: Int? {
            switch self {
            case .seconds15: return 15
            case .seconds30: return 30
            case .seconds60: return 60
            case .infinite: return nil
            }
        }

        var label: String {
            switch self {
            case .seconds15: return "15s"
            case .seconds30: return "30s"
            case .seconds60: return "60s"
            case .infinite: return "∞"
            }
        }
    }

    public init() {}

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    settingsCard
                    Spacer(minLength: 24)
                    openButton
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack {
            Button { app.route = .home } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
            Spacer()
            Text("New Game").foregroundStyle(.white).font(.headline)
            Spacer()
            Color.clear.frame(width: 18, height: 18)
        }
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            stepperRow("Small Blind", value: $smallBlind, min: 1)
                .onChange(of: smallBlind) { new in
                    bigBlind = max(bigBlind, new * 2)
                }
            divider
            stepperRow("Big Blind", value: $bigBlind, min: max(smallBlind * 2, 2))
            divider
            stepperRow("Default Buy-in", value: $defaultBuyIn, min: bigBlind * 10, step: 10)
                .onChange(of: defaultBuyIn) { new in
                    if maxBuyIn < new { maxBuyIn = new }
                }
            divider
            stepperRow("Max Buy-in", value: $maxBuyIn, min: defaultBuyIn, step: 10)
            divider
            timerRow
        }
        .background(PPTheme.panel)
        .cornerRadius(12)
    }

    private func stepperRow(_ label: String, value: Binding<Int>, min: Int, step: Int = 1) -> some View {
        HStack {
            Text(label).foregroundStyle(.white)
            Spacer()
            Stepper(value: value, in: min...100_000, step: step) {
                Text("\(value.wrappedValue)")
                    .font(.chipNumber(size: 18))
                    .foregroundStyle(.white)
            }
            .labelsHidden()
            Text("\(value.wrappedValue)")
                .font(.chipNumber(size: 18))
                .foregroundStyle(.white)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var timerRow: some View {
        HStack {
            Text("Action Timer").foregroundStyle(.white)
            Spacer()
            Picker("Timer", selection: $timerOption) {
                Text("15s").tag(TimerOption.seconds15)
                Text("30s").tag(TimerOption.seconds30)
                Text("60s").tag(TimerOption.seconds60)
                Text("∞").tag(TimerOption.infinite)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        PPTheme.divider.frame(height: 0.5)
    }

    private var openButton: some View {
        Button {
            app.pendingConfig = TableConfig(
                smallBlind: smallBlind,
                bigBlind: bigBlind,
                defaultBuyIn: defaultBuyIn,
                maxBuyIn: maxBuyIn,
                actionTimerSeconds: timerOption.seconds
            )
            Task { await app.beginHosting() }
        } label: {
            Text("Open Room").frame(maxWidth: .infinity)
        }
        .buttonStyle(PPPrimaryButton())
    }
}
#endif
