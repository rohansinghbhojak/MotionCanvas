import SwiftUI

// MARK: - RootView


struct RootView: View {
    @StateObject private var appState = AppState()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Main content — always in the hierarchy so state is preserved
            Group {
                if appState.hasSeenOnboarding {
                    MainMenuView()
                        .environmentObject(appState)
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: appState.hasSeenOnboarding)
            .opacity(showSplash ? 0 : 1)

            // Splash overlaid on top; auto-dismissed after ~2.4 s
            if showSplash {
                SplashScreenView(isVisible: $showSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: showSplash)
    }
}
