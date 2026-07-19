import SwiftUI

struct SpeedTestSheet: View {
    @Environment(\.dismiss) private var dismiss
    let network: String
    let onComplete: () -> Void

    @StateObject private var tester = SpeedTester()
    @State private var ip: IPInfo.Result?
    @AppStorage("theme") private var theme = 0

    private var liveValue: Double {
        switch tester.phase {
        case .download, .upload: return tester.mbps
        default: return 0                            // idle / ping / done rest at zero
        }
    }

    private var phaseText: String {
        switch tester.phase {
        case .idle: return "Starting…"
        case .ping: return "Measuring latency…"
        case .download: return "Testing download…"
        case .upload: return "Testing upload…"
        case .done: return "Test complete"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            Text(phaseText).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)

            LogDial(value: liveValue, size: 210)

            latencies

            RatingTiles(ratings: SpeedRating.all(down: tester.downMbps, up: tester.upMbps, ping: tester.idlePing))

            if let note = tester.note {
                Label(note, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }

            footer
            controls
        }
        .padding(24)
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(Theme.colorScheme(theme))
        .onAppear { start() }
        .task { ip = await IPInfo.fetch() }
    }

    private var header: some View {
        HStack(spacing: 30) {
            metricTop("arrow.down", "DOWNLOAD",
                      tester.phase == .download ? tester.mbps : tester.downMbps,
                      Theme.down, active: tester.phase == .download)
            metricTop("arrow.up", "UPLOAD",
                      tester.phase == .upload ? tester.mbps : tester.upMbps,
                      Theme.up, active: tester.phase == .upload)
        }
    }

    private func metricTop(_ icon: String, _ label: String, _ v: Double, _ c: Color, active: Bool) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(c)
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            }
            Text(v > 0 ? String(format: "%.1f", v) : "—")
                .font(.system(size: 26, weight: .bold)).monospacedDigit()
                .foregroundStyle(active ? c : .primary)
                .contentTransition(.numericText())
        }
    }

    private var latencies: some View {
        HStack(spacing: 20) {
            lat("bolt.fill", "\(tester.idlePing)", .orange)
            lat("arrow.down", tester.downLatency > 0 ? "\(tester.downLatency)" : "—", Theme.down)
            lat("arrow.up", tester.upLatency > 0 ? "\(tester.upLatency)" : "—", Theme.up)
        }
        .font(.system(size: 12))
    }

    private func lat(_ icon: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(c)
            Text(v).monospacedDigit().fontWeight(.semibold)
            Text("ms").foregroundStyle(.secondary).font(.system(size: 10))
        }
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
        Task {
            await tester.run()
            onComplete()
        }
    }
}
