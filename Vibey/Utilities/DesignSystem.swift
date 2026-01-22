//
//  DesignSystem.swift
//  Vibey
//
//  Central design system with colors, fonts, and spacing
//  Based on Figma designs
//

import SwiftUI

// MARK: - Colors
extension Color {
    // Background colors from Figma
    static let vibeyBackground = Color(hex: "121418")      // Main dark background
    static let vibeyCardBorder = Color(hex: "242529")      // Card border color
    static let vibeyText = Color(hex: "EBECF0")            // Main text color
    static let vibeyBlue = Color(hex: "0459FE")            // Brand blue (links, accents)

    // Helper to create Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Fonts
extension Font {
    // Story Script - for "Vibey" logo text
    static func storyScript(size: CGFloat) -> Font {
        .custom("StoryScript-Regular", size: size)
    }

    // Lexend - for ".code" in logo and UI text
    static func lexendThin(size: CGFloat) -> Font {
        .custom("Lexend-Thin", size: size)
    }

    static func lexendLight(size: CGFloat) -> Font {
        .custom("Lexend-Light", size: size)
    }

    static func lexendRegular(size: CGFloat) -> Font {
        .custom("Lexend", size: size)
    }

    static func lexendMedium(size: CGFloat) -> Font {
        .custom("Lexend-Medium", size: size)
    }

    static func lexendBold(size: CGFloat) -> Font {
        .custom("Lexend Bold", size: size)
    }

    static func lexendExtraBold(size: CGFloat) -> Font {
        .custom("Lexend ExtraBold", size: size)
    }

    static func lexendBlack(size: CGFloat) -> Font {
        .custom("Lexend Black", size: size)
    }

    // Atkinson Hyperlegible - for body text
    static func atkinsonRegular(size: CGFloat) -> Font {
        .custom("Atkinson Hyperlegible", size: size)
    }

    static func atkinsonBold(size: CGFloat) -> Font {
        .custom("AtkinsonHyperlegible-Bold", size: size)
    }
}

// MARK: - Spacing
enum Spacing {
    static let extraSmall: CGFloat = 8
    static let small: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 32
    static let extraLarge: CGFloat = 64
}

// MARK: - Corner Radius
enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let button: CGFloat = 1000  // Full pill shape for buttons
}
