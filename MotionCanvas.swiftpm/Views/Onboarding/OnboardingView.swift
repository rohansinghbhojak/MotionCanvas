import SwiftUI
import UIKit

// MARK: - OnboardingPage

struct OnboardingPage {
    let icon:     String
    let title:    String
    let subtitle: String
    let color:    Color
}

// MARK: - ParticleData
// A single floating particle in the onboarding background.

struct ParticleData: Identifiable {
    let id       = UUID()
    var position: CGPoint
    var color:    Color
    var size:     CGFloat
    var opacity:  Double
}

// MARK: - OnboardingView
// Three-page walkthrough shown on first launch.
// Background particles are driven by live device tilt via MotionManager.

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var motion = MotionManager()

    @State private var currentPage:       Int           = 0
    @State private var particlePositions: [ParticleData] = []
    @State private var titleOpacity:      Double        = 0.0
    @State private var titleScale:        Double        = 0.6
    @State private var glowPhase:         Double        = 0.0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "gyroscope",
            title: "You're the Brush",
            subtitle: "No pens. No pressure. No wrong moves.\nJust tilt — and watch the magic happen.",
            color: .cyan),
        OnboardingPage(
            icon: "waveform.path",
            title: "Move Freely",
            subtitle: "Shake, roll, and drift to paint\nbursts of color only you could create.",
            color: .purple),
        OnboardingPage(
            icon: "trophy.fill",
            title: "Make It Yours",
            subtitle: "Every stroke is a win.\nYour canvas, your rules, your masterpiece.",
            color: .yellow),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Motion-driven particle field
            ForEach(particlePositions) { particle in
                Circle()
                    .fill(particle.color.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: particle.size * 0.3)
            }

            VStack(spacing: 0) {
                // Animated icon with glow rings
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(pages[currentPage].color.opacity(0.15 + Double(i) * 0.05), lineWidth: 1)
                            .frame(width: CGFloat(100 + i * 40), height: CGFloat(100 + i * 40))
                            .scaleEffect(1.0 + sin(glowPhase + Double(i)) * 0.08)
                    }
                    ZStack {
                        Circle()
                            .fill(pages[currentPage].color.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: pages[currentPage].icon)
                            .font(.system(size: 44, weight: .ultraLight))
                            .foregroundStyle(pages[currentPage].color)
                    }
                }
                .frame(height: 200)
                .animation(.easeInOut(duration: 0.5), value: currentPage)

                // Slide text
                VStack(spacing: 16) {
                    Text(pages[currentPage].title)
                        .font(.system(size: 36, weight: .thin, design: .rounded))
                        .foregroundStyle(.white).multilineTextAlignment(.center)
                    Text(pages[currentPage].subtitle)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center).lineSpacing(6)
                }
                .padding(.horizontal, 40)
                .id(currentPage)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)))
                .animation(.spring(duration: 0.5), value: currentPage)

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? pages[currentPage].color : .white.opacity(0.3))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(duration: 0.4), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // CTA button
                Button(action: handleCTA) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(pages[currentPage].color).frame(height: 60)
                        Text(currentPage == pages.count - 1 ? "Start Creating ✨" : "Next")
                            .font(.system(size: 18, weight: .semibold)).foregroundStyle(.black)
                    }
                }
                .padding(.horizontal, 40).padding(.bottom, 60)
                .buttonStyle(BounceButtonStyle())
            }
            .opacity(titleOpacity)
        }
        .onAppear {
            setupParticles()
            withAnimation(.easeOut(duration: 1.0)) { titleOpacity = 1.0; titleScale = 1.0 }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { glowPhase = .pi * 2 }
            motion.startUpdates()
        }
        .onDisappear { motion.stopUpdates() }
        .onChange(of: motion.roll) { _ in updateParticles() }
    }

    // MARK: - Actions

    private func handleCTA() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if currentPage < pages.count - 1 {
            currentPage += 1
        } else {
            appState.completeOnboarding()
        }
    }

    private func setupParticles() {
        let s = UIScreen.main.bounds
        particlePositions = (0..<60).map { _ in
            ParticleData(
                position: CGPoint(x: CGFloat.random(in: 0...s.width),
                                  y: CGFloat.random(in: 0...s.height)),
                color:    [Color.cyan, .purple, .indigo, .blue].randomElement()!,
                size:     CGFloat.random(in: 2...6),
                opacity:  Double.random(in: 0.1...0.5))
        }
    }

    private func updateParticles() {
        let s  = UIScreen.main.bounds
        let dx = motion.roll  * 3
        let dy = motion.pitch * 3
        for i in particlePositions.indices {
            var p = particlePositions[i]
            p.position.x += CGFloat(dx)
            p.position.y += CGFloat(dy)
            if p.position.x < 0           { p.position.x = s.width }
            if p.position.x > s.width     { p.position.x = 0 }
            if p.position.y < 0           { p.position.y = s.height }
            if p.position.y > s.height    { p.position.y = 0 }
            particlePositions[i] = p
        }
    }
}
