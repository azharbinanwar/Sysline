//
//  AppRowView.swift
//  Sysline
//
//  One app's row in the usage list.
//

import SwiftUI

struct AppRowView: View {
    let app: AppUsage

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIcon.image(for: app.bundleID))
                .resizable()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("↓ \(ByteFormat.string(app.bytesIn))   ↑ \(ByteFormat.string(app.bytesOut))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(ByteFormat.string(app.total))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 3)
    }
}
