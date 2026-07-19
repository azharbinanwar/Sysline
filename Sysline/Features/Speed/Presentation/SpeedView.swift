import SwiftUI
import Charts

struct SpeedView: View {
    @StateObject private var vm = SpeedViewModel()
    @State private var showTest = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vm.history.isEmpty {
                    empty
                } else {
                    if vm.history.count > 1 { trend }
                    historyList
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Speed")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showTest = true } label: { Label("Run Test", systemImage: "play.fill") }
            }
        }
        .sheet(isPresented: $showTest) {
            SpeedTestSheet(network: CurrentNetwork.identifier()) { vm.load() }
        }
        .onAppear { vm.load() }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "speedometer").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("No speed tests yet").font(.headline)
            Text("Run a test to measure your download, upload, and ping.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Run Test") { showTest = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Past tests")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary).textCase(.uppercase)
            VStack(spacing: 0) {
                ForEach(Array(vm.history.enumerated()), id: \.element.id) { i, r in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sourceLabel(r).isEmpty ? "Speed test" : sourceLabel(r))
                                .font(.system(size: 13, weight: .medium)).lineLimit(1)
                            miniRatings(r)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(String(format: "↓ %.1f", r.downMbps)).foregroundStyle(Theme.down)
                                Text(String(format: "↑ %.1f", r.upMbps)).foregroundStyle(Theme.up)
                                Text("\(r.pingMs) ms").foregroundStyle(.secondary)
                            }
                            .font(.system(size: 13)).monospacedDigit()
                            Text(r.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(i.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    // Wi-Fi name · carrier · location — every field we have, dropping only
    // blanks and the "Unknown network" placeholder.
    private func sourceLabel(_ r: SpeedResult) -> String {
        [r.network, r.isp, r.place]
            .filter { !$0.isEmpty && $0 != "Unknown network" }
            .joined(separator: " · ")
    }

    // Compact per-result quality: tiny icon + 0–5 score.
    private func miniRatings(_ r: SpeedResult) -> some View {
        HStack(spacing: 12) {
            ForEach(SpeedRating.all(down: r.downMbps, up: r.upMbps, ping: r.pingMs)) { rt in
                HStack(spacing: 3) {
                    Image(systemName: rt.icon).font(.system(size: 10))
                        .foregroundStyle(rt.score >= 3 ? Theme.up : (rt.score >= 2 ? .orange : .secondary))
                    Text("\(rt.score)").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // Point-based (evenly spaced by test number, not by date) with smooth curves.
    private var trend: some View {
        let pts = Array(vm.history.reversed().enumerated())
        let maxY = (vm.history.map { max($0.downMbps, $0.upMbps) }.max() ?? 10) * 1.2
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Download & upload")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary).textCase(.uppercase)
                Spacer()
                legendDot(Theme.down, "Down"); legendDot(Theme.up, "Up")
            }
            Chart {
                ForEach(pts, id: \.offset) { i, r in
                    AreaMark(x: .value("Test", i), y: .value("Mbps", r.downMbps))
                        .foregroundStyle(LinearGradient(colors: [Theme.down.opacity(0.16), Theme.down.opacity(0.01)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(pts, id: \.offset) { i, r in
                    LineMark(x: .value("Test", i), y: .value("Mbps", r.downMbps), series: .value("s", "down"))
                        .foregroundStyle(Theme.down).lineStyle(.init(lineWidth: 2)).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Test", i), y: .value("Mbps", r.downMbps))
                        .foregroundStyle(Theme.down).symbolSize(22)
                }
                ForEach(pts, id: \.offset) { i, r in
                    LineMark(x: .value("Test", i), y: .value("Mbps", r.upMbps), series: .value("s", "up"))
                        .foregroundStyle(Theme.up).lineStyle(.init(lineWidth: 2)).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Test", i), y: .value("Mbps", r.upMbps))
                        .foregroundStyle(Theme.up).symbolSize(22)
                }
            }
            .chartYScale(domain: 0...maxY)
            .chartXAxis(.hidden)
            .frame(height: 150)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        }
    }

    private func legendDot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(t).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}
