import SwiftUI
import UIKit

// MARK: - FreeCanvasView


struct FreeCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = MotionManager()
    @StateObject private var canvas = CanvasModel()

    @State private var brushType:      BrushType = .pen
    @State private var brushSize:      CGFloat   = 10
    @State private var chosenColor:    Color     = .cyan
    @State private var opacity:        Double    = 0.85
    @State private var isEraser:       Bool      = false
    @State private var showColorPicker = false
    @State private var showBrushPicker = false
    @State private var canvasSize      = CGSize.zero
    @State private var phase:          GamePhase = .intro
    @State private var showToolbar     = true
    @State private var toolbarTimer:   Timer?    = nil
    @State private var lastPos:        CGPoint   = .zero
    @State private var strokeActive    = false

    enum GamePhase { case intro, playing }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if phase == .playing {
                CanvasView(model: canvas, size: $canvasSize)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { toggleToolbar() }

                if !showColorPicker && !showBrushPicker { brushCursor }

                if showToolbar {
                    VStack { topBar; Spacer(); bottomToolbar }
                        .allowsHitTesting(true)
                }

                if showColorPicker {
                    ColorPickerOverlay(selected: $chosenColor) {
                        showColorPicker = false; endCurrentStroke(); resetToolbarTimer()
                    }
                }
                if showBrushPicker {
                    BrushPickerOverlay(selected: $brushType, size: $brushSize, opacity: $opacity) {
                        showBrushPicker = false; endCurrentStroke(); resetToolbarTimer()
                    }
                }
            }

            if phase == .intro { introView }
        }
        .navigationBarHidden(true)
        .onAppear { motion.startUpdates() }
        .onDisappear { endCurrentStroke(); motion.stopUpdates(); toolbarTimer?.invalidate() }
        .onChange(of: motion.smoothPitch) { _ in if phase == .playing { paintTick() } }
        .onChange(of: motion.smoothRoll)  { _ in if phase == .playing { paintTick() } }
        .onChange(of: motion.shakeIntensity) { v in
            if v > 2.0 && phase == .playing { shakeUndo() }
        }
    }

    // MARK: - Intro screen

    private var introView: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("FREE CANVAS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4)).tracking(6)
                Text("🎨").font(.system(size: 72))
                Text("Paint freely")
                    .font(.system(size: 30, weight: .thin, design: .rounded)).foregroundStyle(.white)

                VStack(spacing: 10) {
                    introRow(icon: "iphone.gen3.radiowaves.left.and.right", text: "Tilt your phone to move the brush")
                    introRow(icon: "hand.tap",            text: "Tap canvas to show / hide toolbar")
                    introRow(icon: "paintbrush",          text: "Choose brush type, size & colour")
                    introRow(icon: "arrow.uturn.backward",text: "Shake to undo last stroke")
                    introRow(icon: "square.and.arrow.up", text: "Share your artwork when done")
                }
                .padding(.horizontal, 28)

                Button {
                    withAnimation(.easeIn(duration: 0.3)) { phase = .playing }
                    resetToolbarTimer()
                } label: {
                    Text("START PAINTING")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 28).padding(.top, 8)

                Button("Go Back") { dismiss() }
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.35))
            }
            .padding(.vertical, 40)
        }
    }

    private func introRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16)).foregroundStyle(.white.opacity(0.6)).frame(width: 26)
            Text(text).font(.system(size: 14, weight: .light)).foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
    }

    // MARK: - Brush cursor

    private var brushCursor: some View {
        let pos = brushPos
        let col = isEraser ? Color.white : chosenColor
        return ZStack {
            if isEraser {
                Circle().stroke(.white.opacity(0.6), lineWidth: 2)
                    .frame(width: brushSize * 3, height: brushSize * 3)
            } else {
                Circle().fill(col.opacity(0.2))
                    .frame(width: brushSize * 3.5, height: brushSize * 3.5)
                    .blur(radius: brushSize * 0.5)
                Circle().fill(col).frame(width: brushSize, height: brushSize)
            }
        }
        .position(pos).allowsHitTesting(false)
    }

    private var brushPos: CGPoint {
        guard canvasSize != .zero else {
            let s = UIScreen.main.bounds
            return CGPoint(x: s.width / 2, y: s.height / 2)
        }
        return CGPoint(
            x: canvasSize.width  / 2 + CGFloat(motion.smoothRoll)  * canvasSize.width  * 0.42,
            y: canvasSize.height / 2 + CGFloat(motion.smoothPitch) * canvasSize.height * 0.36)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7)).frame(width: 40, height: 40)
                    .background(.black.opacity(0.55), in: Circle())
            }
            Spacer()
            Text("FREE CANVAS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4)).tracking(4)
            Spacer()
            Button { undoLast() } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canvas.strokes.isEmpty ? .white.opacity(0.2) : .white.opacity(0.7))
                    .frame(width: 40, height: 40).background(.black.opacity(0.55), in: Circle())
            }
            .disabled(canvas.strokes.isEmpty)
            Button {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                endCurrentStroke(); canvas.clear()
            } label: {
                Image(systemName: "trash").font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6)).frame(width: 40, height: 40)
                    .background(.black.opacity(0.55), in: Circle())
            }
            Button { shareCanvas() } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6)).frame(width: 40, height: 40)
                    .background(.black.opacity(0.55), in: Circle())
            }
        }
        .padding(.horizontal, 14).padding(.top, 56)
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 10) {
            if canvas.strokes.isEmpty && canvas.currentStroke == nil {
                Text("Tilt to paint  •  Shake to undo")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(0.35)).transition(.opacity)
            }
            HStack(spacing: 12) {
                Button {
                    endCurrentStroke(); showColorPicker = true
                } label: {
                    ZStack {
                        Circle().fill(chosenColor).frame(width: 38, height: 38)
                        Circle().stroke(.white.opacity(0.4), lineWidth: 1.5).frame(width: 38, height: 38)
                    }
                }
                Button {
                    endCurrentStroke(); showBrushPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: brushType.icon).font(.system(size: 14))
                        Text(brushType.rawValue).font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                }
                Button {
                    isEraser.toggle(); endCurrentStroke()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eraser.fill").font(.system(size: 14))
                        Text(isEraser ? "Eraser ON" : "Eraser").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(isEraser ? .black : .white.opacity(0.85))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(isEraser ? .white : .white.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 46)
    }

    // MARK: - Paint logic

    private func endCurrentStroke() {
        canvas.endStroke(); strokeActive = false
    }

    private func paintTick() {
        guard canvasSize != .zero, phase == .playing else { return }
        guard !showColorPicker, !showBrushPicker else { return }
        let pos = brushPos
        if isEraser { canvas.eraseNear(pos, radius: brushSize * 2.5); strokeActive = false; return }
        if !strokeActive {
            canvas.beginStroke(at: pos, color: chosenColor, lineWidth: brushSize, opacity: opacity, brushType: brushType)
            strokeActive = true; lastPos = pos; return
        }
        let moved = hypot(pos.x - lastPos.x, pos.y - lastPos.y)
        guard moved > 1.5 else { return }
        canvas.continueStroke(to: pos); lastPos = pos; resetToolbarTimer()
    }

    private func shakeUndo() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); undoLast()
    }

    private func undoLast() {
        guard !canvas.strokes.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        endCurrentStroke(); canvas.strokes.removeLast()
    }

    private func toggleToolbar() {
        withAnimation(.easeInOut(duration: 0.25)) { showToolbar.toggle() }
        if showToolbar { resetToolbarTimer() }
    }

    private func resetToolbarTimer() {
        toolbarTimer?.invalidate()
        toolbarTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { _ in
            if !showColorPicker && !showBrushPicker {
                withAnimation(.easeOut(duration: 0.4)) { showToolbar = false }
            }
        }
    }

    private func shareCanvas() {
        endCurrentStroke()
        let img = canvas.snapshot(size: canvasSize) ?? UIImage()
        let av  = UIActivityViewController(activityItems: [img], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root  = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - ColorPickerOverlay
// Full-screen overlay for selecting a brush colour (presets + system picker).

struct ColorPickerOverlay: View {
    @Binding var selected: Color
    let onClose: () -> Void

    let presets: [Color] = [
        .white, .red, .orange, .yellow, .green, .mint, .cyan,
        .blue, .indigo, .purple, .pink,
        Color(red: 1, green: 0.4, blue: 0),
        Color(red: 0, green: 1, blue: 0.6),
        Color(red: 1, green: 0, blue: 0.8),
        Color(red: 0.2, green: 0.6, blue: 1),
        Color(red: 1, green: 0.9, blue: 0.4),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 20) {
                Text("CHOOSE COLOUR")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5)).tracking(5)
                ColorPicker("", selection: $selected, supportsOpacity: false)
                    .labelsHidden().scaleEffect(1.6).frame(width: 60, height: 60)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 8), spacing: 10) {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, color in
                        Button { selected = color; onClose() } label: {
                            Circle().fill(color).frame(width: 34, height: 34)
                                .overlay(Circle().stroke(.white.opacity(selected == color ? 0.9 : 0.2), lineWidth: 2))
                                .shadow(color: color.opacity(0.5), radius: 4)
                        }
                    }
                }
                Button { onClose() } label: {
                    Text("Done").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(selected, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(24).background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - BrushPickerOverlay
// Full-screen overlay for selecting brush type, size, and opacity.

struct BrushPickerOverlay: View {
    @Binding var selected: BrushType
    @Binding var size:     CGFloat
    @Binding var opacity:  Double
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 18) {
                Text("BRUSH TYPE")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5)).tracking(5)
                VStack(spacing: 8) {
                    ForEach(BrushType.allCases, id: \.self) { brush in
                        Button { selected = brush } label: {
                            HStack(spacing: 14) {
                                Image(systemName: brush.icon).font(.system(size: 18))
                                    .foregroundStyle(selected == brush ? .black : .white.opacity(0.7)).frame(width: 24)
                                Text(brush.rawValue)
                                    .font(.system(size: 16, weight: selected == brush ? .semibold : .regular))
                                    .foregroundStyle(selected == brush ? .black : .white.opacity(0.8))
                                Spacer()
                                if selected == brush {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(selected == brush ? .white : .white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Size").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(size))").font(.system(size: 13, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    }
                    Slider(value: $size, in: 3...40, step: 1).accentColor(.cyan)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Opacity").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(opacity * 100))%").font(.system(size: 13, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    }
                    Slider(value: $opacity, in: 0.1...1.0).accentColor(.cyan)
                }
                Button { onClose() } label: {
                    Text("Done").font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(24).background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 20)
        }
    }
}
