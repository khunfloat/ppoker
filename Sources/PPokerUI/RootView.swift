#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
    @StateObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase

    public init(app: AppState = AppState()) {
        _app = StateObject(wrappedValue: app)
    }

    public var body: some View {
        ZStack {
            switch app.route {
            case .home:
                HomeView()
            case .hostSetup:
                HostSetupView()
            case .lobby:
                LobbyView()
            case .browse:
                BrowseRoomsView()
            case .table:
                TableView()
            case .stats:
                StatsView()
            }
            if scenePhase != .active {
                PrivacyBlurView()
            }
        }
        .environmentObject(app)
        .preferredColorScheme(.dark)
    }
}

public struct PrivacyBlurView: View {
    public init() {}
    public var body: some View {
        ZStack {
            #if canImport(UIKit)
            BlurEffect(style: .systemMaterial)
                .ignoresSafeArea()
            #else
            Color.black.opacity(0.85).ignoresSafeArea()
            #endif
            VStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                Text("Privacy Mode")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }
}

#if canImport(UIKit)
import UIKit
struct BlurEffect: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
#endif
#endif
