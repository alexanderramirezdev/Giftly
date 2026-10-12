//
//  GiftlyAtmosphereView.swift
//  Giftly
//
//  Assembles Giftly's living seasonal background. Sits BEHIND the home content,
//  ignores touches, and is hidden from accessibility. Season is chosen from the
//  nearest upcoming occasion (so the world matches what you're shopping for),
//  falling back to the calendar month.
//

import SwiftUI

enum GiftlySeason {
    case winter, spring, summer, autumn

    static func forMonth(_ m: Int) -> GiftlySeason {
        switch m {
        case 12, 1, 2: return .winter
        case 3, 4, 5:  return .spring
        case 6, 7, 8:  return .summer
        default:       return .autumn
        }
    }
}

struct GiftlyAtmosphereView: View {
    /// Pass a season explicitly, or nil to derive from the current month.
    var season: GiftlySeason?
    /// 0...1 fullness for the gift stack (occasion progress). 1 = full.
    var giftFullness: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedSeason: GiftlySeason {
        season ?? .forMonth(Calendar.current.component(.month, from: .now))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch resolvedSeason {
                case .winter:
                    WinterAtmosphere(size: geo.size, reduceMotion: reduceMotion, giftFullness: giftFullness)
                default:
                    // Other seasons slot in here later; winter ships first.
                    WinterAtmosphere(size: geo.size, reduceMotion: reduceMotion, giftFullness: giftFullness)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Winter composition

private struct WinterAtmosphere: View {
    let size: CGSize
    let reduceMotion: Bool
    let giftFullness: Double

    var body: some View {
        ZStack {
            // 1. Swaying snowy pine, anchored bottom-right
            GentleSway(reduceMotion: reduceMotion, anchor: UnitPoint(x: 0.8, y: 1.0), maxAngle: 0.8) {
                GiftlyPineTree()
            }
            .frame(width: size.width, height: size.height)

            // 2. Gift stack at the tree's foot
            GiftlyGiftStack(fullness: giftFullness)
                .frame(width: 180, height: 90)
                .position(x: size.width * 0.80 - 40, y: size.height - 46)

            // 3. Elves peeking in and out from behind the tree
            ElfPeek(size: size, reduceMotion: reduceMotion,
                    anchor: CGPoint(x: size.width * 0.62, y: size.height - 70),
                    period: 11, phase: 0, flip: false)
            ElfPeek(size: size, reduceMotion: reduceMotion,
                    anchor: CGPoint(x: size.width * 0.93, y: size.height - 60),
                    period: 14, phase: 6, flip: true)

            // 4. A reindeer strolling across the lower band
            ReindeerStroll(size: size, reduceMotion: reduceMotion)

            // 5. Drifting snow
            ForEach(0..<18, id: \.self) { i in
                SnowFlake(index: i, total: 18, size: size, reduceMotion: reduceMotion)
            }

            // 6. A few slow golden sparkles for warmth
            ForEach(0..<6, id: \.self) { i in
                Sparkle(index: i, size: size, reduceMotion: reduceMotion)
            }
        }
    }
}

// MARK: - Gentle sway wrapper

private struct GentleSway<Content: View>: View {
    let reduceMotion: Bool
    var anchor: UnitPoint = .bottom
    var maxAngle: Double = 0.9
    var duration: Double = 5.5
    @ViewBuilder var content: () -> Content
    @State private var angle: Double = 0

    var body: some View {
        content()
            .rotationEffect(.degrees(angle), anchor: anchor)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    angle = maxAngle
                }
            }
    }
}

// MARK: - Elf peek

private struct ElfPeek: View {
    let size: CGSize
    let reduceMotion: Bool
    let anchor: CGPoint
    let period: Double
    let phase: Double
    let flip: Bool

    private let motion: PeekMotion

    init(size: CGSize, reduceMotion: Bool, anchor: CGPoint, period: Double, phase: Double, flip: Bool) {
        self.size = size; self.reduceMotion = reduceMotion
        self.anchor = anchor; self.period = period; self.phase = phase; self.flip = flip
        self.motion = PeekMotion(period: period, visibleFraction: 0.32, phase: phase)
    }

    var body: some View {
        if reduceMotion {
            // Show the elf gently, half-up, no popping.
            GiftlyElf(visibility: 0.85, flip: flip).position(anchor)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let v = motion.visibility(at: timeline.date.timeIntervalSinceReferenceDate)
                GiftlyElf(visibility: v, flip: flip)
                    .position(anchor)
            }
        }
    }
}

// MARK: - Reindeer stroll (loops across the lower band every ~22s)

private struct ReindeerStroll: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var x: CGFloat = -120
    @State private var bob: CGFloat = 0

    var body: some View {
        let y = size.height - 150
        GiftlyReindeer()
            .offset(y: bob)
            .position(x: x, y: y)
            .opacity(0.95)
            .task {
                guard !reduceMotion else { x = size.width * 0.18; return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { bob = -4 }
                while !Task.isCancelled {
                    x = -120
                    withAnimation(.linear(duration: 22)) { x = size.width + 120 }
                    try? await Task.sleep(for: .seconds(22))
                    try? await Task.sleep(for: .seconds(14))   // off-screen rest
                }
            }
    }
}

// MARK: - Snow

private struct SnowFlake: View {
    let index: Int
    let total: Int
    let size: CGSize
    let reduceMotion: Bool

    private var startX: CGFloat {
        let seed = Double((index * 127) % 100) / 100.0
        return size.width * CGFloat(0.05 + seed * 0.9)
    }
    private var flakeSize: CGFloat { [9, 12, 15, 18, 11, 14][index % 6] }
    private var motion: GiftlyFallMotion {
        GiftlyFallMotion(
            topY: -20, bottomY: size.height + 30,
            fallDuration: 9 + Double(index % 5) * 1.8,
            swayAmplitude: 14, swayPeriod: 7,
            baseRotation: Double((index * 60) % 360), spin: 120,
            maxOpacity: [0.5, 0.7, 0.85, 0.6, 0.75][index % 5]
        )
    }

    var body: some View {
        GiftlyFallingParticle(
            x: startX, motion: motion,
            phase: motion.cycle * Double((index * 79) % 100) / 100.0,
            reduceMotion: reduceMotion,
            staticY: size.height * CGFloat(Double((index * 53) % 100) / 100.0)
        ) {
            Image(systemName: "snowflake")
                .font(.system(size: flakeSize))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Sparkle

private struct Sparkle: View {
    let index: Int
    let size: CGSize
    let reduceMotion: Bool
    @State private var on = false

    private var pos: CGPoint {
        CGPoint(x: size.width * CGFloat(Double((index * 83) % 100) / 100.0),
                y: size.height * CGFloat(0.12 + Double((index * 37) % 60) / 100.0))
    }

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: [8, 11, 9][index % 3]))
            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(on ? 0.9 : 0.2))
            .position(pos)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4 + Double(index % 3) * 0.5)
                    .repeatForever(autoreverses: true).delay(Double(index) * 0.4)) {
                    on = true
                }
            }
    }
}
