//
//  GiftlyBackground.swift
//  Giftly
//
//  One warm, inviting background used on EVERY screen so the app feels like a
//  single cozy space instead of a stack of blank-white sheets. Two intensities:
//   • .full   — home screen: the warm wash + the living seasonal scene
//   • .subtle — inner/detail screens: the warm wash + a faint ambient touch
//               (a soft top glow and a few quiet seasonal symbols), nothing that
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
    @AppStorage(GiftlySeason.settingKey) private var seasonSetting = "auto"
    @AppStorage(GiftlySeason.previewTouchKey) private var previewTouch = "none"

    private var shownSeason: GiftlySeason {
        season ?? GiftlySeason.shown(setting: seasonSetting, preview: previewTouch)
    }

    var body: some View {
        // The season lives here, in the background, not in the text.
        let washColor: Color = shownSeason.accent.opacity(0.10)
        return ZStack {
            // Warm wash: cream base with a gentle vertical gradient so it isn't flat.
            LinearGradient(
                colors: [
                    GiftlyTheme.background,
                    GiftlyTheme.background,
                    washColor
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
                SubtleAmbient(reduceMotion: reduceMotion, season: shownSeason)
            }
        }
        .ignoresSafeArea()
    }
}

/// A quiet ambient layer for inner screens: a handful of slow, faint snowflakes.
/// Enough to feel alive, little enough to never distract from content.
private struct SubtleAmbient: View {
    let reduceMotion: Bool
    let season: GiftlySeason

    /// Holiday and Snow Day get snowflakes, spring petals, summer sparkles, autumn leaves.
    private var symbol: String {
        switch season {
        case .holiday, .snowDay: return "snowflake"
        case .spring:            return "camera.macro"
        case .summer:            return "sparkle"
        case .autumn:            return "leaf.fill"
        }
    }

    // One slow clock for all seven (not one each): inner screens stay light.
    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                flakes(size: geo.size, time: nil)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                    flakes(size: geo.size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func flakes(size: CGSize, time: Double?) -> some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                FaintFlake(index: i, size: size, time: time, symbol: symbol, tint: season.accent)
            }
        }
    }
}

private struct FaintFlake: View {
    let index: Int
    let size: CGSize
    /// nil = Reduce Motion: a still flake.
    let time: Double?
    let symbol: String
    let tint: Color

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
        let m = motion
        let icon = Image(systemName: symbol)
            .font(.system(size: flakeSize))
            .foregroundStyle(tint.opacity(0.6))
        if let time {
            let phase = m.cycle * Double((index * 61) % 100) / 100.0
            let s = m.sample(at: time + phase)
            icon
                .rotationEffect(.degrees(s.rotation))
                .opacity(s.opacity)
                .position(x: startX + s.xOffset, y: s.y)
        } else {
            icon
                .rotationEffect(.degrees(m.baseRotation))
                .opacity(m.maxOpacity * 0.8)
                .position(x: startX, y: size.height * CGFloat(Double((index * 41) % 100) / 100.0))
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
