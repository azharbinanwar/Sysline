import SwiftUI
import Charts

struct UsageTrendChart: View {
    let points: [UsagePoint]
    var showAxes = true

    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Time", p.date), y: .value("In", p.bytesIn))
                    .foregroundStyle(Theme.down.opacity(0.12))
                    .interpolationMethod(.catmullRom)
            }
            ForEach(points) { p in
                LineMark(x: .value("Time", p.date), y: .value("In", p.bytesIn),
                         series: .value("Series", "In"))
                    .foregroundStyle(Theme.down)
                    .interpolationMethod(.catmullRom)
            }
            ForEach(points) { p in
                LineMark(x: .value("Time", p.date), y: .value("Out", p.bytesOut),
                         series: .value("Series", "Out"))
                    .foregroundStyle(Theme.up)
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            if showAxes {
                AxisMarks { value in
                    AxisValueLabel {
                        if let bytes = value.as(Int.self) {
                            Text(ByteFormat.string(bytes)).font(.system(size: 9))
                        }
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }
}
