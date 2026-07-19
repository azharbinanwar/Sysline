//
//  UsageChartView.swift
//  Sysline
//
//  Top-5 apps as horizontal bars (total bytes).
//

import SwiftUI
import Charts

struct UsageChartView: View {
    let apps: [AppUsage]

    var body: some View {
        Chart(apps) { app in
            BarMark(
                x: .value("Usage", app.total),
                y: .value("App", app.name)
            )
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let bytes = value.as(Int.self) {
                        Text(ByteFormat.string(bytes)).font(.system(size: 9))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { AxisValueLabel().font(.system(size: 10)) }
        }
        .frame(height: CGFloat(apps.count) * 26)
    }
}
