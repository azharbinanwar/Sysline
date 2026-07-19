import SwiftUI

enum Theme {
    static let down   = Color(red: 10/255, green: 132/255, blue: 255/255) // #0A84FF
    static let up     = Color(red: 48/255, green: 209/255, blue:  88/255) // #30D158
    static let accent = Color(red:  0/255, green: 113/255, blue: 227/255) // #0071E3

    static let cardRadius: CGFloat = 10

    // 0 = System, 1 = Light, 2 = Dark
    static func colorScheme(_ raw: Int) -> ColorScheme? {
        raw == 1 ? .light : raw == 2 ? .dark : nil
    }

    /// Stable placeholder tile per app until we resolve real icons.
    static func tile(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Color(hue: Double(sum % 360) / 360, saturation: 0.55, brightness: 0.78)
    }
}
