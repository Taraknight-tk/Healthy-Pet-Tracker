import SwiftUI

extension Color {

    // MARK: - Backgrounds
    static let bgPrimary = Color(hex: "F5F0E8")
    static let bgSecondary = Color(hex: "E8DFD3")
    static let bgTertiary = Color(hex: "FDFCFA")

    // MARK: - Text
    static let textPrimary = Color(hex: "4A4540")
    static let textSecondary = Color(hex: "6B6460")
    static let textTertiary = Color(hex: "9B938E")

    // MARK: - Borders
    static let borderSubtle = Color(hex: "D4C7B8")
    static let borderEmphasis = Color(hex: "A89B8E")

    // MARK: - Accent
    static let accentPrimary = Color(hex: "7FB685")
    static let accentActive = Color(hex: "5A9B61")
    static let accentMuted = Color(hex: "9BB896")

    // MARK: - Helper
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
