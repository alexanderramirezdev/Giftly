//
//  SceneProps.swift
//  Giftly
//
//  Shared drawing pieces for every season and occasion scene: trees,
//  snowman, sun, clouds, kite, pumpkins, eggs, tulips, balloons, cake,
//  hearts, graduation caps, bunting, butterflies, and particle fields
//  (snow, petals, leaves, hearts, confetti). Everything draws into a
//  GraphicsContext from a clock value, so a whole scene is one Canvas.
//

import SwiftUI

/// One Canvas driven by a clock, with a still frame under Reduce Motion.
struct SceneCanvas: View {
    let reduceMotion: Bool
    var fps: Double = 30
    let draw: (GraphicsContext, CGSize, Double) -> Void

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { ctx, size in draw(ctx, size, 0) }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / fps)) { timeline in
                    Canvas { ctx, size in
                        draw(ctx, size, timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum ParticleKind {
    case snow, petals, leaves, heartsRising, confetti
}

enum SceneProps {

    // MARK: Basics

    static func dot(_ c: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: Color) {
        c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    static func frac(_ v: Double) -> Double { v - floor(v) }

    // MARK: Particles

    /// A field of falling (or rising) particles across the whole canvas.
    static func particles(_ c: GraphicsContext, size: CGSize, t: Double, kind: ParticleKind,
                          count: Int, seed: Double = 0) {
        let w = Double(size.width)
        let h = Double(size.height)
        let snowColor = Color(hex: "BFD3E3")
        let petalColors: [Color] = [Color(hex: "F7C6D6"), Color(hex: "F28FB0"), Color(hex: "FFE3EC")]
        let leafColors: [Color] = [Color(hex: "E9913A"), Color(hex: "C0392B"), Color(hex: "F2C14E"), Color(hex: "B5651D")]
        let heartColors: [Color] = [Color(hex: "E8503F"), Color(hex: "F28FB0"), Color(hex: "D9567A")]
        let confettiColors: [Color] = [Color(hex: "E8503F"), Color(hex: "3B7DD8"), Color(hex: "FFD36B"),
                                       Color(hex: "9BE07A"), Color(hex: "B98AE0")]

        for i in 0..<count {
            let fi = Double(i)
            let x0 = frac(fi * 0.6180339887 + seed) * w
            let speed = 16.0 + Double(i % 5) * 6.0
            let travel = h + 60
            var y = (t * speed + fi * 53.0).truncatingRemainder(dividingBy: travel) - 30
            if kind == .heartsRising { y = h + 30 - (t * speed * 0.8 + fi * 61.0).truncatingRemainder(dividingBy: travel) }
            let sway = sin(t * 0.8 + fi) * (10.0 + Double(i % 4) * 4.0)
            let px = CGFloat(x0 + sway)
            let py = CGFloat(y)
            let spin = Angle.degrees(t * (40 + Double(i % 3) * 30) * (i % 2 == 0 ? 1 : -1) + fi * 40)

            switch kind {
            case .snow:
                let r = CGFloat(1.6 + Double(i % 4) * 0.8)
                dot(c, px, py, r, snowColor.opacity(0.75))
            case .petals:
                var p = c
                p.translateBy(x: px, y: py)
                p.rotate(by: spin)
                p.fill(Path(ellipseIn: CGRect(x: -4, y: -6, width: 8, height: 12)),
                       with: .color(petalColors[i % petalColors.count].opacity(0.85)))
            case .leaves:
                var l = c
                l.translateBy(x: px, y: py)
                l.rotate(by: spin)
                l.fill(leafPath(size: 9), with: .color(leafColors[i % leafColors.count].opacity(0.9)))
            case .heartsRising:
                let r = CGFloat(6 + (i % 3) * 3)
                c.fill(heartPath(center: CGPoint(x: px, y: py), r: r),
                       with: .color(heartColors[i % heartColors.count].opacity(0.55)))
            case .confetti:
                var p = c
                p.translateBy(x: px, y: py)
                p.rotate(by: spin)
                p.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)),
                       with: .color(confettiColors[i % confettiColors.count].opacity(0.85)))
            }
        }
    }

    static func leafPath(size s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -s))
        p.addQuadCurve(to: CGPoint(x: 0, y: s), control: CGPoint(x: s * 0.9, y: -s * 0.2))
        p.addQuadCurve(to: CGPoint(x: 0, y: -s), control: CGPoint(x: -s * 0.9, y: -s * 0.2))
        p.closeSubpath()
        return p
    }

    static func heartPath(center: CGPoint, r: CGFloat) -> Path {
        let x = center.x
        let y = center.y
        var p = Path()
        p.move(to: CGPoint(x: x, y: y + r * 0.9))
        p.addCurve(to: CGPoint(x: x, y: y - r * 0.35),
                   control1: CGPoint(x: x - r * 1.4, y: y),
                   control2: CGPoint(x: x - r * 0.9, y: y - r))
        p.addCurve(to: CGPoint(x: x, y: y + r * 0.9),
                   control1: CGPoint(x: x + r * 0.9, y: y - r),
                   control2: CGPoint(x: x + r * 1.4, y: y))
        p.closeSubpath()
        return p
    }

    // MARK: Ground

    /// A rolling band of ground along the bottom.
    static func ground(_ c: GraphicsContext, size: CGSize, back: Color, front: Color) {
        let w = size.width
        let h = size.height
        c.fill(Path(ellipseIn: CGRect(x: -w * 0.3, y: h - 90, width: w * 1.1, height: 160)), with: .color(back))
        c.fill(Path(ellipseIn: CGRect(x: w * 0.2, y: h - 70, width: w * 1.2, height: 150)), with: .color(front))
    }

    // MARK: Trees

    /// Round canopy tree (spring blossom or autumn color), swaying from the base.
    static func canopyTree(_ c: GraphicsContext, x: CGFloat, base: CGFloat, leaf: Color, leafShade: Color,
                           accents: [Color], sway: Double) {
        var g = c
        g.translateBy(x: x, y: base)
        g.rotate(by: .degrees(sway))
        g.translateBy(x: -x, y: -base)

        var trunk = Path()
        trunk.move(to: CGPoint(x: x - 9, y: base))
        trunk.addLine(to: CGPoint(x: x - 6, y: base - 70))
        trunk.addQuadCurve(to: CGPoint(x: x + 6, y: base - 70), control: CGPoint(x: x, y: base - 78))
        trunk.addLine(to: CGPoint(x: x + 9, y: base))
        trunk.closeSubpath()
        g.fill(trunk, with: .color(Color(hex: "7A4E2E")))
        var branch = Path()
        branch.move(to: CGPoint(x: x - 3, y: base - 60))
        branch.addQuadCurve(to: CGPoint(x: x - 30, y: base - 90), control: CGPoint(x: x - 20, y: base - 82))
        g.stroke(branch, with: .color(Color(hex: "7A4E2E")), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (x - 38, base - 110, 34), (x + 34, base - 112, 36), (x, base - 140, 42),
            (x - 18, base - 92, 30), (x + 22, base - 90, 30)
        ]
        for (px, py, r) in puffs { dot(g, px, py, r, leaf) }
        for (px, py, r) in puffs { dot(g, px + r * 0.25, py + r * 0.25, r * 0.7, leafShade.opacity(0.35)) }
        for i in 0..<26 {
            let fi = Double(i)
            let puff = puffs[i % puffs.count]
            let angle = fi * 2.399
            let dist = CGFloat(frac(fi * 0.37)) * puff.2 * 0.85
            let r = CGFloat(2.5 + Double(i % 3) * 0.5)
            dot(g, puff.0 + CGFloat(cos(angle)) * dist, puff.1 + CGFloat(sin(angle)) * dist, r,
                accents[i % accents.count])
        }
    }

    /// A small distant pine for the Snow Day hills.
    static func littlePine(_ c: GraphicsContext, x: CGFloat, base: CGFloat, height: CGFloat) {
        var tri = Path()
        tri.move(to: CGPoint(x: x, y: base - height))
        tri.addLine(to: CGPoint(x: x - height * 0.32, y: base))
        tri.addLine(to: CGPoint(x: x + height * 0.32, y: base))
        tri.closeSubpath()
        c.fill(tri, with: .color(Color(hex: "5E8C79").opacity(0.55)))
        var cap = Path()
        cap.move(to: CGPoint(x: x, y: base - height))
        cap.addLine(to: CGPoint(x: x - height * 0.14, y: base - height * 0.58))
        cap.addLine(to: CGPoint(x: x + height * 0.14, y: base - height * 0.58))
        cap.closeSubpath()
        c.fill(cap, with: .color(Color.white.opacity(0.9)))
    }

    // MARK: Snow Day

    static func snowman(_ c: GraphicsContext, x: CGFloat, y: CGFloat, t: Double) {
        let edge = Color(hex: "DCE6EE")
        c.fill(Path(ellipseIn: CGRect(x: x - 40, y: y - 4, width: 80, height: 12)), with: .color(Color.black.opacity(0.06)))
        for (cy, r) in [(y - 30, CGFloat(32)), (y - 80, CGFloat(24)), (y - 118, CGFloat(18))] {
            let rect = CGRect(x: x - r, y: cy - r, width: r * 2, height: r * 2)
            c.fill(Path(ellipseIn: rect), with: .color(.white))
            c.stroke(Path(ellipseIn: rect), with: .color(edge), lineWidth: 2)
        }
        let ink = Color(hex: "2A1B11")
        dot(c, x - 6, y - 122, 2.4, ink)
        dot(c, x + 6, y - 122, 2.4, ink)
        var nose = Path()
        nose.move(to: CGPoint(x: x, y: y - 116))
        nose.addLine(to: CGPoint(x: x + 16, y: y - 113))
        nose.addLine(to: CGPoint(x: x, y: y - 111))
        nose.closeSubpath()
        c.fill(nose, with: .color(Color(hex: "E8853A")))
        var smile = Path()
        smile.move(to: CGPoint(x: x - 7, y: y - 108))
        smile.addQuadCurve(to: CGPoint(x: x + 7, y: y - 108), control: CGPoint(x: x, y: y - 104))
        c.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        for dy in [CGFloat(80), 68, 56] { dot(c, x, y - dy, 2.4, ink) }

        // Scarf, its tail flutters.
        let red = Color(hex: "E8503F")
        var wrap = Path()
        wrap.move(to: CGPoint(x: x - 20, y: y - 100))
        wrap.addQuadCurve(to: CGPoint(x: x + 20, y: y - 100), control: CGPoint(x: x, y: y - 93))
        wrap.addLine(to: CGPoint(x: x + 20, y: y - 94))
        wrap.addQuadCurve(to: CGPoint(x: x - 20, y: y - 94), control: CGPoint(x: x, y: y - 86))
        wrap.closeSubpath()
        c.fill(wrap, with: .color(red))
        let flutter = CGFloat(sin(t * 2.2) * 3)
        var tail = Path()
        tail.move(to: CGPoint(x: x + 10, y: y - 95))
        tail.addLine(to: CGPoint(x: x + 18, y: y - 95))
        tail.addLine(to: CGPoint(x: x + 16 + flutter, y: y - 74))
        tail.addLine(to: CGPoint(x: x + 9 + flutter, y: y - 76))
        tail.closeSubpath()
        c.fill(tail, with: .color(red))

        let twig = Color(hex: "7A4E2E")
        var arms = Path()
        arms.move(to: CGPoint(x: x - 22, y: y - 82))
        arms.addLine(to: CGPoint(x: x - 48, y: y - 100))
        arms.move(to: CGPoint(x: x - 40, y: y - 95))
        arms.addLine(to: CGPoint(x: x - 44, y: y - 106))
        arms.move(to: CGPoint(x: x + 22, y: y - 82))
        arms.addLine(to: CGPoint(x: x + 48, y: y - 98))
        c.stroke(arms, with: .color(twig), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let hat = Color(hex: "2A3A55")
        c.fill(Path(roundedRect: CGRect(x: x - 14, y: y - 150, width: 28, height: 18), cornerRadius: 2), with: .color(hat))
        c.fill(Path(roundedRect: CGRect(x: x - 20, y: y - 134, width: 40, height: 5), cornerRadius: 2), with: .color(hat))
        c.fill(Path(CGRect(x: x - 14, y: y - 138, width: 28, height: 4)), with: .color(red))
    }

    // MARK: Summer

    static func sun(_ c: GraphicsContext, x: CGFloat, y: CGFloat, t: Double) {
        dot(c, x, y, 58, Color(hex: "FFD36B").opacity(0.18))
        let turn = t * 0.15
        for i in 0..<12 {
            let angle = Double(i) * Double.pi / 6 + turn
            var ray = Path()
            ray.move(to: CGPoint(x: x + CGFloat(cos(angle)) * 34, y: y + CGFloat(sin(angle)) * 34))
            ray.addLine(to: CGPoint(x: x + CGFloat(cos(angle)) * 46, y: y + CGFloat(sin(angle)) * 46))
            c.stroke(ray, with: .color(Color(hex: "FFC63D")), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
        dot(c, x, y, 26, Color(hex: "FFCF4A"))
        dot(c, x - 8, y - 8, 9, Color(hex: "FFE08A"))
    }

    static func cloud(_ c: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        var g = c
        g.translateBy(x: x, y: y)
        g.scaleBy(x: scale, y: scale)
        g.fill(Path(ellipseIn: CGRect(x: -34, y: -14, width: 68, height: 28)), with: .color(.white))
        dot(g, -14, -8, 14, .white)
        dot(g, 8, -14, 18, .white)
    }

    static func kite(_ c: GraphicsContext, x: CGFloat, y: CGFloat, t: Double) {
        let bob = CGFloat(sin(t * 0.9) * 8)
        let tilt = sin(t * 0.7) * 6
        var g = c
        g.translateBy(x: x, y: y + bob)
        g.rotate(by: .degrees(tilt))
        var body = Path()
        body.move(to: CGPoint(x: 0, y: -30))
        body.addLine(to: CGPoint(x: 20, y: 0))
        body.addLine(to: CGPoint(x: 0, y: 34))
        body.addLine(to: CGPoint(x: -20, y: 0))
        body.closeSubpath()
        g.fill(body, with: .color(Color(hex: "E8503F")))
        var topRight = Path()
        topRight.move(to: CGPoint(x: 0, y: -30))
        topRight.addLine(to: CGPoint(x: 20, y: 0))
        topRight.addLine(to: CGPoint(x: 0, y: 0))
        topRight.closeSubpath()
        g.fill(topRight, with: .color(Color(hex: "FFD36B")))
        var bottomLeft = Path()
        bottomLeft.move(to: CGPoint(x: 0, y: 0))
        bottomLeft.addLine(to: CGPoint(x: -20, y: 0))
        bottomLeft.addLine(to: CGPoint(x: 0, y: 34))
        bottomLeft.closeSubpath()
        g.fill(bottomLeft, with: .color(Color(hex: "3B7DD8")))
        let wave = CGFloat(sin(t * 2.0) * 8)
        var tail = Path()
        tail.move(to: CGPoint(x: 0, y: 34))
        tail.addQuadCurve(to: CGPoint(x: 6, y: 80), control: CGPoint(x: -10 - wave, y: 60))
        tail.addQuadCurve(to: CGPoint(x: -4, y: 120), control: CGPoint(x: 18 + wave, y: 100))
        g.stroke(tail, with: .color(Color(hex: "5B3A1E")), lineWidth: 1.2)
        let bows: [Color] = [Color(hex: "E8503F"), Color(hex: "FFD36B"), Color(hex: "3B7DD8")]
        for (i, point) in [CGPoint(x: -6 - wave * 0.4, y: 52), CGPoint(x: 8, y: 76), CGPoint(x: 4 + wave * 0.4, y: 102)].enumerated() {
            var bow = Path()
            bow.move(to: CGPoint(x: point.x - 5, y: point.y - 3))
            bow.addLine(to: point)
            bow.addLine(to: CGPoint(x: point.x - 5, y: point.y + 3))
            bow.closeSubpath()
            bow.move(to: CGPoint(x: point.x + 5, y: point.y - 3))
            bow.addLine(to: point)
            bow.addLine(to: CGPoint(x: point.x + 5, y: point.y + 3))
            bow.closeSubpath()
            g.fill(bow, with: .color(bows[i]))
        }
    }

    static func butterfly(_ c: GraphicsContext, x: CGFloat, y: CGFloat, color: Color, t: Double) {
        let flap = CGFloat(0.45 + 0.55 * abs(sin(t * 10)))
        var g = c
        g.translateBy(x: x, y: y)
        var wings = g
        wings.scaleBy(x: flap, y: 1)
        wings.fill(Path(ellipseIn: CGRect(x: -13, y: -13, width: 14, height: 18)), with: .color(color))
        wings.fill(Path(ellipseIn: CGRect(x: -1, y: -13, width: 14, height: 18)), with: .color(color))
        wings.fill(Path(ellipseIn: CGRect(x: -10, y: 0, width: 10, height: 12)), with: .color(color.opacity(0.8)))
        wings.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 10, height: 12)), with: .color(color.opacity(0.8)))
        g.fill(Path(roundedRect: CGRect(x: -1.2, y: -8, width: 2.4, height: 18), cornerRadius: 1.2),
               with: .color(Color(hex: "3B2618")))
    }

    // MARK: Spring

    static func egg(_ c: GraphicsContext, x: CGFloat, y: CGFloat, color: Color, stripe: Color) {
        c.fill(Path(ellipseIn: CGRect(x: x - 10, y: y - 13, width: 20, height: 26)), with: .color(color))
        var zig = Path()
        zig.move(to: CGPoint(x: x - 9, y: y - 2))
        zig.addQuadCurve(to: CGPoint(x: x, y: y - 2), control: CGPoint(x: x - 4, y: y - 6))
        zig.addQuadCurve(to: CGPoint(x: x + 9, y: y - 2), control: CGPoint(x: x + 4, y: y + 2))
        c.stroke(zig, with: .color(stripe), lineWidth: 2.5)
        dot(c, x - 4, y + 6, 1.6, stripe)
        dot(c, x + 4, y + 6, 1.6, stripe)
    }

    static func tulip(_ c: GraphicsContext, x: CGFloat, y: CGFloat, color: Color, sway: Double) {
        var g = c
        g.translateBy(x: x, y: y)
        g.rotate(by: .degrees(sway))
        var stem = Path()
        stem.move(to: .zero)
        stem.addLine(to: CGPoint(x: 0, y: -36))
        g.stroke(stem, with: .color(Color(hex: "4E8A3E")), lineWidth: 3)
        var leafShape = Path()
        leafShape.move(to: CGPoint(x: 0, y: -12))
        leafShape.addQuadCurve(to: CGPoint(x: -12, y: -30), control: CGPoint(x: -12, y: -20))
        leafShape.addQuadCurve(to: CGPoint(x: 0, y: -16), control: CGPoint(x: -4, y: -24))
        leafShape.closeSubpath()
        g.fill(leafShape, with: .color(Color(hex: "5E9A4C")))
        var bloom = Path()
        bloom.move(to: CGPoint(x: -9, y: -44))
        bloom.addQuadCurve(to: CGPoint(x: 0, y: -30), control: CGPoint(x: -10, y: -30))
        bloom.addQuadCurve(to: CGPoint(x: 9, y: -44), control: CGPoint(x: 10, y: -30))
        bloom.addLine(to: CGPoint(x: 5, y: -38))
        bloom.addLine(to: CGPoint(x: 0, y: -46))
        bloom.addLine(to: CGPoint(x: -5, y: -38))
        bloom.closeSubpath()
        g.fill(bloom, with: .color(color))
    }

    // MARK: Autumn

    static func pumpkin(_ c: GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, face: Bool, t: Double) {
        c.fill(Path(roundedRect: CGRect(x: x - 3, y: y - r - 8, width: 6, height: 10), cornerRadius: 2),
               with: .color(Color(hex: "5E7A2E")))
        let lobes: [(CGFloat, CGFloat, Color)] = [
            (-r * 0.5, r * 0.6, Color(hex: "E07A1F")), (r * 0.5, r * 0.6, Color(hex: "E07A1F")), (0, r * 0.62, Color(hex: "F08A2A"))
        ]
        for (dx, rx, color) in lobes {
            c.fill(Path(ellipseIn: CGRect(x: x + dx - rx, y: y - r * 0.8, width: rx * 2, height: r * 1.6)), with: .color(color))
        }
        var vine = Path()
        vine.move(to: CGPoint(x: x + 4, y: y - r * 0.8))
        vine.addQuadCurve(to: CGPoint(x: x + 18, y: y - r + 2), control: CGPoint(x: x + 14, y: y - r - 6))
        c.stroke(vine, with: .color(Color(hex: "5E7A2E")), lineWidth: 2)
        guard face else { return }

        // Friendly jack-o-lantern with a flickering candle glow.
        let flicker = 0.75 + 0.15 * sin(t * 9.1) + 0.10 * sin(t * 23.7 + 1.3)
        let glow = Color(hex: "FFD36B")
        dot(c, x, y, r * 1.3, glow.opacity(0.18 * flicker))
        var eyes = Path()
        eyes.move(to: CGPoint(x: x - 11, y: y - 5))
        eyes.addLine(to: CGPoint(x: x - 5, y: y - 11))
        eyes.addLine(to: CGPoint(x: x - 1, y: y - 4))
        eyes.closeSubpath()
        eyes.move(to: CGPoint(x: x + 11, y: y - 5))
        eyes.addLine(to: CGPoint(x: x + 5, y: y - 11))
        eyes.addLine(to: CGPoint(x: x + 1, y: y - 4))
        eyes.closeSubpath()
        c.fill(eyes, with: .color(glow.opacity(flicker)))
        var grin = Path()
        grin.move(to: CGPoint(x: x - 12, y: y + 4))
        grin.addQuadCurve(to: CGPoint(x: x + 12, y: y + 4), control: CGPoint(x: x, y: y + 16))
        grin.addQuadCurve(to: CGPoint(x: x - 12, y: y + 4), control: CGPoint(x: x, y: y + 8))
        grin.closeSubpath()
        c.fill(grin, with: .color(glow.opacity(flicker)))
    }

    // MARK: Celebrations

    static func balloon(_ c: GraphicsContext, x: CGFloat, y: CGFloat, color: Color, t: Double, seed: Double) {
        let sway = CGFloat(sin(t * 1.3 + seed) * 4)
        var string = Path()
        string.move(to: CGPoint(x: x, y: y + 22))
        string.addQuadCurve(to: CGPoint(x: x + 4 - sway, y: y + 60), control: CGPoint(x: x - 6 + sway, y: y + 40))
        c.stroke(string, with: .color(Color(hex: "8A7A6A")), lineWidth: 1)
        c.fill(Path(ellipseIn: CGRect(x: x - 15, y: y - 19, width: 30, height: 38)), with: .color(color))
        var knot = Path()
        knot.move(to: CGPoint(x: x - 3, y: y + 18))
        knot.addLine(to: CGPoint(x: x + 3, y: y + 18))
        knot.addLine(to: CGPoint(x: x, y: y + 23))
        knot.closeSubpath()
        c.fill(knot, with: .color(color))
        c.fill(Path(ellipseIn: CGRect(x: x - 9, y: y - 13, width: 8, height: 12)), with: .color(Color.white.opacity(0.35)))
    }

    static func cake(_ c: GraphicsContext, x: CGFloat, y: CGFloat, t: Double) {
        c.fill(Path(ellipseIn: CGRect(x: x - 44, y: y - 6, width: 88, height: 12)), with: .color(Color(hex: "E8DCCB")))
        c.fill(Path(roundedRect: CGRect(x: x - 36, y: y - 34, width: 72, height: 32), cornerRadius: 6), with: .color(Color(hex: "F3B3C6")))
        c.fill(Path(roundedRect: CGRect(x: x - 28, y: y - 58, width: 56, height: 26), cornerRadius: 6), with: .color(Color(hex: "FBE3EA")))
        var frosting = Path()
        frosting.move(to: CGPoint(x: x - 36, y: y - 32))
        frosting.addLine(to: CGPoint(x: x + 36, y: y - 32))
        frosting.addLine(to: CGPoint(x: x + 36, y: y - 26))
        for i in 0..<6 {
            let xr = x + 36 - CGFloat(i) * 12
            frosting.addQuadCurve(to: CGPoint(x: xr - 12, y: y - 26), control: CGPoint(x: xr - 6, y: y - 18))
        }
        frosting.closeSubpath()
        c.fill(frosting, with: .color(.white))
        let candles: [Color] = [Color(hex: "E8503F"), Color(hex: "3B7DD8"), Color(hex: "FFD36B")]
        for (i, color) in candles.enumerated() {
            let cx = x - 14 + CGFloat(i) * 14
            c.fill(Path(roundedRect: CGRect(x: cx - 2, y: y - 74, width: 4, height: 16), cornerRadius: 1), with: .color(color))
            let flick = CGFloat(sin(t * 12 + Double(i)) * 1.2)
            var flame = Path()
            flame.move(to: CGPoint(x: cx + flick, y: y - 84))
            flame.addQuadCurve(to: CGPoint(x: cx, y: y - 74), control: CGPoint(x: cx + 4, y: y - 78))
            flame.addQuadCurve(to: CGPoint(x: cx + flick, y: y - 84), control: CGPoint(x: cx - 4, y: y - 78))
            flame.closeSubpath()
            c.fill(flame, with: .color(Color(hex: "FFB43D")))
        }
    }

    static func gradCap(_ c: GraphicsContext, x: CGFloat, y: CGFloat, angle: Double) {
        var g = c
        g.translateBy(x: x, y: y)
        g.rotate(by: .degrees(angle))
        var base = Path()
        base.move(to: CGPoint(x: -12, y: 2))
        base.addLine(to: CGPoint(x: -12, y: 12))
        base.addQuadCurve(to: CGPoint(x: 12, y: 12), control: CGPoint(x: 0, y: 18))
        base.addLine(to: CGPoint(x: 12, y: 2))
        base.closeSubpath()
        g.fill(base, with: .color(Color(hex: "2A2F3A")))
        var board = Path()
        board.move(to: CGPoint(x: 0, y: -10))
        board.addLine(to: CGPoint(x: 26, y: 0))
        board.addLine(to: CGPoint(x: 0, y: 10))
        board.addLine(to: CGPoint(x: -26, y: 0))
        board.closeSubpath()
        g.fill(board, with: .color(Color(hex: "363D4C")))
        var tassel = Path()
        tassel.move(to: .zero)
        tassel.addLine(to: CGPoint(x: 18, y: 4))
        tassel.addLine(to: CGPoint(x: 18, y: 16))
        g.stroke(tassel, with: .color(Color(hex: "E3B04B")), lineWidth: 2)
        dot(g, 18, 18, 3, Color(hex: "E3B04B"))
    }

    static func bunting(_ c: GraphicsContext, from x0: CGFloat, to x1: CGFloat, y: CGFloat, colors: [Color], leafy: Bool) {
        let mid = (x0 + x1) / 2
        var rope = Path()
        rope.move(to: CGPoint(x: x0, y: y))
        rope.addQuadCurve(to: CGPoint(x: x1, y: y), control: CGPoint(x: mid, y: y + 24))
        c.stroke(rope, with: .color(Color(hex: "8A7A6A")), lineWidth: 1.2)
        let count = 9
        for i in 0..<count {
            let u = (CGFloat(i) + 0.5) / CGFloat(count)
            let a = (1 - u) * (1 - u)
            let b = 2 * u * (1 - u)
            let px = a * x0 + b * mid + u * u * x1
            let py = y + b * 24
            let color = colors[i % colors.count]
            if leafy {
                var l = c
                l.translateBy(x: px, y: py + 9)
                l.rotate(by: .degrees(Double(i % 2 == 0 ? 15 : -15)))
                l.fill(leafPath(size: 9), with: .color(color))
            } else {
                var flag = Path()
                flag.move(to: CGPoint(x: px - 8, y: py))
                flag.addLine(to: CGPoint(x: px + 8, y: py))
                flag.addLine(to: CGPoint(x: px, y: py + 16))
                flag.closeSubpath()
                c.fill(flag, with: .color(color))
            }
        }
    }

    /// Twinkling string lights across the top (Christmas pages).
    static func stringLights(_ c: GraphicsContext, size: CGSize, y: CGFloat, t: Double) {
        let swags = 4
        let sag: CGFloat = 20
        let w = size.width
        var wire = Path()
        for k in 0..<swags {
            let xa = w * CGFloat(k) / CGFloat(swags)
            let xb = w * CGFloat(k + 1) / CGFloat(swags)
            if k == 0 { wire.move(to: CGPoint(x: xa, y: y)) }
            wire.addQuadCurve(to: CGPoint(x: xb, y: y), control: CGPoint(x: (xa + xb) / 2, y: y + 2 * sag))
        }
        c.stroke(wire, with: .color(Color(hex: "5B3A1E").opacity(0.5)), lineWidth: 1.2)
        let colors: [Color] = [Color(hex: "E8503F"), Color(hex: "FFD36B"), Color(hex: "2F7D4F"), Color(hex: "7FC8F8")]
        var n = 0
        for k in 0..<swags {
            let xa = w * CGFloat(k) / CGFloat(swags)
            let xb = w * CGFloat(k + 1) / CGFloat(swags)
            for u in [0.2, 0.5, 0.8] {
                let uu = CGFloat(u)
                let px = xa + (xb - xa) * uu
                let py = y + 4 * sag * uu * (1 - uu)
                let twinkle = 0.55 + 0.45 * sin(t * 1.7 + Double(n) * 1.3)
                let color = colors[n % colors.count]
                dot(c, px, py + 4, 8, color.opacity(0.25 * twinkle))
                c.fill(Path(ellipseIn: CGRect(x: px - 2.5, y: py, width: 5, height: 7)), with: .color(color.opacity(0.5 + 0.5 * twinkle)))
                n += 1
            }
        }
    }

    /// Gold four point sparkles that pulse in place.
    static func sparkles(_ c: GraphicsContext, size: CGSize, t: Double, count: Int) {
        for i in 0..<count {
            let fi = Double(i)
            let x = CGFloat(frac(fi * 0.381 + 0.17)) * size.width
            let y = CGFloat(0.12 + frac(fi * 0.613) * 0.75) * size.height
            let pulse = max(0, sin(t * 1.6 + fi * 1.9))
            let r = CGFloat(3 + 5 * pulse)
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            c.fill(SparkleShape().path(in: rect), with: .color(Color(hex: "FFC63D").opacity(0.25 + 0.6 * pulse)))
        }
    }
}
