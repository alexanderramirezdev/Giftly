//
//  AtmosphereEngine.swift
//  Giftly
//
//  The motion engine behind Giftly's living seasonal background. Clock-driven
//  (every element is a pure function of the current time), NOT animation-chained
//  — this keeps motion smooth, makes it impossible for two animations to fight
//  over the same property, and respects Reduce Motion everywhere.
//
//  This is Giftly's own engine. It takes the lesson from well-made ambient
//  layers (compute position from a clock, fade in/out, freeze on rest) but the
//  world it renders — gifts, elves, reindeer, ribbons — is unique to Giftly.
//

import SwiftUI

// MARK: - Falling particle math (snow, sparkles, confetti)

nonisolated struct GiftlyFallMotion {
    var topY: CGFloat
    var bottomY: CGFloat
    var fallDuration: Double
    var swayAmplitude: CGFloat
    var swayPeriod: Double
    var baseRotation: Double
    var spin: Double
    var maxOpacity: Double
    var fadeIn: Double = 0.6
    var fadeOut: Double = 0.8

    struct Sample {
        var xOffset: CGFloat
        var y: CGFloat
        var rotation: Double
        var opacity: Double
    }

    var cycle: Double { fallDuration }

    func sample(at time: Double) -> Sample {
        var local = time.truncatingRemainder(dividingBy: cycle)
        if local < 0 { local += cycle }
        let progress = local / fallDuration
        let wave = sin(time * 2 * .pi / swayPeriod)
        let fadeInF = min(1.0, local / fadeIn)
        let fadeOutF = min(1.0, (cycle - local) / fadeOut)
        return Sample(
            xOffset: CGFloat(wave) * swayAmplitude,
            y: topY + (bottomY - topY) * CGFloat(progress),
            rotation: baseRotation + spin * progress + wave * 12,
            opacity: maxOpacity * max(0, min(fadeInF, fadeOutF))
        )
    }
}

struct GiftlyFallingParticle<Content: View>: View {
    let x: CGFloat
    let motion: GiftlyFallMotion
    let phase: Double
    let reduceMotion: Bool
    let staticY: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if reduceMotion {
            content()
                .rotationEffect(.degrees(motion.baseRotation))
                .opacity(motion.maxOpacity * 0.8)
                .position(x: x, y: staticY)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let s = motion.sample(at: timeline.date.timeIntervalSinceReferenceDate + phase)
                content()
                    .rotationEffect(.degrees(s.rotation))
                    .opacity(s.opacity)
                    .position(x: x + s.xOffset, y: s.y)
            }
        }
    }
}

// MARK: - "Pop in and out" math (elves peeking)

/// A character that appears for a beat, then hides, on a repeating schedule
/// offset per-instance so several don't sync. Returns how "out" it is (0 hidden,
/// 1 fully shown) as a smooth function of the clock.
nonisolated struct PeekMotion {
    var period: Double          // full hide→show→hide cycle length
    var visibleFraction: Double // portion of the cycle spent visible
    var phase: Double           // per-instance offset so peeks stagger

    /// 0 = fully hidden, 1 = fully popped up. Eases in and out.
    func visibility(at time: Double) -> Double {
        var local = (time + phase).truncatingRemainder(dividingBy: period)
        if local < 0 { local += period }
        let visibleLen = period * visibleFraction
        guard local < visibleLen else { return 0 }
        // ease up for first 25%, hold, ease down for last 25%
        let p = local / visibleLen
        let eased: Double
        if p < 0.25 { eased = p / 0.25 }
        else if p > 0.75 { eased = (1 - p) / 0.25 }
        else { eased = 1 }
        // smoothstep
        return eased * eased * (3 - 2 * eased)
    }
}
