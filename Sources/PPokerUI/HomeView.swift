#if canImport(SwiftUI)
import SwiftUI

public struct HomeView: View {
    @EnvironmentObject var app: AppState

    public init() {}

    public var body: some View {
        ZStack {
            PPTheme.appBackground.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 4) {
                    Text("PPoker")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Local play, no internet needed")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                TextField("Your name", text: $app.displayName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(PPTheme.panel)
                    .cornerRadius(12)
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    Button {
                        app.route = .hostSetup
                    } label: {
                        Text("Host Game").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PPPrimaryButton())
                    .disabled(app.displayName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        Task { await app.beginJoining() }
                    } label: {
                        Text("Join Game").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PPSecondaryButton())
                    .disabled(app.displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Spacer()
            }
            .padding(24)
        }
    }
}

public struct PPPrimaryButton: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .padding(.vertical, 16)
            .background(configuration.isPressed ? Color.white.opacity(0.85) : Color.white)
            .foregroundStyle(.black)
            .cornerRadius(12)
    }
}

public struct PPSecondaryButton: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .padding(.vertical, 16)
            .background(Color.clear)
            .foregroundStyle(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
#endif
