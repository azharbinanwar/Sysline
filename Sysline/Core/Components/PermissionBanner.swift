import SwiftUI

struct PermissionBanner: View {
    let text: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Open Settings", action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}
