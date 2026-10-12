//
//  GiftlyBackground.swift
//  Giftly
//
//  One warm, inviting background used on EVERY screen so the app feels like a
//  single cozy space instead of a stack of blank-white sheets. Two intensities:
//   • .full   — home screen: the warm wash + the living seasonal scene
//   • .subtle — inner/detail screens: the warm wash + a faint ambient touch
//               (a soft top glow and a few quiet snowflakes), nothing that
//               competes with content.
//
//  Use via the modifier: `.giftlyBackground()` or `.giftlyBackground(.full, season:)`.
//

import SwiftUI

enum GiftlyBackgroundStyle { case full, subtle }

struct GiftlyBackground: View {
    var style: GiftlyBackgroundStyle = .subtle
    var season: GiftlySeason? = nil
    var giftFullness: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Warm wash: cream base with a gentle vertical gradient so it isn't flat.
            LinearGradient(
                colors: [
                    GiftlyTheme.background,
                    GiftlyTheme.background,
                    GiftlyTheme.cranberry.opacity(0.045)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Soft radial warmth near the top so the header area feels lit.
            RadialGradient(
                colors: [GiftlyTheme.gold.opacity(0.10), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 320
            )

            switch style {
            case .full:
                GiftlyAtmosphereView(season: season, giftFullness: giftFullness)
            case .subtle:
                SubtleAmbient(reduceMotion: reduceMotion)
            }
        }
        .ignoresSafeArea()
    }
}

/// A quiet ambient layer for inner screens: a handful of slow, faint snowflakes.
/// Enough to feel alive, little enough to never distract from content.
private struct SubtleAmbient: View {
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    FaintFlake(index: i, size: geo.size, reduceMotion: reduceMotion)
                }
            }
        }
    }
}

private struct FaintFlake: View {
    let index: Int
    let size: CGSize
    let reduceMotion: Bool

    private var startX: CGFloat {
        let seed = Double((index * 149) % 100) / 100.0
        return size.width * CGFloat(0.06 + seed * 0.88)
    }
    private var flakeSize: CGFloat { [10, 13, 16, 11][index % 4] }
    private var motion: GiftlyFallMotion {
        GiftlyFallMotion(
            topY: -20, bottomY: size.height + 30,
            fallDuration: 16 + Double(index % 4) * 3.0,   // slow
            swayAmplitude: 10, swayPeriod: 9,
            baseRotation: Double((index * 70) % 360), spin: 60,
            maxOpacity: 0.10                               // very faint
        )
    }

    var body: some View {
        GiftlyFallingParticle(
            x: startX, motion: motion,
            phase: motion.cycle * Double((index * 61) % 100) / 100.0,
            reduceMotion: reduceMotion,
            staticY: size.height * CGFloat(Double((index * 41) % 100) / 100.0)
        ) {
            Image(systemName: "snowflake")
                .font(.system(size: flakeSize))
                .foregroundStyle(GiftlyTheme.evergreen.opacity(0.5))
        }
    }
}

// MARK: - Modifier for easy app-wide use

extension View {
    /// Puts a Giftly warm background behind this view. Default is the subtle
    /// style for inner screens; pass .full for the home scene.
    func giftlyBackground(_ style: GiftlyBackgroundStyle = .subtle,
                          season: GiftlySeason? = nil,
                          giftFullness: Double = 1.0) -> some View {
        self.background(
            GiftlyBackground(style: style, season: season, giftFullness: giftFullness)
        )
    }
}
