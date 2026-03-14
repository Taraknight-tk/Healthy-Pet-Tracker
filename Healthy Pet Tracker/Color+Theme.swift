import SwiftUI
import UIKit

extension Color {

    // MARK: - Backgrounds
    static let bgPrimary   = Color(UIColor.themed(light: "F5F0E8", dark: "1C1917"))
    static let bgSecondary = Color(UIColor.themed(light: "E8DFD3", dark: "2A2420"))
    static let bgTertiary  = Color(UIColor.themed(light: "FDFCFA", dark: "322C26"))

    // MARK: - Text
    static let textPrimary   = Color(UIColor.themed(light: "4A4540", dark: "EDE8E3"))
    static let textSecondary = Color(UIColor.themed(light: "6B6460", dark: "B5ADA7"))
    static let textTertiary  = Color(UIColor.themed(light: "9B938E", dark: "8A817C"))

    // MARK: - Borders
    static let borderSubtle   = Color(UIColor.themed(light: "D4C7B8", dark: "3D3530"))
    static let borderEmphasis = Color(UIColor.themed(light: "A89B8E", dark: "5C524C"))

    // MARK: - Accent
    static let accentPrimary = Color(UIColor.themed(light: "7FB685", dark: "8EC494"))
    static let accentActive  = Color(UIColor.themed(light: "5A9B61", dark: "6CB574"))
    static let accentMuted   = Color(UIColor.themed(light: "9BB896", dark: "A8C4A4"))

    // MARK: - Helper (SwiftUI Color from hex string)
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

// MARK: - UIColor helpers
extension UIColor {

    /// Creates a UIColor from a 6-character hex string.
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    /// Returns an adaptive UIColor that switches between light and dark hex values.
    static func themed(light lightHex: String, dark darkHex: String) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: darkHex)
                : UIColor(hex: lightHex)
        }
    }
}
