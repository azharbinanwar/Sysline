import SwiftUI

// 270° arc dial with a centered readout — used in the test sheet.
struct SpeedDial: View {
    var value: Double
    var maxValue: Double = 200
    var color: Color
    var label: String

    private var fraction: Double { min(value / maxValue, 1) }

    var body: some View {
        ZStack {
            ArcShape().stroke(Color.primary.opacity(0.10),
                              style: StrokeStyle(lineWidth: 13, lineCap: .round))
            ArcShape().trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .animation(.easeOut(duration: 1.3), value: fraction)

            VStack(spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 40, weight: .bold)).monospacedDigit()
                Text("Mbps").font(.system(size: 11)).foregroundStyle(.secondary)
                Text(label).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color).textCase(.uppercase)
                    .padding(.top, 4)
            }
            .padding(.top, 20)
        }
    }
}

private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2 - 8
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(135), endAngle: .degrees(45), clockwise: false)
        return p
    }
}
