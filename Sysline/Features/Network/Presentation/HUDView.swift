import SwiftUI

struct HUDView: View {
    @StateObject private var vm = NetworkViewModel()
    @AppStorage("showFloatingHUD") private var showHUD = true
    @AppStorage("hudSize") private var size = 0

    private let width: CGFloat = 280                      // large width for every size
    private var appCount: Int { [0, 3, 5][min(size, 2)] } // small = totals bar only

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 11))
                Button { vm.range = vm.range.next } label: {
                    HStack(spacing: 3) {
                        Text(vm.range.rawValue).font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    showHUD = false
                    FloatingHUD.shared.setVisible(false)
                } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)

            if size == 2, !vm.trend.isEmpty {   // Large: chart on top, only when there's data
                UsageTrendChart(points: vm.trend, showAxes: false)
                    .frame(height: 48)
            }

            HStack(spacing: 14) {
                Text("↓ \(ByteFormat.string(vm.totalIn))").foregroundStyle(Theme.down)
                Text("↑ \(ByteFormat.string(vm.totalOut))").foregroundStyle(Theme.up)
            }
            .font(.system(size: 15, weight: .bold))
            .monospacedDigit()

            if appCount > 0 {
                if vm.topFive.isEmpty {
                    Text("No data yet").font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    ForEach(vm.topFive.prefix(appCount)) { app in
                        HStack(spacing: 6) {
                            Image(nsImage: AppIcon.image(for: app.bundleID))
                                .resizable().frame(width: 14, height: 14)
                            Text(app.name).font(.system(size: 11)).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(ByteFormat.string(app.total))
                                .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: width, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onTapGesture { NSApp.activate(ignoringOtherApps: true) }
        .onAppear { vm.setActive(true) }
        .onDisappear { vm.setActive(false) }
    }
}
