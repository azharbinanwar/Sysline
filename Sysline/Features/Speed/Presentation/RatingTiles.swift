import SwiftUI

// The four activity tiles (icon + 0–5 dots), Speedtest-style. Dots fill in
// smoothly as scores land; a score of 0 means "not measured yet".
struct RatingTiles: View {
    let ratings: [SpeedRating]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ratings) { r in
                VStack(spacing: 7) {
                    Image(systemName: r.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(r.score >= 3 ? Theme.up : (r.score >= 2 ? .orange : .secondary))
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle()
                                .fill(i < r.score ? color(r.score) : Color.secondary.opacity(0.22))
                                .frame(width: 4, height: 4)
                        }
                    }
                    Text(r.label).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
            }
        }
        .animation(.easeOut(duration: 0.35), value: ratings.map(\.score))
    }

    private func color(_ score: Int) -> Color {
        score >= 3 ? Theme.up : (score >= 2 ? .orange : .red)
    }
}
