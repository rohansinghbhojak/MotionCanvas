import SwiftUI
import UIKit

// MARK: - CanvasModel


class CanvasModel: ObservableObject {
    @Published var strokes:       [Stroke] = []
    @Published var currentStroke: Stroke?  = nil

    // MARK: - Stroke lifecycle

    func beginStroke(at point: CGPoint, color: Color, lineWidth: CGFloat,
                     opacity: Double, brushType: BrushType) {
        currentStroke = Stroke(points: [point], color: color,
                               lineWidth: lineWidth, opacity: opacity,
                               brushType: brushType)
    }

    func continueStroke(to point: CGPoint) {
        guard currentStroke != nil else { return }
        currentStroke!.points.append(point)
    }

    func endStroke() {
        if let s = currentStroke, s.points.count > 1 { strokes.append(s) }
        currentStroke = nil
    }

    // MARK: - Edit operations

    func eraseNear(_ center: CGPoint, radius: CGFloat) {
        strokes.removeAll { stroke in
            stroke.points.contains { pt in
                hypot(pt.x - center.x, pt.y - center.y) < radius
            }
        }
        currentStroke?.points.removeAll { pt in
            hypot(pt.x - center.x, pt.y - center.y) < radius
        }
    }

    func clear() {
        strokes       = []
        currentStroke = nil
    }

    // MARK: - Snapshot

    func snapshot(size: CGSize) -> UIImage? {
        guard size != .zero else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let ctx = UIGraphicsGetCurrentContext()!
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for stroke in strokes { drawStroke(stroke, in: ctx) }
            if let live = currentStroke { drawStroke(live, in: ctx) }
        }
    }

    private func drawStroke(_ stroke: Stroke, in ctx: CGContext) {
        guard stroke.points.count > 1 else { return }
        ctx.beginPath()
        ctx.setLineWidth(stroke.lineWidth)
        ctx.setStrokeColor(UIColor(stroke.color).withAlphaComponent(stroke.opacity).cgColor)
        ctx.move(to: stroke.points[0])
        for pt in stroke.points.dropFirst() { ctx.addLine(to: pt) }
        ctx.strokePath()
    }
}
