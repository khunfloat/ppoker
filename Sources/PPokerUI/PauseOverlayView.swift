#if canImport(SwiftUI)
import SwiftUI

public struct PauseOverlayView: View {
    public let hostName: String
    public let isHost: Bool
    public let onResume: () -> Void
    public let onEnd: () -> Void

    public init(hostName: String, isHost: Bool, onResume: @escaping () -> Void, onEnd: @escaping () -> Void) {
        self.hostName = hostName
        self.isHost = isHost
        self.onResume = onResume
        self.onEnd = onEnd
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text("Game Paused")
                    .font(.title2).bold()
                    .foregroundStyle(.white)
                Text("by \(hostName)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                if isHost {
                    VStack(spacing: 10) {
                        Button { onResume() } label: {
                            Text("Resume").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PPPrimaryButton())
                        Button(role: .destructive) { onEnd() } label: {
                            Text("End Session").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PPSecondaryButton())
                    }
                    .frame(maxWidth: 300)
                } else {
                    Text("Waiting for host…")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 12)
                }
            }
            .padding(32)
        }
    }
}
#endif
