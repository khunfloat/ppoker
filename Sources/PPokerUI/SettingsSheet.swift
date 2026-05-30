#if canImport(SwiftUI)
import SwiftUI
import PPokerEngine

public struct SettingsSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var smallBlind: Int
    @State private var bigBlind: Int
    @State private var defaultBuyIn: Int
    @State private var maxBuyIn: Int
    @State private var timerOption: TimerOption

    public init(current: TableConfig) {
        _smallBlind = State(initialValue: current.smallBlind)
        _bigBlind = State(initialValue: current.bigBlind)
        _defaultBuyIn = State(initialValue: current.defaultBuyIn)
        _maxBuyIn = State(initialValue: current.maxBuyIn)
        _timerOption = State(initialValue: TimerOption.from(seconds: current.actionTimerSeconds))
    }

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

        static func from(seconds: Int?) -> TimerOption {
            switch seconds {
            case 15: return .seconds15
            case 30: return .seconds30
            case 60: return .seconds60
            default: return .infinite
            }
        }
    }

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if midHand {
                        Text("Changes apply at the next hand")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    settingsCard
                    saveButton
                    cancelButton
                }
                .padding(20)
            }
        }
    }

    private var midHand: Bool {
        let s = app.gameState.currentHand?.street
        return s != nil && s != .complete
    }

    private var header: some View {
        Text("Table Settings")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
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
            }
            .labelsHidden()
            Text("\(value.wrappedValue)")
                .font(.chipNumber(size: 18))
                .foregroundStyle(.white)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var divider: some View {
        PPTheme.divider.frame(height: 0.5)
    }

    private var saveButton: some View {
        Button {
            let cfg = TableConfig(
                smallBlind: smallBlind,
                bigBlind: bigBlind,
                defaultBuyIn: defaultBuyIn,
                maxBuyIn: maxBuyIn,
                actionTimerSeconds: timerOption.seconds
            )
            Task {
                try? await app.host?.updateConfig(cfg)
                dismiss()
            }
        } label: {
            Text(midHand ? "Save (applies next hand)" : "Save").frame(maxWidth: .infinity)
        }
        .buttonStyle(PPPrimaryButton())
    }

    private var cancelButton: some View {
        Button { dismiss() } label: {
            Text("Cancel").frame(maxWidth: .infinity)
        }
        .buttonStyle(PPSecondaryButton())
    }
}
#endif
