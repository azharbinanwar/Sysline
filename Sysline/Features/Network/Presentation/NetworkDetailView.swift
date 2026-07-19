import SwiftUI

struct NetworkDetailView: View {
    @ObservedObject var vm: NetworkViewModel
    @State private var sortOrder = [KeyPathComparator(\AppUsage.total, order: .reverse)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            totals

            UsageTrendChart(points: vm.trend)
                .frame(height: 130)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(.separator))

            Table(vm.filteredApps.sorted(using: sortOrder), sortOrder: $sortOrder) {
                TableColumn("App") { app in
                    HStack(spacing: 8) {
                        Image(nsImage: AppIcon.image(for: app.bundleID))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(app.name)
                    }
                }
                TableColumn("↓ In", value: \.bytesIn) { app in
                    Text(ByteFormat.string(app.bytesIn)).foregroundStyle(Theme.down)
                }
                TableColumn("↑ Out", value: \.bytesOut) { app in
                    Text(ByteFormat.string(app.bytesOut)).foregroundStyle(Theme.up)
                }
                TableColumn("Total", value: \.total) { app in
                    Text(ByteFormat.string(app.total)).fontWeight(.semibold)
                }
                TableColumn("%") { app in
                    Text("\(vm.percent(app))%").foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var totals: some View {
        HStack(spacing: 28) {
            total("↓", vm.totalIn, "downloaded", Theme.down)
            total("↑", vm.totalOut, "uploaded", Theme.up)
            Spacer()
        }
    }

    private func total(_ arrow: String, _ bytes: Int, _ label: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(arrow) \(ByteFormat.string(bytes))")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(color)
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}
