import SwiftUI
import UIKit

// MARK: - MainMenuView

struct MainMenuView: View {
    @EnvironmentObject var appState: AppState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.09).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 4) {
                        Text("MOTION")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4)).tracking(9)
                        Text("Canvas")
                            .font(.system(size: 52, weight: .thin, design: .rounded))
                            .foregroundStyle(.white)
                        Text("No rules. Just you, motion, and color.")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.top, 68)

                    Spacer()

                    // Mode cards
                    VStack(spacing: 14) {
                        ForEach(GameMode.allCases, id: \.self) { mode in
                            ModeCard(mode: mode, highScore: appState.highScores[mode.rawValue]) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                path.append(mode)
                            }
                        }
                    }
                    .padding(.horizontal, 18)

                    Spacer()

                    // Personal best footer
                    VStack(spacing: 2) {
                        Text("YOUR BEST")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35)).tracking(2)
                        Text("\(appState.highScores.values.max() ?? 0)")
                            .font(.system(size: 24, weight: .thin, design: .monospaced))
                            .foregroundStyle(.yellow)
                        if (appState.highScores.values.max() ?? 0) == 0 {
                            Text("Your first creation awaits 🎨")
                                .font(.system(size: 10, weight: .light))
                                .foregroundStyle(.white.opacity(0.28))
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: GameMode.self) { mode in
                modeDestination(mode)
                    .environmentObject(appState)
                    .navigationBarHidden(true)
            }
        }
        .onAppear { appState.loadHighScores() }
    }

    @ViewBuilder
    private func modeDestination(_ mode: GameMode) -> some View {
        switch mode {
        case .freeCanvas:    FreeCanvasView()
        case .constellation: ConstellationView()
        case .colorFill:     ColorFillView()
        }
    }
}

// MARK: - ModeCard
// Tappable card representing one game mode on the main menu.

struct ModeCard: View {
    let mode:      GameMode
    let highScore: Int?
    let action:    () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: mode.gradientColors,
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 52, height: 52)
                        Image(systemName: mode.icon)
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(mode.rawValue)
                                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            Spacer()
                            if let hs = highScore, hs > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 9)).foregroundStyle(.yellow)
                                    Text("\(hs)")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.yellow)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.yellow.opacity(0.15), in: Capsule())
                            }
                        }
                        Text(mode.subtitle)
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 11)).foregroundStyle(mode.accentColor.opacity(0.8))
                    Text(mode.objective)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                .padding(.top, 12).padding(.leading, 2)
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Text("PLAY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(mode.accentColor).tracking(3)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(mode.accentColor)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(16)
            .background(ZStack {
                RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.055))
                RoundedRectangle(cornerRadius: 22).stroke(mode.accentColor.opacity(0.3), lineWidth: 1)
            })
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(pressed ? 0.97 : 1.0)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded   { _ in pressed = false })
    }
}


