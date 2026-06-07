import SwiftUI
import UIKit
import QuartzCore

// MARK: - PaintTarget


class PaintTarget: NSObject {
    let tick: () -> Void
    init(tick: @escaping () -> Void) { self.tick = tick }
    @objc func onTick() { tick() }
}

// MARK: - ColorFillView


struct ColorFillView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = MotionManager()

    @State private var canvasSize          = CGSize.zero
    @State private var shape: FillShape    = FillShape.all.randomElement()!
    @State private var shapePath: Path     = Path()
    @State private var allStrokes:         [PaintStroke] = []
    @State private var currentStrokePoints:[CGPoint]     = []

    // Coverage grid
    @State private var coveredCells    = Set<Int>()
    @State private var totalShapeCells = 0
    @State private var insideStrokeCount = 0
    @State private var totalStrokeCount  = 0

    // Colour
    @State private var colorIndex = 0
    let palette: [Color] = [.cyan, .pink, .yellow, .green, .orange, .purple, .mint, .red,
                             Color(red: 1, green: 0.3, blue: 0.5), .teal]
    var currentColor: Color { palette[colorIndex] }

    // Game state
    @State private var phase: GamePhase  = .countdown
    @State private var countdownVal      = 3
    @State private var timeLeft: Double  = 50
    @State private var gameTimer: Timer? = nil
    @State private var displayLink: CADisplayLink? = nil
    @State private var score             = 0
    @State private var coveragePercent   = 0.0
    @State private var accuracyPercent   = 0.0
    @State private var paintSnapshot: UIImage? = nil
    @State private var shapeSnapshot: UIImage? = nil
    @State private var isNewHighScore    = false

    enum GamePhase { case countdown, playing, result }

    let gridCols = 30
    let gridRows = 50

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    // Paint strokes canvas
                    Canvas { ctx, _ in
                        for stroke in allStrokes {
                            guard stroke.points.count > 1 else { continue }
                            var path = Path(); path.move(to: stroke.points[0])
                            for pt in stroke.points.dropFirst() { path.addLine(to: pt) }
                            ctx.stroke(path, with: .color(stroke.color.opacity(stroke.opacity)),
                                       style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                        }
                        if currentStrokePoints.count > 1 {
                            var livePath = Path(); livePath.move(to: currentStrokePoints[0])
                            for pt in currentStrokePoints.dropFirst() { livePath.addLine(to: pt) }
                            ctx.stroke(livePath, with: .color(currentColor.opacity(0.85)),
                                       style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .ignoresSafeArea()

                    // Shape outline guide
                    if phase == .playing || phase == .result {
                        shapePath.stroke(.white.opacity(0.9),
                                         style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        shapePath.stroke(currentColor.opacity(0.3),
                                         style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                            .blur(radius: 4)
                            .animation(.easeInOut(duration: 0.3), value: colorIndex)
                    }

                    // Brush cursor
                    if phase == .playing {
                        let pos = brushPos(in: geo.size)
                        ZStack {
                            Circle().fill(currentColor.opacity(0.35)).frame(width: 52, height: 52).blur(radius: 16)
                            Circle().fill(currentColor).frame(width: 18, height: 18).shadow(color: currentColor, radius: 8)
                            Circle().stroke(.white.opacity(0.6), lineWidth: 2).frame(width: 52, height: 52)
                        }
                        .position(pos).allowsHitTesting(false)
                    }
                }
                .onAppear   { canvasSize = geo.size; buildShape(in: geo.size); buildShapeGrid(in: geo.size) }
                .onChange(of: geo.size) { canvasSize = $0; buildShape(in: $0); buildShapeGrid(in: $0) }
            }

            if phase == .playing  { hudView }
            if phase == .countdown { countdownView }
            if phase == .result {
                ColorFillResultView(
                    shape: shape, score: score, coverage: coveragePercent, accuracy: accuracyPercent,
                    paintSnapshot: paintSnapshot, shapeSnapshot: shapeSnapshot,
                    color: currentColor, isNewHighScore: isNewHighScore,
                    onReplay: restartGame, onMenu: { dismiss() })
                .transition(.opacity)
                .animation(.easeIn(duration: 0.5), value: phase == .result)
            }
        }
        .navigationBarHidden(true)
        .onAppear   { motion.startUpdates(); runCountdown() }
        .onDisappear { stopDisplayLink(); motion.stopUpdates(); gameTimer?.invalidate() }
        .onChange(of: motion.shakeIntensity) { v in
            if v > 1.8 && phase == .playing { cycleColor() }
        }
    }

    // MARK: - Shape & grid

    private func buildShape(in size: CGSize) { shapePath = shape.path(size) }

    private func buildShapeGrid(in size: CGSize) {
        guard size != .zero else { return }
        var count = 0
        let cw = size.width / CGFloat(gridCols), ch = size.height / CGFloat(gridRows)
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                if shapePath.contains(CGPoint(x: CGFloat(col)*cw+cw/2, y: CGFloat(row)*ch+ch/2)) { count += 1 }
            }
        }
        totalShapeCells = max(1, count)
    }

    private func cellIndex(for pt: CGPoint) -> Int {
        guard canvasSize != .zero else { return 0 }
        let col = Int(pt.x / canvasSize.width  * CGFloat(gridCols))
        let row = Int(pt.y / canvasSize.height * CGFloat(gridRows))
        return row * gridCols + col
    }

    // MARK: - DisplayLink

    private func startDisplayLink() {
        let dl = CADisplayLink(target: PaintTarget(tick: paintTick), selector: #selector(PaintTarget.onTick))
        dl.add(to: .main, forMode: .common); displayLink = dl
    }
    private func stopDisplayLink() { displayLink?.invalidate(); displayLink = nil }

    // MARK: - Paint tick (60 fps)

    private func paintTick() {
        guard canvasSize != .zero, phase == .playing else { return }
        let pos = brushPos(in: canvasSize)
        currentStrokePoints.append(pos)
        let cell = cellIndex(for: pos)
        totalStrokeCount += 1
        if shapePath.contains(pos) {
            insideStrokeCount += 1
            if !coveredCells.contains(cell) {
                coveredCells.insert(cell)
                let insideCount = coveredCells.filter { idx in
                    let col = idx % gridCols, row = idx / gridCols
                    let cw = canvasSize.width/CGFloat(gridCols), ch = canvasSize.height/CGFloat(gridRows)
                    return shapePath.contains(CGPoint(x: CGFloat(col)*cw+cw/2, y: CGFloat(row)*ch+ch/2))
                }.count
                coveragePercent = min(1.0, Double(insideCount) / Double(totalShapeCells))
            }
        }
    }

    private func brushPos(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width  / 2 + CGFloat(motion.smoothRoll)  * size.width  * 0.38,
            y: size.height / 2 + CGFloat(motion.smoothPitch) * size.height * 0.34)
    }

    private func cycleColor() {
        if !currentStrokePoints.isEmpty {
            allStrokes.append(PaintStroke(points: currentStrokePoints, color: currentColor, width: 18, opacity: 0.85))
            currentStrokePoints = []
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(duration: 0.3)) { colorIndex = (colorIndex + 1) % palette.count }
    }

    // MARK: - HUD

    private var hudView: some View {
        VStack {
            HStack(alignment: .top) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6)).frame(width: 38, height: 38)
                        .background(.black.opacity(0.45), in: Circle())
                }
                Spacer()
                VStack(spacing: 5) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12)).frame(width: 140, height: 10)
                        Capsule()
                            .fill(LinearGradient(colors: [currentColor, currentColor.opacity(0.6)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: 140 * CGFloat(coveragePercent), height: 10)
                            .animation(.easeOut(duration: 0.1), value: coveragePercent)
                    }
                    Text("\(Int(coveragePercent * 100))% filled")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", timeLeft))
                        .font(.system(size: 28, weight: .thin, design: .monospaced))
                        .foregroundStyle(timeLeft > 15 ? .white : .red)
                    Text("SEC").font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3)).tracking(2)
                }
            }
            .padding(.horizontal, 16).padding(.top, 56)
            Spacer()
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { idx, c in
                        Circle().fill(c)
                            .frame(width: idx == colorIndex ? 16 : 9, height: idx == colorIndex ? 16 : 9)
                            .shadow(color: idx == colorIndex ? c : .clear, radius: 5)
                            .animation(.spring(duration: 0.25), value: colorIndex)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())
                Text("🖌 Tilt to paint anywhere  •  🤙 Shake to change colour")
                    .font(.system(size: 11, weight: .light)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, 44)
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("COLOR FILL")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(GameMode.colorFill.accentColor.opacity(0.8)).tracking(5)
                Text(shape.emoji).font(.system(size: 60))
                Text("Fill the \(shape.name)!")
                    .font(.system(size: 26, weight: .light)).foregroundStyle(.white)
                VStack(spacing: 6) {
                    Text("🖌  Tilt your phone to paint — go anywhere!")
                    Text("🤙  Shake to switch colour")
                    Text("⭐  Score = how much you filled the shape")
                }
                .font(.system(size: 13, weight: .light)).foregroundStyle(.white.opacity(0.5))
                if countdownVal > 0 {
                    Text("\(countdownVal)")
                        .font(.system(size: 90, weight: .ultraLight, design: .rounded)).foregroundStyle(.white)
                        .id(countdownVal)
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                        .animation(.spring(duration: 0.4), value: countdownVal)
                } else {
                    Text("PAINT!")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(GameMode.colorFill.accentColor)
                        .shadow(color: GameMode.colorFill.accentColor.opacity(0.8), radius: 20)
                }
            }
        }
    }

    // MARK: - Lifecycle

    private func runCountdown() {
        final class Box { var value: Int; init(_ v: Int) { value = v } }
        let tick = Box(3)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            withAnimation { countdownVal = tick.value - 1 }
            UIImpactFeedbackGenerator(style: tick.value == 1 ? .heavy : .light).impactOccurred()
            tick.value -= 1
            if tick.value < 0 {
                t.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { phase = .playing }
                    startDisplayLink(); startTimer()
                }
            }
        }
    }

    private func startTimer() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeLeft = max(0, timeLeft - 0.1)
            if timeLeft <= 0 { finishGame() }
        }
    }

    private func finishGame() {
        stopDisplayLink(); gameTimer?.invalidate()
        if !currentStrokePoints.isEmpty {
            allStrokes.append(PaintStroke(points: currentStrokePoints, color: currentColor, width: 18, opacity: 0.85))
            currentStrokePoints = []
        }
        let total = max(1, totalStrokeCount)
        accuracyPercent = Double(insideStrokeCount) / Double(total)
        score = Int(coveragePercent * 700) + Int(accuracyPercent * 300) + max(0, Int(timeLeft) * 4)
        isNewHighScore = appState.saveHighScore(mode: GameMode.colorFill.rawValue, score: score)
        paintSnapshot  = renderPaintSnapshot()
        shapeSnapshot  = renderShapeSnapshot()
        withAnimation(.easeIn(duration: 0.5)) { phase = .result }
    }

    private func renderPaintSnapshot() -> UIImage? {
        guard canvasSize != .zero else { return nil }
        var strokesToDraw = allStrokes
        if currentStrokePoints.count > 1 {
            strokesToDraw.append(PaintStroke(points: currentStrokePoints, color: currentColor, width: 18, opacity: 0.85))
        }
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { _ in
            let ctx = UIGraphicsGetCurrentContext()!
            UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))
            ctx.setLineCap(.round); ctx.setLineJoin(.round)
            ctx.saveGState(); ctx.addPath(shapePath.cgPath); ctx.clip()
            for stroke in strokesToDraw {
                guard stroke.points.count > 1 else { continue }
                ctx.beginPath(); ctx.setLineWidth(stroke.width)
                ctx.setStrokeColor(UIColor(stroke.color).withAlphaComponent(stroke.opacity).cgColor)
                ctx.move(to: stroke.points[0])
                for pt in stroke.points.dropFirst() { ctx.addLine(to: pt) }
                ctx.strokePath()
            }
            ctx.restoreGState()
            ctx.beginPath(); ctx.addPath(shapePath.cgPath)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            ctx.setLineWidth(4); ctx.strokePath()
        }
    }

    private func renderShapeSnapshot() -> UIImage? { return nil }

    private func restartGame() {
        stopDisplayLink(); gameTimer?.invalidate()
        phase = .countdown; countdownVal = 3; score = 0; timeLeft = 50
        allStrokes = []; currentStrokePoints = []
        coveredCells = []; insideStrokeCount = 0; totalStrokeCount = 0
        coveragePercent = 0; accuracyPercent = 0; colorIndex = 0
        shape = FillShape.all.randomElement()!
        paintSnapshot = nil; shapeSnapshot = nil
        if canvasSize != .zero { buildShape(in: canvasSize); buildShapeGrid(in: canvasSize) }
        runCountdown()
    }
}

// MARK: - ColorFillResultView
// Results screen shown after time runs out; displays score, coverage bar and artwork preview.

struct ColorFillResultView: View {
    let shape:         FillShape
    let score:         Int
    let coverage:      Double
    let accuracy:      Double
    let paintSnapshot: UIImage?
    let shapeSnapshot: UIImage?
    let color:         Color
    let isNewHighScore: Bool
    let onReplay:      () -> Void
    let onMenu:        () -> Void

    @State private var appeared  = false
    @State private var displayed = 0

    var grade: String {
        if coverage > 0.85 { return "MASTERPIECE! 🎨" }
        if coverage > 0.65 { return "WELL DONE! 🌟" }
        if coverage > 0.4  { return "GREAT START! ✨" }
        return "YOU'VE GOT THIS! 💛"
    }
    var starCount: Int {
        if coverage > 0.85 { return 3 }
        if coverage > 0.55 { return 2 }
        if coverage > 0.3  { return 1 }
        return 0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Text(grade).font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(color).shadow(color: color.opacity(0.7), radius: 10)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < starCount ? "star.fill" : "star")
                                .font(.system(size: 22))
                                .foregroundStyle(i < starCount ? .yellow : .white.opacity(0.2))
                                .shadow(color: i < starCount ? .yellow.opacity(0.8) : .clear, radius: 6)
                                .scaleEffect(appeared && i < starCount ? 1.15 : 1)
                                .animation(.spring(duration: 0.4).delay(Double(i) * 0.12 + 0.2), value: appeared)
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 48)
                .scaleEffect(appeared ? 1 : 0.7).opacity(appeared ? 1 : 0)
                .animation(.spring(duration: 0.5), value: appeared)

                if isNewHighScore {
                    HighScoreBannerView().padding(.horizontal, 20)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }

                Group {
                    if let img = paintSnapshot {
                        Image(uiImage: img).resizable()
                            .aspectRatio(img.size, contentMode: .fit)
                            .frame(maxWidth: .infinity).frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: color.opacity(0.25), radius: 12)
                    } else {
                        RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05))
                            .frame(maxWidth: .infinity).frame(height: 220)
                            .overlay(VStack(spacing: 8) {
                                Text(shape.emoji).font(.system(size: 52))
                                Text("Your painting").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                            })
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 10) {
                    ResultStat(label: "SCORE",    value: "\(displayed)",          unit: "pts", color: color)
                    ResultStat(label: "FILLED",   value: "\(Int(coverage*100))",  unit: "%",   color: .cyan)
                    ResultStat(label: "IN SHAPE", value: "\(Int(accuracy*100))",  unit: "%",   color: .green)
                }
                .padding(.horizontal, 18)
                .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("COVERAGE").font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4)).tracking(3)
                        Spacer()
                        Text("\(Int(coverage*100))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(color)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.1))
                            Capsule()
                                .fill(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: appeared ? g.size.width * CGFloat(coverage) : 0)
                                .animation(.spring(duration: 1.3).delay(0.4), value: appeared)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

                VStack(spacing: 8) {
                    Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onReplay() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise"); Text("Try Another Shape")
                        }
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(color, in: RoundedRectangle(cornerRadius: 15))
                    }
                    Button("Main Menu") { onMenu() }
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 1.2)) { displayed = score }
            }
        }
    }
}

// MARK: - ResultStat
// A small labelled stat box used in the Color Fill result screen.

struct ResultStat: View {
    let label: String
    let value: String
    let unit:  String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35)).tracking(2)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 26, weight: .light, design: .monospaced))
                    .foregroundStyle(color).contentTransition(.numericText())
                Text(unit).font(.system(size: 12, design: .monospaced)).foregroundStyle(color.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}
