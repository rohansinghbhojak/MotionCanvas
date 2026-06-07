import SwiftUI
import UIKit

// MARK: - CanvasView


struct CanvasView: View {
    @ObservedObject var model: CanvasModel
    @Binding var size: CGSize

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, canvasSize in
                ctx.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(.black))
                for stroke in model.strokes { drawStroke(stroke, in: ctx) }
                if let live = model.currentStroke { drawStroke(live, in: ctx) }
            }
            .background(Color.black)
            .onAppear { size = geo.size }
            .onChange(of: geo.size) { size = $0 }
        }
    }

    func drawStroke(_ stroke: Stroke, in ctx: GraphicsContext) {
        guard stroke.points.count > 1 else { return }
        switch stroke.brushType {

        case .pen, .water:
            var path = Path()
            path.move(to: stroke.points[0])
            for pt in stroke.points.dropFirst() { path.addLine(to: pt) }
            ctx.stroke(path,
                       with: .color(stroke.color.opacity(stroke.opacity)),
                       style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))

        case .neon:
            var path = Path()
            path.move(to: stroke.points[0])
            for pt in stroke.points.dropFirst() { path.addLine(to: pt) }
            var glowCtx = ctx
            glowCtx.blendMode = .plusLighter
            glowCtx.opacity   = stroke.opacity * 0.45
            glowCtx.stroke(path, with: .color(stroke.color),
                           style: StrokeStyle(lineWidth: stroke.lineWidth * 3, lineCap: .round, lineJoin: .round))
            var coreCtx = ctx
            coreCtx.blendMode = .plusLighter
            coreCtx.opacity   = stroke.opacity
            coreCtx.stroke(path, with: .color(.white),
                           style: StrokeStyle(lineWidth: stroke.lineWidth * 0.4, lineCap: .round, lineJoin: .round))

        case .spray:
            for pt in stride(from: 0, to: stroke.points.count, by: 2) {
                let pos = stroke.points[pt]
                for _ in 0..<8 {
                    let angle = Double.random(in: 0...2 * .pi)
                    let r     = CGFloat.random(in: 0...stroke.lineWidth * 1.5)
                    let dot   = CGPoint(x: pos.x + r * CGFloat(cos(angle)),
                                        y: pos.y + r * CGFloat(sin(angle)))
                    let size  = CGFloat.random(in: 1...3)
                    let dotPath = Path(ellipseIn: CGRect(x: dot.x - size/2, y: dot.y - size/2, width: size, height: size))
                    ctx.fill(dotPath, with: .color(stroke.color.opacity(Double.random(in: 0.3...0.7))))
                }
            }

        case .chalk:
            for pt in stride(from: 0, to: stroke.points.count, by: 1) {
                let pos = stroke.points[pt]
                for _ in 0..<5 {
                    let jx   = CGFloat.random(in: -stroke.lineWidth * 0.5...stroke.lineWidth * 0.5)
                    let jy   = CGFloat.random(in: -stroke.lineWidth * 0.5...stroke.lineWidth * 0.5)
                    let size = CGFloat.random(in: 1...2.5)
                    let dotPath = Path(ellipseIn: CGRect(x: pos.x+jx-size/2, y: pos.y+jy-size/2, width: size, height: size))
                    ctx.fill(dotPath, with: .color(stroke.color.opacity(Double.random(in: 0.2...0.55))))
                }
            }
        }
    }
}

// MARK: - HighScoreBannerView
// Celebratory banner shown whenever the player beats their personal best.

struct HighScoreBannerView: View {
    @State private var scale:          CGFloat = 0.5
    @State private var opacity:        Double  = 0
    @State private var offsetY:        CGFloat = 30
    @State private var shimmer:        CGFloat = -1.0
    @State private var sparkleOpacity: Double  = 0
    @State private var chosenMessage:  String  = ""

    private let messages: [String] = [
        "That's YOUR best yet! 🌟",
        "Look what you just did! ✨",
        "A new personal record — YOU did that! 🎉",
        "That's your masterpiece score! 🏆",
        "You just levelled up! Keep shining ✨",
        "New high score! You're on fire 🔥",
        "Your best creation so far! 🎨",
        "Every session you get better 🌈"
    ]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 18) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow.opacity(sparkleOpacity - Double(i) * 0.1))
                        .scaleEffect(sparkleOpacity > 0 ? 1.0 : 0.3)
                        .animation(.spring(duration: 0.4).delay(Double(i) * 0.08), value: sparkleOpacity)
                }
            }

            ZStack {
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.yellow.opacity(0.22), Color.orange.opacity(0.18)],
                        startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(Color.yellow.opacity(0.45), lineWidth: 1))
                Capsule()
                    .fill(LinearGradient(
                        colors: [.clear, .white.opacity(0.18), .clear],
                        startPoint: UnitPoint(x: shimmer,       y: 0.5),
                        endPoint:   UnitPoint(x: shimmer + 0.4, y: 0.5)))
                    .clipped()
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Text("NEW HIGH SCORE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .tracking(2)
                }
                .padding(.horizontal, 18).padding(.vertical, 9)
            }
            .fixedSize()

            Text(chosenMessage)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(y: offsetY)
        .onAppear {
            chosenMessage = messages.randomElement() ?? messages[0]
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                scale = 1.0; opacity = 1.0; offsetY = 0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { sparkleOpacity = 1.0 }
            withAnimation(.linear(duration: 1.1).delay(0.3))   { shimmer = 1.2 }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - GameOverView
// Generic game-over overlay used by modes that produce a canvas snapshot.

struct GameOverView: View {
    let score:          Int
    let mode:           GameMode
    let canvasSnapshot: UIImage?
    let isNewHighScore: Bool
    let onReplay:       () -> Void
    let onMenu:         () -> Void

    @State private var appeared  = false
    @State private var displayed = 0
    @State private var showBtns  = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 26) {
                if let img = canvasSnapshot {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1), lineWidth: 1))
                        .shadow(color: mode.accentColor.opacity(0.4), radius: 20)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }
                VStack(spacing: 6) {
                    Text("COMPLETE")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4)).tracking(6)
                    Text("\(displayed)")
                        .font(.system(size: 58, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(mode.accentColor)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.8), value: displayed)
                }
                .opacity(appeared ? 1 : 0)
                if isNewHighScore {
                    HighScoreBannerView().transition(.scale(scale: 0.7).combined(with: .opacity))
                }
                if showBtns {
                    VStack(spacing: 10) {
                        Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onReplay() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise"); Text("Play Again")
                            }
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(mode.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        }
                        Button("Main Menu") { onMenu() }
                            .font(.system(size: 15)).foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 36)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.65)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 1.0)) { displayed = score }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.spring(duration: 0.5)) { showBtns = true }
            }
        }
    }
}

// MARK: - BounceButtonStyle
// Shared button style that gives a springy press-down feel.

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}
