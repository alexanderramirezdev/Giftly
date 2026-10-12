//
//  Color+Hex.swift
//  Giftly
//
//  Small utility so Person.colorHex ("#4C8BF5") renders as a SwiftUI Color.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b: Double
        switch s.count {
        case 6:
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
        default:
            r = 0.3; g = 0.55; b = 0.96   // sensible fallback blue
        }
        self.init(red: r, green: g, blue: b)
    }
}
