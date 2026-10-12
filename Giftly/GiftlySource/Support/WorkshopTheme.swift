//
//  WorkshopTheme.swift
//  Giftly
//
//  The workshop layer that sits on top of GiftlyTheme: Pip's fixed colors
//  (he looks the same in light and dark mode), his name, and a few shared
//  helpers used by the workshop pieces (ElfView, ElfHandoffView, GiftBoxMark).
//  Screen backgrounds, cards and text colors still come from GiftlyTheme.
//

import SwiftUI

enum Workshop {
    // Pip's palette. Fixed, not adaptive, so the character never changes.
    static let woodLight = Color(hex: "2A1B11")   // the little workshop window in the handoff card
    static let grain     = Color(hex: "3B2718")
    static let brass     = Color(hex: "E3B04B")
    static let cream     = Color(hex: "F6E9D2")
    static let dimCream  = Color(hex: "B9A58A")
    static let pine      = Color(hex: "2F7D4F")
    static let berry     = Color(hex: "C0392B")

    /// The head elf's name. Change in one place.
    static let elfName = "Pip"
}

extension Font {
    /// Serif accent type for Pip's lines and workshop moments.
    static func workshop(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// Four point sparkle, used for glints and "found it" moments.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.28
        for i in 0..<8 {
            let angle = Double(i) * Double.pi / 4 - Double.pi / 2
            let radius = i % 2 == 0 ? outer : inner
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

/// Pip's speech bubble: a GiftlyCard with Pip beside it. Used on home, the
/// welcome screen and anywhere Pip talks.
struct PipSays: View {
    let text: String
    var pose: ElfPose = .idle
    var elfSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ElfView(pose: pose, size: elfSize)
            GiftlyCard(padding: 12) {
                Text(text)
                    .font(.workshop(15, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, elfSize * 0.2)
        }
    }
}
