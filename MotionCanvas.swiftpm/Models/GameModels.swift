import SwiftUI

// MARK: - GameMode


enum GameMode: String, CaseIterable, Hashable {
    case freeCanvas    = "Free Canvas"
    case constellation = "Constellation"
    case colorFill     = "Color Fill"

    var icon: String {
        switch self {
        case .freeCanvas:    return "paintbrush.pointed.fill"
        case .constellation: return "star.fill"
        case .colorFill:     return "drop.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .freeCanvas:    return "Your phone is the brush"
        case .constellation: return "Trace the hidden stars"
        case .colorFill:     return "Fill the shape perfectly"
        }
    }

    var objective: String {
        switch self {
        case .freeCanvas:    return "Express yourself freely — paint, sketch, spray."
        case .constellation: return "Tilt through stars in order to reveal a hidden constellation. Score on how accurately you trace it!"
        case .colorFill:     return "Tilt your phone to spray paint inside the shape. Score on coverage — stay inside the lines for a bonus!"
        }
    }

    var accentColor: Color {
        switch self {
        case .freeCanvas:    return .cyan
        case .constellation: return .yellow
        case .colorFill:     return Color(red: 1.0, green: 0.45, blue: 0.55)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .freeCanvas:    return [.cyan, .blue]
        case .constellation: return [.yellow, .orange]
        case .colorFill:     return [Color(red: 1.0, green: 0.45, blue: 0.55), .purple]
        }
    }
}

// MARK: - BrushType
// Available brush styles for the Free Canvas mode.

enum BrushType: String, CaseIterable {
    case pen   = "Pen"
    case neon  = "Neon"
    case spray = "Spray"
    case water = "Watercolour"
    case chalk = "Chalk"

    var icon: String {
        switch self {
        case .pen:   return "pencil"
        case .neon:  return "wand.and.stars"
        case .spray: return "aqi.medium"
        case .water: return "drop"
        case .chalk: return "scribble.variable"
        }
    }
}

// MARK: - StrokePoint
// A single point in a brush stroke (used by Free Canvas).

struct StrokePoint: Identifiable {
    let id        = UUID()
    var position:  CGPoint
    var color:     Color
    var size:      CGFloat
    var opacity:   Double
    var blur:      CGFloat
    var timestamp: Date = Date()
}

// MARK: - Stroke
// A connected path of points forming one continuous brush stroke.

struct Stroke: Identifiable {
    let id = UUID()
    var points:    [CGPoint]
    let color:     Color
    let lineWidth: CGFloat
    let opacity:   Double
    let brushType: BrushType
}

// MARK: - PaintStroke
// Stroke model used specifically by the Color Fill mode.

struct PaintStroke: Identifiable {
    let id = UUID()
    var points:  [CGPoint]
    let color:   Color
    let width:   CGFloat
    let opacity: Double
}

// MARK: - ConstellationStar
// Represents one star node in the Constellation game.

struct ConstellationStar: Identifiable {
    let id         = UUID()
    var position:  CGPoint
    var orderIndex: Int
    var isVisited: Bool    = false
    var visitTime: Date?   = nil
    var radius:    CGFloat = 38
    var pulsePhase: Double = 0
}

// MARK: - ConstellationShape
// A named shape made of stars, with ideal connections between them.

struct ConstellationShape {
    let name:             String
    let emoji:            String
    let normalizedPoints: [CGPoint]   // unit fractions (0–1), converted at runtime
    let connections:      [(Int, Int)] // index pairs for the guide lines

    static let all: [ConstellationShape] = [
        ConstellationShape(
            name: "Triangle", emoji: "🔺",
            normalizedPoints: [
                CGPoint(x: 0.50, y: 0.12),
                CGPoint(x: 0.88, y: 0.82),
                CGPoint(x: 0.12, y: 0.82),
            ],
            connections: [(0,1),(1,2),(2,0)]
        ),
        ConstellationShape(
            name: "Diamond", emoji: "💎",
            normalizedPoints: [
                CGPoint(x: 0.50, y: 0.10),
                CGPoint(x: 0.88, y: 0.50),
                CGPoint(x: 0.50, y: 0.88),
                CGPoint(x: 0.12, y: 0.50),
            ],
            connections: [(0,1),(1,2),(2,3),(3,0)]
        ),
        ConstellationShape(
            name: "Lightning", emoji: "⚡",
            normalizedPoints: [
                CGPoint(x: 0.15, y: 0.12),
                CGPoint(x: 0.85, y: 0.12),
                CGPoint(x: 0.15, y: 0.88),
                CGPoint(x: 0.85, y: 0.88),
            ],
            connections: [(0,1),(1,2),(2,3)]
        ),
        ConstellationShape(
            name: "House", emoji: "🏠",
            normalizedPoints: [
                CGPoint(x: 0.50, y: 0.10),
                CGPoint(x: 0.85, y: 0.45),
                CGPoint(x: 0.85, y: 0.88),
                CGPoint(x: 0.15, y: 0.88),
                CGPoint(x: 0.15, y: 0.45),
            ],
            connections: [(0,1),(1,2),(2,3),(3,4),(4,0)]
        ),
        ConstellationShape(
            name: "Cross", emoji: "✚",
            normalizedPoints: [
                CGPoint(x: 0.50, y: 0.10),
                CGPoint(x: 0.88, y: 0.50),
                CGPoint(x: 0.50, y: 0.88),
                CGPoint(x: 0.12, y: 0.50),
            ],
            connections: [(0,1),(1,2),(2,3),(3,0),(0,2),(1,3)]
        ),
        ConstellationShape(
            name: "Pentagon", emoji: "⬠",
            normalizedPoints: [
                CGPoint(x: 0.50, y: 0.10),
                CGPoint(x: 0.88, y: 0.38),
                CGPoint(x: 0.74, y: 0.85),
                CGPoint(x: 0.26, y: 0.85),
                CGPoint(x: 0.12, y: 0.38),
            ],
            connections: [(0,1),(1,2),(2,3),(3,4),(4,0)]
        ),
    ]
}

// MARK: - FillShape
// A named shape used in the Color Fill mode, defined by a path closure.

struct FillShape: @unchecked Sendable {
    let name:  String
    let emoji: String
    let path:  (CGSize) -> Path

    static let all: [FillShape] = [
        FillShape(name: "Circle", emoji: "⭕") { size in
            let r = min(size.width, size.height) * 0.36
            return Path(ellipseIn: CGRect(
                x: size.width / 2 - r,
                y: size.height / 2 - r,
                width: r * 2, height: r * 2))
        },
        FillShape(name: "Star", emoji: "⭐") { size in
            starPath(center: CGPoint(x: size.width/2, y: size.height/2),
                     outerRadius: min(size.width, size.height) * 0.38,
                     innerRadius: min(size.width, size.height) * 0.16,
                     points: 5)
        },
        FillShape(name: "Heart", emoji: "❤️") { size in
            heartPath(in: CGRect(
                x: size.width * 0.15, y: size.height * 0.22,
                width: size.width * 0.70, height: size.height * 0.56))
        },
        FillShape(name: "Triangle", emoji: "🔺") { size in
            var p = Path()
            p.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.18))
            p.addLine(to: CGPoint(x: size.width * 0.85, y: size.height * 0.78))
            p.addLine(to: CGPoint(x: size.width * 0.15, y: size.height * 0.78))
            p.closeSubpath()
            return p
        },
        FillShape(name: "Flower", emoji: "🌸") { size in
            flowerPath(center: CGPoint(x: size.width/2, y: size.height/2),
                       petalRadius: min(size.width, size.height) * 0.20,
                       petalCount: 6)
        },
    ]
}

// MARK: - Path Helpers

func starPath(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int) -> Path {
    var path = Path()
    let angleStep = CGFloat.pi / CGFloat(points)
    for i in 0..<(points * 2) {
        let r = i % 2 == 0 ? outerRadius : innerRadius
        let angle = CGFloat(i) * angleStep - CGFloat.pi / 2
        let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
    }
    path.closeSubpath()
    return path
}

func heartPath(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
    path.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.9))
    path.addCurve(to: CGPoint(x: x, y: y + h * 0.35),
                  control1: CGPoint(x: x + w * 0.1, y: y + h * 0.75),
                  control2: CGPoint(x: x, y: y + h * 0.6))
    path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.2),
                  control1: CGPoint(x: x, y: y),
                  control2: CGPoint(x: x + w * 0.5, y: y + h * 0.15))
    path.addCurve(to: CGPoint(x: x + w, y: y + h * 0.35),
                  control1: CGPoint(x: x + w * 0.5, y: y + h * 0.15),
                  control2: CGPoint(x: x + w, y: y))
    path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.9),
                  control1: CGPoint(x: x + w, y: y + h * 0.6),
                  control2: CGPoint(x: x + w * 0.9, y: y + h * 0.75))
    path.closeSubpath()
    return path
}

func flowerPath(center: CGPoint, petalRadius: CGFloat, petalCount: Int) -> Path {
    var path = Path()
    for i in 0..<petalCount {
        let angle = CGFloat(i) * (2 * CGFloat.pi / CGFloat(petalCount))
        let petalCenter = CGPoint(
            x: center.x + petalRadius * cos(angle),
            y: center.y + petalRadius * sin(angle))
        path.addEllipse(in: CGRect(
            x: petalCenter.x - petalRadius * 0.7,
            y: petalCenter.y - petalRadius * 0.7,
            width: petalRadius * 1.4,
            height: petalRadius * 1.4))
    }
    path.addEllipse(in: CGRect(
        x: center.x - petalRadius * 0.5,
        y: center.y - petalRadius * 0.5,
        width: petalRadius, height: petalRadius))
    return path
}
