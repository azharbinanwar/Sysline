import SwiftUI

// Glowing near-full-circle speed gauge (gap at bottom) — teal→blue arc + needle.
// Geometry mirrors the design reference: 290° sweep, marks 0…100.
struct LogDial: View {
    var value: Double         // Mbps
    var size: CGFloat = 300

    private static let marks: [Double] = [0, 5, 10, 15, 20, 30, 50, 75, 100]
    private static let teal = Color(red: 0.25, green: 0.878, blue: 0.816) // #40e0d0

    // piecewise so the printed marks sit at equal arc spacing
    static func fraction(_ v: Double) -> Double {
        if v <= 0 { return 0 }
        if v >= 100 { return 1 }
        for i in 1..<marks.count where v <= marks[i] {
            let f0 = Double(i - 1) / 8, f1 = Double(i) / 8
            let t = (v - marks[i - 1]) / (marks[i] - marks[i - 1])
            return f0 + t * (f1 - f0)
        }
        return 1
    }

    private var lineW: CGFloat { size * 0.06 }
    private var radius: CGFloat { size * 0.4 }
    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }
    private var frac: Double { LogDial.fraction(value) }

    // arc spans 124°→414° clockwise (y-down), leaving a gap centred on the bottom
    private func angle(_ f: Double) -> Double { (124 + f * 290) * .pi / 180 }
    private func point(_ f: Double, _ r: CGFloat) -> CGPoint {
        let a = angle(f)
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }
    private var arc: Path {
        var p = Path()
        for i in 0...180 {
            let pt = point(Double(i) / 180, radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    var body: some View {
        ZStack {
            arc.stroke(Color.primary.opacity(0.1), style: .init(lineWidth: lineW, lineCap: .round))

            arc.trimmedPath(from: 0, to: frac)
                .stroke(LinearGradient(colors: [Theme.down, Self.teal],
                                       startPoint: .bottomLeading, endPoint: .topTrailing),
                        style: .init(lineWidth: lineW, lineCap: .round))
                .shadow(color: Self.teal.opacity(0.6), radius: size * 0.033)
                .animation(.easeOut(duration: 0.3), value: frac)

            ForEach(Array(Self.marks.enumerated()), id: \.offset) { i, m in
                Text("\(Int(m))")
                    .font(.system(size: size * 0.047, weight: .medium))
                    .foregroundStyle(.secondary)
                    .position(point(Double(i) / 8, radius + size * 0.075))
            }

            Canvas { ctx, _ in
                let tip = point(frac, radius - lineW * 1.4)
                var n = Path(); n.move(to: center); n.addLine(to: tip)
                ctx.stroke(n, with: .color(Self.teal), style: .init(lineWidth: size * 0.02, lineCap: .round))
            }
            .shadow(color: Self.teal.opacity(0.8), radius: size * 0.02)
            .animation(.easeOut(duration: 0.15), value: frac)

            Circle().fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: size * 0.073, height: size * 0.073)
                .overlay(Circle().stroke(.primary.opacity(0.25), lineWidth: 2))
        }
        .frame(width: size, height: size)
    }
}
