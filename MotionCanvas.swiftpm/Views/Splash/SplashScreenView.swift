import SwiftUI
import UIKit

// MARK: - SplashScreenView


struct SplashScreenView: View {
    @Binding var isVisible: Bool

    @State private var iconScale:       CGFloat = 0.55
    @State private var iconOpacity:     Double  = 0.0
    @State private var glowRadius:      CGFloat = 20
    @State private var glowOpacity:     Double  = 0.0
    @State private var titleOpacity:    Double  = 0.0
    @State private var subtitleOpacity: Double  = 0.0
    @State private var ringScale:       CGFloat = 0.7
    @State private var ringOpacity:     Double  = 0.0
    @State private var pulsePhase:      Double  = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.12), .clear],
                center: .center, startRadius: 0, endRadius: 220)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon with pulse rings
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.35), Color.cyan.opacity(0.25)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.2)
                            .frame(width: CGFloat(130 + i * 44), height: CGFloat(130 + i * 44))
                            .scaleEffect(ringScale + sin(pulsePhase + Double(i) * 1.1) * 0.04)
                            .opacity(ringOpacity - Double(i) * 0.12)
                    }
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.purple.opacity(0.45), .clear],
                            center: .center, startRadius: 0, endRadius: 65))
                        .frame(width: 130, height: 130)
                        .blur(radius: glowRadius).opacity(glowOpacity)

                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(white: 0.12), Color(white: 0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 110, height: 110)
                            .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 8)

                        if let uiImg = UIImage(named: "AppIcon") {
                            Image(uiImage: uiImg)
                                .resizable().scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        } else {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 52, weight: .ultraLight))
                                .foregroundStyle(LinearGradient(
                                    colors: [.cyan, .purple],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                    .scaleEffect(iconScale).opacity(iconOpacity)
                }
                .frame(height: 240)

                VStack(spacing: 6) {
                    Text("MOTION")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45)).tracking(10)
                    Text("Canvas")
                        .font(.system(size: 46, weight: .thin, design: .rounded))
                        .foregroundStyle(.white)
                }
                .opacity(titleOpacity).padding(.top, 28)

                Text("Your body is the brush.\nEvery move is already art.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48).padding(.top, 10)
                    .opacity(subtitleOpacity)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                iconScale = 1.0; iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0)) {
                glowRadius = 40; glowOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                ringScale = 1.0; ringOpacity = 0.75
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.3))  { titleOpacity    = 1.0 }
            withAnimation(.easeOut(duration: 0.6).delay(0.55)) { subtitleOpacity = 1.0 }
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                pulsePhase = .pi * 2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeInOut(duration: 0.6)) { isVisible = false }
            }
        }
    }
}
