import SwiftUI
import UIKit
import QuartzCore

// MARK: - ConstellationTarget


class ConstellationTarget: NSObject {
    let tick: () -> Void
    init(tick: @escaping () -> Void) { self.tick = tick }
    @objc func onTick() { tick() }
}

// MARK: - ConstellationView


struct ConstellationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = MotionManager()

    @State private var canvasSize         = CGSize.zero
    @State private var shape: ConstellationShape = ConstellationShape.all.randomElement()!
    @State private var stars:             [ConstellationStar] = []
    @State private var nextStarIndex      = 0
    @State private var completedSegments: [[CGPoint]] = []
    @State private var currentSegment:    [CGPoint]   = []

    @State private var score             = 0
    @State private var combo             = 0
    @State private var timeLeft: Double  = 75
    @State private var gameTimer: Timer? = nil
    @State private var displayLink: CADisplayLink? = nil

    @State private var phase: GamePhase  = .countdown
    @State private var countdownVal      = 3

    @State private var accuracy          = 0.0
    @State private var resultStarCount   = 0
    @State private var userSnapshot:  UIImage? = nil
    @State private var idealSnapshot: UIImage? = nil
    @State private var isNewHighScore    = false
    @State private var brushUnlocked     = false
    @State private var showFlash         = false
    @State private var flashPos          = CGPoint.zero
    @State private var flashColor        = Color.yellow

    enum GamePhase { case countdown, playing, result }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.08).ignoresSafeArea()
            starfieldView

            GeometryReader { geo in
                ZStack {
                    // Drawn path canvas
                    Canvas { ctx, _ in
                        let segColors: [Color] = [.cyan, .yellow, .orange, .pink, .green, .mint, .purple, .red, .teal, .indigo]
                        for (idx, seg) in completedSegments.enumerated() {
                            guard seg.count > 1 else { continue }
                            let col = segColors[idx % segColors.count]
                            var p = Path(); p.move(to: seg[0])
                            for pt in seg.dropFirst() { p.addLine(to: pt) }
                            var glow = ctx; glow.opacity = 0.28
                            glow.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                            ctx.stroke(p, with: .color(col.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                        if currentSegment.count > 1 {
                            let col = segColors[completedSegments.count % segColors.count]
                            var p = Path(); p.move(to: currentSegment[0])
                            for pt in currentSegment.dropFirst() { p.addLine(to: pt) }
                            var glow = ctx; glow.opacity = 0.22
                            glow.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                            ctx.stroke(p, with: .color(col.opacity(0.85)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .allowsHitTesting(false)

                    // Stars
                    ForEach(stars) { star in
                        ConstellationStarView(
                            star: star,
                            isNext:    star.orderIndex == nextStarIndex && phase == .playing,
                            isVisited: star.isVisited)
                    }

                    // Brush cursor
                    if phase == .playing || (phase == .countdown && !stars.isEmpty) {
                        let pos = brushPosition(in: geo.size)
                        brushCursor(at: pos, locked: !brushUnlocked)
                    }

                    // Star-hit flash
                    if showFlash { starBurst(at: flashPos, color: flashColor) }
                }
                .onAppear  { canvasSize = geo.size; buildStars(in: geo.size) }
                .onChange(of: geo.size) { canvasSize = $0; buildStars(in: $0) }
            }

            if phase == .playing   { hudView }
            if phase == .countdown { countdownView }
            if phase == .result {
                ConstellationResultView(
                    shape: shape, score: score, accuracy: accuracy,
                    starsCollected: stars.filter { $0.isVisited }.count, totalStars: stars.count,
                    resultStarCount: resultStarCount,
                    userSnapshot: userSnapshot, idealSnapshot: idealSnapshot,
                    isNewHighScore: isNewHighScore,
                    onReplay: restartGame, onMenu: { dismiss() })
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .onAppear   { motion.startUpdates(); runCountdown() }
        .onDisappear { stopDisplayLink(); motion.stopUpdates(); gameTimer?.invalidate() }
    }

    // MARK: - Starfield background

    private var starfieldView: some View {
        let xs: [Double] = [0.05,0.15,0.25,0.35,0.45,0.55,0.65,0.75,0.85,0.95,0.10,0.20,0.30,0.40,0.50,0.60,0.70,0.80,0.90,0.08,0.18,0.28,0.38,0.48,0.58,0.68,0.78,0.88,0.98,0.03,0.13,0.23,0.33,0.43,0.53,0.63,0.73,0.83,0.93,0.07,0.17,0.27,0.37,0.47,0.57,0.67,0.77,0.87,0.97,0.02,0.12,0.22,0.32,0.42,0.52,0.62,0.72,0.82,0.92,0.06]
        let ys: [Double] = [0.05,0.12,0.20,0.28,0.36,0.44,0.52,0.60,0.68,0.76,0.84,0.92,0.08,0.16,0.24,0.32,0.40,0.48,0.56,0.64,0.72,0.80,0.88,0.96,0.04,0.11,0.19,0.27,0.35,0.43,0.51,0.59,0.67,0.75,0.83,0.91,0.03,0.10,0.18,0.26,0.34,0.42,0.50,0.58,0.66,0.74,0.82,0.90,0.07,0.15,0.23,0.31,0.39,0.47,0.55,0.63,0.71,0.79,0.87,0.95]
        let s = UIScreen.main.bounds
        return ZStack {
            ForEach(0..<60, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity([0.06,0.10,0.14,0.08,0.12][i % 5]))
                    .frame(width: [1.0,1.5,2.0,1.2,1.8][i % 5])
                    .position(x: s.width * xs[i], y: s.height * ys[i])
            }
        }
    }

    // MARK: - Brush cursor

    private func brushCursor(at pos: CGPoint, locked: Bool) -> some View {
        ZStack {
            if locked {
                Circle().stroke(Color.cyan.opacity(0.45), lineWidth: 2).frame(width: 56, height: 56)
            }
            Circle().fill(Color.cyan.opacity(0.25)).frame(width: 40, height: 40).blur(radius: 10)
            Circle().fill(Color.cyan).frame(width: locked ? 12 : 8, height: locked ? 12 : 8).shadow(color: .cyan, radius: 6)
            Circle().stroke(Color.cyan.opacity(0.5), lineWidth: 1.5).frame(width: 36, height: 36)
        }
        .position(pos).allowsHitTesting(false)
    }

    private func starBurst(at pos: CGPoint, color: Color) -> some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * .pi / 6
                Circle().fill(color.opacity(0.8)).frame(width: 5, height: 5)
                    .offset(x: 25 * CGFloat(cos(angle)), y: 25 * CGFloat(sin(angle)))
            }
            Circle().fill(color.opacity(0.5)).frame(width: 30, height: 30).blur(radius: 8)
        }
        .position(pos).allowsHitTesting(false)
        .transition(.scale(scale: 0.2).combined(with: .opacity))
    }

    // MARK: - HUD

    private var hudView: some View {
        VStack {
            HStack(alignment: .top) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6)).frame(width: 38, height: 38)
                        .background(.black.opacity(0.4), in: Circle())
                }
                Spacer()
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        ForEach(stars.indices, id: \.self) { i in
                            Circle()
                                .fill(stars[i].isVisited ? Color.yellow : .white.opacity(0.2))
                                .frame(width: stars[i].isVisited ? 9 : 6, height: stars[i].isVisited ? 9 : 6)
                                .overlay(Circle().stroke(i == nextStarIndex ? .yellow.opacity(0.8) : .clear, lineWidth: 1.5))
                                .animation(.spring(duration: 0.3), value: stars[i].isVisited)
                        }
                    }
                    Text("\(nextStarIndex) / \(stars.count) stars")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
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
            if nextStarIndex < stars.count {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.yellow)
                    Text(nextStarIndex == 0 ? "Tilt away from Star 1 to begin!" : "Head to star \(nextStarIndex + 1) →")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule()).padding(.bottom, 44)
            }
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("CONSTELLATION")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.7)).tracking(5)
                Text(shape.emoji + "  " + shape.name)
                    .font(.system(size: 28, weight: .light)).foregroundStyle(.white)
                VStack(spacing: 6) {
                    Text("⭐  Your pointer starts ON Star 1")
                    Text("↗️  Tilt away to start drawing")
                    Text("🎯  Visit every star in order")
                    Text("🏆  See your result vs the ideal at the end")
                }
                .font(.system(size: 13, weight: .light)).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center).padding(.horizontal, 20)
                if countdownVal > 0 {
                    Text("\(countdownVal)")
                        .font(.system(size: 90, weight: .ultraLight, design: .rounded)).foregroundStyle(.white)
                        .id(countdownVal).transition(.scale(scale: 1.4).combined(with: .opacity))
                        .animation(.spring(duration: 0.4), value: countdownVal)
                } else {
                    Text("GO!").font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow).shadow(color: .yellow.opacity(0.8), radius: 20)
                }
            }
        }
    }

    // MARK: - Build stars

    private func buildStars(in size: CGSize) {
        guard size != .zero else { return }
        let mx: CGFloat = 80
        let w = size.width - mx * 2, h = size.height - mx * 2
        stars = shape.normalizedPoints.enumerated().map { idx, pt in
            ConstellationStar(position: CGPoint(x: mx + pt.x * w, y: mx + pt.y * h),
                              orderIndex: idx, pulsePhase: Double(idx) * 0.5)
        }
        nextStarIndex = 0; completedSegments = []; currentSegment = []; brushUnlocked = false
    }

    // MARK: - DisplayLink

    private func startDisplayLink() {
        let dl = CADisplayLink(target: ConstellationTarget(tick: motionTick), selector: #selector(ConstellationTarget.onTick))
        dl.add(to: .main, forMode: .common); displayLink = dl
    }
    private func stopDisplayLink() { displayLink?.invalidate(); displayLink = nil }

    // MARK: - Motion tick (60 fps)

    private func motionTick() {
        guard canvasSize != .zero, phase == .playing else { return }
        let rawPos = CGPoint(
            x: canvasSize.width  / 2 + CGFloat(motion.smoothRoll)  * canvasSize.width  * 0.45,
            y: canvasSize.height / 2 + CGFloat(motion.smoothPitch) * canvasSize.height * 0.40)

        if !brushUnlocked {
            guard let firstStar = stars.first else { return }
            if hypot(rawPos.x - firstStar.position.x, rawPos.y - firstStar.position.y) > 28 {
                brushUnlocked = true
                currentSegment = [firstStar.position]
            } else { return }
        }

        let pos = rawPos
        currentSegment.append(pos)
        if currentSegment.count > 800 { currentSegment = Array(currentSegment.suffix(600)) }

        guard nextStarIndex < stars.count else { return }
        let target = stars[nextStarIndex]
        if hypot(pos.x - target.position.x, pos.y - target.position.y) < target.radius + 10 {
            hitStar(at: nextStarIndex)
        }
    }

    private func hitStar(at idx: Int) {
        guard idx < stars.count else { return }
        stars[idx].isVisited = true; stars[idx].visitTime = Date()
        var seg = currentSegment; seg.append(stars[idx].position)
        completedSegments.append(seg)
        currentSegment = [stars[idx].position]
        combo += 1; score += 50 + combo * 15
        flashPos = stars[idx].position
        flashColor = [Color.yellow, .cyan, .orange, .pink, .mint][idx % 5]
        withAnimation(.spring(duration: 0.2)) { showFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { showFlash = false } }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        nextStarIndex += 1
        if nextStarIndex >= stars.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { finishGame() }
        }
    }

    private func brushPosition(in size: CGSize) -> CGPoint {
        if !brushUnlocked, let firstStar = stars.first { return firstStar.position }
        return CGPoint(
            x: size.width  / 2 + CGFloat(motion.smoothRoll)  * size.width  * 0.45,
            y: size.height / 2 + CGFloat(motion.smoothPitch) * size.height * 0.40)
    }

    // MARK: - Game lifecycle

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
        if currentSegment.count > 1 { completedSegments.append(currentSegment) }
        let visited    = stars.filter { $0.isVisited }.count
        let visitRatio = Double(visited) / Double(max(1, stars.count))
        var segAccuracies: [Double] = []
        for seg in completedSegments {
            guard seg.count >= 2 else { continue }
            let idealDist = hypot(seg.last!.x - seg.first!.x, seg.last!.y - seg.first!.y)
            guard idealDist > 10 else { continue }
            var actualLen: CGFloat = 0
            for j in 1..<seg.count { actualLen += hypot(seg[j].x-seg[j-1].x, seg[j].y-seg[j-1].y) }
            let ratio = Double(actualLen / idealDist)
            segAccuracies.append(max(0.0, 1.0 - (ratio - 1.0) / 2.0))
        }
        let straightness = segAccuracies.isEmpty ? 0.0 : segAccuracies.reduce(0,+) / Double(segAccuracies.count)
        accuracy = visitRatio * 0.5 + straightness * 0.5
        score   += max(0, Int(timeLeft) * 6)
        resultStarCount = accuracy > 0.82 ? 3 : accuracy > 0.55 ? 2 : accuracy > 0.30 ? 1 : 0
        isNewHighScore  = appState.saveHighScore(mode: GameMode.constellation.rawValue, score: score)
        userSnapshot    = renderUserSnapshot()
        idealSnapshot   = renderIdealSnapshot()
        withAnimation(.easeIn(duration: 0.5)) { phase = .result }
    }

    // MARK: - Snapshot rendering

    private func renderUserSnapshot() -> UIImage {
        let size = canvasSize == .zero ? CGSize(width: 300, height: 400) : canvasSize
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let ctx = UIGraphicsGetCurrentContext()!
            UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let segUIColors: [UIColor] = [.cyan, .yellow, .orange, .systemPink, .green, .systemMint, .purple, .red, .systemTeal, .systemIndigo]
            ctx.setLineCap(.round); ctx.setLineJoin(.round)
            for (idx, seg) in completedSegments.enumerated() {
                guard seg.count > 1 else { continue }
                let col = segUIColors[idx % segUIColors.count]
                ctx.beginPath(); ctx.setLineWidth(10)
                ctx.setStrokeColor(col.withAlphaComponent(0.28).cgColor)
                ctx.move(to: seg[0]); for pt in seg.dropFirst() { ctx.addLine(to: pt) }; ctx.strokePath()
                ctx.beginPath(); ctx.setLineWidth(3)
                ctx.setStrokeColor(col.withAlphaComponent(0.9).cgColor)
                ctx.move(to: seg[0]); for pt in seg.dropFirst() { ctx.addLine(to: pt) }; ctx.strokePath()
            }
            for star in stars {
                let r: CGFloat = star.isVisited ? 10 : 7
                let col: UIColor = star.isVisited ? .yellow : UIColor.white.withAlphaComponent(0.4)
                col.setFill()
                UIBezierPath(ovalIn: CGRect(x: star.position.x-r, y: star.position.y-r, width: r*2, height: r*2)).fill()
            }
        }
    }

    private func renderIdealSnapshot() -> UIImage {
        let size = canvasSize == .zero ? CGSize(width: 300, height: 400) : canvasSize
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let ctx = UIGraphicsGetCurrentContext()!
            UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setLineCap(.round); ctx.setLineJoin(.round)
            let ordered = stars.sorted { $0.orderIndex < $1.orderIndex }
            if ordered.count > 1 {
                for i in 0..<ordered.count - 1 {
                    let a = ordered[i].position, b = ordered[i+1].position
                    ctx.beginPath(); ctx.setLineWidth(10)
                    ctx.setStrokeColor(UIColor.yellow.withAlphaComponent(0.25).cgColor)
                    ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
                    ctx.beginPath(); ctx.setLineWidth(2.5); ctx.setLineDash(phase: 0, lengths: [8,5])
                    ctx.setStrokeColor(UIColor.yellow.withAlphaComponent(0.9).cgColor)
                    ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
                    ctx.setLineDash(phase: 0, lengths: [])
                }
            }
            for star in ordered {
                let pos = star.position
                UIColor.yellow.withAlphaComponent(0.20).setFill()
                UIBezierPath(ovalIn: CGRect(x: pos.x-16, y: pos.y-16, width: 32, height: 32)).fill()
                UIColor.yellow.setFill()
                UIBezierPath(ovalIn: CGRect(x: pos.x-9, y: pos.y-9, width: 18, height: 18)).fill()
                let label = "\(star.orderIndex + 1)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: UIColor.white]
                let sz = label.size(withAttributes: attrs)
                label.draw(at: CGPoint(x: pos.x - sz.width/2, y: pos.y + 14), withAttributes: attrs)
            }
        }
    }

    private func restartGame() {
        stopDisplayLink(); gameTimer?.invalidate()
        phase = .countdown; countdownVal = 3; score = 0; combo = 0; timeLeft = 75
        nextStarIndex = 0; completedSegments = []; currentSegment = []
        brushUnlocked = false; accuracy = 0; resultStarCount = 0
        userSnapshot = nil; idealSnapshot = nil
        shape = ConstellationShape.all.randomElement()!
        if canvasSize != .zero { buildStars(in: canvasSize) }
        runCountdown()
    }
}

// MARK: - ConstellationStarView
// Animated star node that pulses when it's the next target and glows when visited.

struct ConstellationStarView: View {
    let star:      ConstellationStar
    let isNext:    Bool
    let isVisited: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isNext {
                Circle().stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                    .frame(width: star.radius * 2 + 24, height: star.radius * 2 + 24)
                    .scaleEffect(pulse ? 1.35 : 1).opacity(pulse ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
            }
            Image(systemName: isVisited ? "star.fill" : (isNext ? "star.fill" : "star"))
                .font(.system(size: isNext ? 30 : (isVisited ? 24 : 18)))
                .foregroundStyle(isVisited ? .yellow : (isNext ? .yellow : .white.opacity(0.45)))
                .shadow(color: isVisited ? .yellow.opacity(0.9) : (isNext ? .yellow.opacity(0.7) : .clear), radius: 12)
                .scaleEffect(isVisited ? 1.25 : 1)
                .animation(.spring(duration: 0.35), value: isVisited)
            if !isVisited {
                Text("\(star.orderIndex + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(isNext ? 1.0 : 0.45)).offset(y: 22)
            }
        }
        .position(star.position)
        .onAppear { if isNext { pulse = true } }
        .onChange(of: isNext) { pulse = $0 }
    }
}

// MARK: - ConstellationResultView
// Results screen comparing the player's drawn path against the ideal shape.

struct ConstellationResultView: View {
    let shape:          ConstellationShape
    let score:          Int
    let accuracy:       Double
    let starsCollected: Int
    let totalStars:     Int
    let resultStarCount: Int
    let userSnapshot:   UIImage?
    let idealSnapshot:  UIImage?
    let isNewHighScore: Bool
    let onReplay:       () -> Void
    let onMenu:         () -> Void

    @State private var appeared  = false
    @State private var displayed = 0

    var grade: String {
        switch resultStarCount {
        case 3: return "PERFECT! ⭐"
        case 2: return "GREAT JOB! 🌟"
        case 1: return "NICE MOVE! ✨"
        default: return "YOU'VE GOT THIS! 💛"
        }
    }
    var gradeColor: Color {
        switch resultStarCount {
        case 3: return .yellow
        case 2: return .green
        case 1: return .cyan
        default: return .white.opacity(0.5)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.90).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text(grade).font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(gradeColor).shadow(color: gradeColor.opacity(0.7), radius: 14)
                    HStack(spacing: 10) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < resultStarCount ? "star.fill" : "star")
                                .font(.system(size: 26))
                                .foregroundStyle(i < resultStarCount ? .yellow : .white.opacity(0.2))
                                .shadow(color: i < resultStarCount ? .yellow.opacity(0.8) : .clear, radius: 8)
                                .scaleEffect(appeared && i < resultStarCount ? 1.2 : 1.0)
                                .animation(.spring(duration: 0.4).delay(Double(i) * 0.12 + 0.2), value: appeared)
                        }
                    }
                }
                .padding(.top, 48)
                .opacity(appeared ? 1 : 0).scaleEffect(appeared ? 1 : 0.7)
                .animation(.spring(duration: 0.5), value: appeared)

                Spacer().frame(height: 20)

                if isNewHighScore {
                    HighScoreBannerView().padding(.horizontal, 20)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    Spacer().frame(height: 6)
                }

                VStack(spacing: 8) {
                    Text("YOUR PATH  vs  PERFECT SHAPE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4)).tracking(2)
                    HStack(spacing: 10) {
                        VStack(spacing: 6) {
                            Text("You drew").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                            snapshotImage(userSnapshot, fallbackColor: .cyan)
                        }
                        VStack(spacing: 6) {
                            Text("Ideal").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                            snapshotImage(idealSnapshot, fallbackColor: .yellow)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                Spacer().frame(height: 18)

                HStack(spacing: 10) {
                    resultStatBox(label: "SCORE",    value: "\(displayed)",               unit: "pts", color: .yellow)
                    resultStatBox(label: "STARS",    value: "\(starsCollected)/\(totalStars)", unit: "★", color: .cyan)
                    resultStatBox(label: "ACCURACY", value: "\(Int(accuracy * 100))",     unit: "%",   color: .green)
                }
                .padding(.horizontal, 16)
                .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

                Spacer().frame(height: 18)

                VStack(spacing: 10) {
                    Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onReplay() }) {
                        HStack(spacing: 8) { Image(systemName: "arrow.clockwise"); Text("New Constellation") }
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(.yellow, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button("Main Menu") { onMenu() }
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.42), value: appeared)

                Spacer().frame(height: 32)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 1.2)) { displayed = score }
            }
        }
    }

    @ViewBuilder
    private func snapshotImage(_ img: UIImage?, fallbackColor: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.04, green: 0.04, blue: 0.10))
            if let img = img { Image(uiImage: img).resizable().scaledToFit() }
            else { Text("…").foregroundStyle(.white.opacity(0.3)) }
        }
        .frame(width: 160, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(fallbackColor.opacity(0.35), lineWidth: 1.5))
    }

    @ViewBuilder
    private func resultStatBox(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35)).tracking(2)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 22, weight: .light, design: .monospaced))
                    .foregroundStyle(color).contentTransition(.numericText())
                Text(unit).font(.system(size: 11, design: .monospaced)).foregroundStyle(color.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
