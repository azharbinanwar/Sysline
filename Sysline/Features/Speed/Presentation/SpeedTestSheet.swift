import Combine
import SwiftUI

// The speed test sheet — a modern speedometer: 250° arc with real tick marks
// on a log scale (0…1000), a glowing needle in the phase color, and a peak
// notch that remembers the fastest moment of the phase. Stat row + ratings
// below, familiar layout otherwise.
struct SpeedTestSheet: View {
    @Environment(\.dismiss) private var dismiss
    let network: String
    let onComplete: () -> Void

    @StateObject private var tester = SpeedTester()
    @State private var ip: IPInfo.Result?
    @AppStorage("theme") private var theme = 0
    @State private var peak = 0.0

    var body: some View {
        VStack(spacing: 12) {
            Text(phaseText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            SpeedGauge(value: liveValue, display: displayValue, peak: peak,
                       color: phaseColor, done: tester.phase == .done, size: 240)

            statsRow

            if tester.phase == .done {
                RatingTiles(ratings: SpeedRating.all(down: tester.downMbps, up: tester.upMbps, ping: tester.idlePing))
            }

            if let note = tester.note {
                Label(note, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }

            footer
            controls
        }
        .padding(24)
        .frame(width: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(Theme.colorScheme(theme))
        .onAppear { start() }
        .task { ip = await IPInfo.fetch() }
        .onChange(of: tester.mbps) { peak = max(peak, tester.mbps) }
        .onChange(of: tester.phase) { if tester.phase == .upload { peak = 0 } }
    }

    // 0 outside the active phases so the needle glides back to rest when done.
    private var liveValue: Double {
        switch tester.phase {
        case .download, .upload: tester.mbps
        default: 0
        }
    }

    // The middle number keeps the download result after the needle rests.
    private var displayValue: Double {
        tester.phase == .done ? tester.downMbps : liveValue
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(String(format: "%.1f", tester.downMbps), "Download", Theme.down,
                 live: tester.phase == .download)
            divider
            stat(String(format: "%.1f", tester.upMbps), "Upload", Theme.up,
                 live: tester.phase == .upload)
            divider
            stat(tester.idlePing > 0 ? "\(tester.idlePing)" : "—", "Ping ms", .orange, live: false)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 30)
    }

    private func stat(_ value: String, _ label: String, _ color: Color, live: Bool) -> some View {
        VStack(spacing: 2) {
            Text(live ? "…" : value)
                .font(.system(size: 20, weight: .semibold)).monospacedDigit()
                .foregroundStyle(color)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Label(ip?.isp.isEmpty == false ? ip!.isp : network, systemImage: "wifi")
            if let place = ip?.place, !place.isEmpty {
                Label(place, systemImage: "location.fill")
            }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
    }

    @ViewBuilder private var controls: some View {
        if tester.phase == .done {
            HStack(spacing: 8) {
                Button("Test Again") { start() }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        } else {
            Button("Cancel") { dismiss() }.controlSize(.large)
        }
    }

    private func start() {
        peak = 0
        Task {
            await tester.run()
            onComplete()
        }
    }

    private var phaseColor: Color {
        switch tester.phase {
        case .upload: Theme.up
        case .done: Theme.down
        default: Theme.down
        }
    }

    private var phaseText: String {
        switch tester.phase {
        case .idle: "Starting…"
        case .ping: "Measuring latency…"
        case .download: "Testing download…"
        case .upload: "Testing upload…"
        case .done: "Test complete"
        }
    }
}

// The speedometer itself: track + minor/major ticks + value arc + needle +
// peak notch, log-scaled so slow speeds get most of the sweep.
struct SpeedGauge: View {
    var value: Double        // Mbps, drives the needle (0 = at rest)
    var display: Double      // Mbps, the number shown in the middle
    var peak: Double         // Mbps, highest seen this phase
    var color: Color
    var done: Bool
    var size: CGFloat

    private static let marks: [Double] = [0, 1, 5, 10, 25, 50, 100, 250, 500, 1000]
    private static let startDeg = 145.0, sweepDeg = 250.0

    static func fraction(_ value: Double) -> Double {
        let segments = Double(marks.count - 1)
        if value <= 0 { return 0 }
        if value >= marks.last! { return 1 }
        for i in 1..<marks.count where value <= marks[i] {
            let f0 = Double(i - 1) / segments, f1 = Double(i) / segments
            let t = (value - marks[i - 1]) / (marks[i] - marks[i - 1])
            return f0 + t * (f1 - f0)
        }
        return 1
    }

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2 + size * 0.04)
            let radius = size * 0.38
            let track = size * 0.045

            func angle(_ f: Double) -> Double { (Self.startDeg + f * Self.sweepDeg) * .pi / 180 }
            func point(_ f: Double, _ r: CGFloat) -> CGPoint {
                CGPoint(x: center.x + r * cos(angle(f)), y: center.y + r * sin(angle(f)))
            }
            func arc(_ from: Double, _ to: Double, _ r: CGFloat) -> Path {
                var p = Path()
                p.addArc(center: center, radius: r,
                         startAngle: .radians(angle(from)), endAngle: .radians(angle(to)),
                         clockwise: false)
                return p
            }

            // track
            context.stroke(arc(0, 1, radius), with: .color(.primary.opacity(0.08)),
                           style: StrokeStyle(lineWidth: track, lineCap: .round))

            // minor ticks (2 between each mark), major ticks + labels at marks
            let segments = Self.marks.count - 1
            for i in 0...(segments * 3) {
                let f = Double(i) / Double(segments * 3)
                let isMajor = i % 3 == 0
                let outer = radius + track * 0.9
                let inner = outer - (isMajor ? size * 0.032 : size * 0.016)
                var tick = Path()
                tick.move(to: point(f, inner))
                tick.addLine(to: point(f, outer))
                context.stroke(tick, with: .color(.primary.opacity(isMajor ? 0.35 : 0.15)),
                               lineWidth: isMajor ? 1.6 : 1)
                if isMajor {
                    let mark = Self.marks[i / 3]
                    context.draw(
                        Text("\(Int(mark))")
                            .font(.system(size: size * 0.042, weight: .medium))
                            .foregroundStyle(.secondary),
                        at: point(f, radius + size * 0.085))
                }
            }

            let f = Self.fraction(value)

            // value arc with soft glow
            if f > 0 {
                var glow = context
                glow.addFilter(.blur(radius: size * 0.02))
                glow.stroke(arc(0, f, radius), with: .color(color.opacity(0.55)),
                            style: StrokeStyle(lineWidth: track, lineCap: .round))
                context.stroke(arc(0, f, radius), with: .color(color),
                               style: StrokeStyle(lineWidth: track, lineCap: .round))
            }

            // peak notch — remembers the fastest moment of this phase
            let peakF = Self.fraction(peak)
            if peakF > f + 0.005, !done {
                var notch = Path()
                notch.move(to: point(peakF, radius - track * 0.8))
                notch.addLine(to: point(peakF, radius + track * 0.8))
                context.stroke(notch, with: .color(color.opacity(0.6)), lineWidth: 2)
            }

            // needle: slim, phase-colored, round hub
            let needleTip = point(f, radius - track * 1.6)
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: needleTip)
            context.stroke(needle, with: .color(color),
                           style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round))
            let hub = size * 0.05
            context.fill(Path(ellipseIn: CGRect(x: center.x - hub / 2, y: center.y - hub / 2,
                                                width: hub, height: hub)),
                         with: .color(color))
            context.fill(Path(ellipseIn: CGRect(x: center.x - hub / 4, y: center.y - hub / 4,
                                                width: hub / 2, height: hub / 2)),
                         with: .color(Color(nsColor: .windowBackgroundColor)))
        }
        .frame(width: size, height: size * 0.78)
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Text(String(format: "%.1f", display))
                    .font(.system(size: size * 0.16, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText())
                Text("Mbps").font(.system(size: size * 0.055)).foregroundStyle(.secondary)
            }
            .offset(y: -size * 0.01)
        }
        .animation(.easeOut(duration: 0.25), value: value)
    }
}
