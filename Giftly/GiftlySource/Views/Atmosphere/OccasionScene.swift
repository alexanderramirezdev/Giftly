//
//  OccasionScene.swift
//  Giftly
//
//  The background inside an occasion's own page, themed to the event:
//  balloons, confetti and cake for birthdays, hearts for anniversaries and
//  weddings, tossed caps for graduations, pastel balloons for baby showers,
//  lights and snow for Christmas. On the day itself a confetti burst plays
//  once when the page opens. Kept soft so the list stays easy to read.
//

import SwiftUI

struct OccasionScene: View {
    let kind: OccasionKind
    var isToday: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SceneCanvas(reduceMotion: reduceMotion) { ctx, size, t in
                var c = ctx
                c.opacity = 0.8
                OccasionScene.draw(c, kind: kind, size: size, t: t)
            }
            if isToday {
                ConfettiBurst()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func draw(_ c: GraphicsContext, kind: OccasionKind, size: CGSize, t: Double) {
        let w = size.width
        let h = size.height
        switch kind {
        case .birthday:
            let colors: [Color] = [Color(hex: "E8503F"), Color(hex: "FFC63D"), Color(hex: "3B7DD8"), Color(hex: "7BC67B")]
            risingBalloons(c, size: size, t: t, colors: colors)
            SceneProps.cake(c, x: w * 0.82, y: h - 30, t: t)
            SceneProps.particles(c, size: size, t: t, kind: .confetti, count: 14, seed: 5)

        case .babyShower:
            let pastels: [Color] = [Color(hex: "A8D8F0"), Color(hex: "F7C6D6"), Color(hex: "FFF1B5"), Color(hex: "C9F0D8")]
            risingBalloons(c, size: size, t: t, colors: pastels)
            SceneProps.sparkles(c, size: size, t: t, count: 5)

        case .anniversary, .wedding:
            SceneProps.particles(c, size: size, t: t, kind: .heartsRising, count: 14, seed: 2)
            SceneProps.sparkles(c, size: size, t: t, count: 4)

        case .graduation:
            for i in 0..<4 {
                let fi = Double(i)
                let period = 5.0 + fi * 0.8
                let p = SceneProps.frac(t / period + fi * 0.27)
                // A toss: up and back down along a parabola.
                let arc = 4 * p * (1 - p)
                let x = w * CGFloat(0.58 + fi * 0.11)
                let y = h - 40 - CGFloat(arc) * h * 0.35
                let spin: Double = i % 2 == 0 ? 360 : -360
                SceneProps.gradCap(c, x: x, y: y, angle: p * spin)
            }
            SceneProps.sparkles(c, size: size, t: t, count: 7)

        case .christmas:
            SceneProps.stringLights(c, size: size, y: 6, t: t)
            SceneProps.particles(c, size: size, t: t, kind: .snow, count: 22)

        case .holiday, .justBecause, .other:
            SceneProps.sparkles(c, size: size, t: t, count: 6)
        }
    }

    /// A few balloons floating slowly up the right side, looping.
    private static func risingBalloons(_ c: GraphicsContext, size: CGSize, t: Double, colors: [Color]) {
        let w = size.width
        let h = size.height
        for i in 0..<5 {
            let fi = Double(i)
            let p = SceneProps.frac(t / (26 + fi * 3) + fi * 0.21)
            let x = w * CGFloat(0.62 + SceneProps.frac(fi * 0.37) * 0.34)
            let y = (h + 80) - CGFloat(p) * (h + 180)
            SceneProps.balloon(c, x: x, y: y, color: colors[i % colors.count], t: t, seed: fi)
        }
    }
}

// MARK: - Confetti burst (plays once, on the day)

struct ConfettiBurst: View {
    var duration: Double = 3.0
    var count: Int = 70

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    private static let colors: [Color] = [
        Color(hex: "E8503F"), Color(hex: "FFC63D"), Color(hex: "3B7DD8"),
        Color(hex: "7BC67B"), Color(hex: "F28FB0"), Color(hex: "B07FD8")
    ]

    var body: some View {
        Group {
            if let start, !reduceMotion {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        let elapsed = timeline.date.timeIntervalSince(start)
                        draw(ctx, size: size, elapsed: elapsed)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard start == nil, !reduceMotion else { return }
            start = .now
            Haptics.success()
            Task {
                try? await Task.sleep(for: .seconds(duration + 0.2))
                start = nil
            }
        }
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, elapsed: Double) {
        guard elapsed < duration else { return }
        let fade = max(0, min(1, (duration - elapsed) / 0.8))
        let originX = Double(size.width) / 2
        let originY = Double(size.height) * 0.18
        let gravity = 520.0
        for i in 0..<count {
            let fi = Double(i)
            let angle = -Double.pi / 2 + (SceneProps.frac(fi * 0.618) - 0.5) * 2.4
            let speed = 260 + SceneProps.frac(fi * 0.371) * 320
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed
            let x = originX + vx * elapsed
            let y = originY + vy * elapsed + 0.5 * gravity * elapsed * elapsed
            var p = ctx
            p.opacity = fade
            p.translateBy(x: CGFloat(x), y: CGFloat(y))
            p.rotate(by: .degrees(elapsed * (180 + fi * 7)))
            let rect = CGRect(x: -4, y: -2.5, width: 8, height: 5)
            p.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(ConfettiBurst.colors[i % ConfettiBurst.colors.count]))
        }
    }
}
