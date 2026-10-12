//
//  WinterScene.swift
//  Giftly
//
//  Giftly's own winter / Christmas atmosphere. A snowy pine, a growing stack of
//  wrapped gifts, elves that peek in and out from behind the tree, a reindeer
//  that strolls across, and drifting snow + sparkles. All hand-drawn in Canvas,
//  clock-driven via AtmosphereEngine, and fully Reduce-Motion safe.
//
//  This is NOT a copy of any other app's wildlife — the cast (elves, reindeer,
//  gift stack, candy-stripe ribbons) is specific to a gifting app.
//

import SwiftUI

// MARK: - Snowy Pine Tree

/// A full, snow dusted pine: five scalloped tiers with a shaded side, snow on
/// every scallop, swags of twinkling lights, ornaments, and a glowing star.
/// Anchored toward the right edge, base at the bottom of the screen.
struct GiftlyPineTree: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { ctx, size in
                    GiftlyPineTree.draw(ctx, size: size, t: 0)
                }
            } else {
                // Lights only need a gentle twinkle: 12fps is plenty.
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                    Canvas { ctx, size in
                        GiftlyPineTree.draw(ctx, size: size, t: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
    }

    private struct Tier {
        let top: CGFloat
        let bottom: CGFloat
        let half: CGFloat
        let scallops: Int
    }

    static func draw(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let cx: CGFloat = size.width * 0.80
        let base: CGFloat = size.height - 8

        let needle = Color(hex: "2E7A4A")
        let needleAlt = Color(hex: "2A6F43")
        let needleShade = Color(hex: "1B5132")

        // Snow mound + trunk
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 120, y: base - 12, width: 240, height: 28)), with: .color(.white))
        ctx.fill(Path(roundedRect: CGRect(x: cx - 11, y: base - 48, width: 22, height: 48), cornerRadius: 3),
                 with: .color(Color(hex: "6B4428")))
        ctx.fill(Path(CGRect(x: cx - 11, y: base - 48, width: 8, height: 48)), with: .color(Color(hex: "7E5233")))

        let tiers: [Tier] = [
            Tier(top: base - 150, bottom: base - 40, half: 108, scallops: 6),
            Tier(top: base - 215, bottom: base - 110, half: 90, scallops: 5),
            Tier(top: base - 275, bottom: base - 178, half: 72, scallops: 4),
            Tier(top: base - 325, bottom: base - 240, half: 54, scallops: 3),
            Tier(top: base - 362, bottom: base - 298, half: 34, scallops: 2)
        ]
        for (i, tier) in tiers.enumerated() {
            let fill: Color = i % 2 == 0 ? needle : needleAlt
            ctx.fill(tierPath(cx: cx, tier: tier), with: .color(fill))
            ctx.fill(shadePath(cx: cx, tier: tier), with: .color(needleShade.opacity(0.55)))
            drawSnow(ctx, cx: cx, tier: tier)
        }
        for i in 0..<4 {
            drawGarland(ctx, cx: cx, tier: tiers[i], seed: i, t: t)
        }
        drawOrnaments(ctx, cx: cx, base: base)
        drawStar(ctx, center: CGPoint(x: cx, y: base - 366), r: 14, t: t)
    }

    private static func tierPath(cx: CGFloat, tier: Tier) -> Path {
        let h: CGFloat = tier.bottom - tier.top
        let step: CGFloat = 2 * tier.half / CGFloat(tier.scallops)
        var p = Path()
        p.move(to: CGPoint(x: cx, y: tier.top))
        p.addQuadCurve(to: CGPoint(x: cx - tier.half, y: tier.bottom),
                       control: CGPoint(x: cx - tier.half * 0.30, y: tier.top + h * 0.55))
        for i in 0..<tier.scallops {
            let x0: CGFloat = cx - tier.half + CGFloat(i) * step
            let x1: CGFloat = x0 + step
            p.addQuadCurve(to: CGPoint(x: x1, y: tier.bottom), control: CGPoint(x: (x0 + x1) / 2, y: tier.bottom + 11))
        }
        p.addQuadCurve(to: CGPoint(x: cx, y: tier.top),
                       control: CGPoint(x: cx + tier.half * 0.30, y: tier.top + h * 0.55))
        p.closeSubpath()
        return p
    }

    /// The right side, in shadow (light comes from the upper left).
    private static func shadePath(cx: CGFloat, tier: Tier) -> Path {
        let h: CGFloat = tier.bottom - tier.top
        let step: CGFloat = 2 * tier.half / CGFloat(tier.scallops)
        var p = Path()
        p.move(to: CGPoint(x: cx, y: tier.top))
        p.addQuadCurve(to: CGPoint(x: cx + tier.half, y: tier.bottom),
                       control: CGPoint(x: cx + tier.half * 0.30, y: tier.top + h * 0.55))
        for i in 0..<(tier.scallops / 2) {
            let x1: CGFloat = cx + tier.half - CGFloat(i + 1) * step
            let x0: CGFloat = x1 + step
            p.addQuadCurve(to: CGPoint(x: x1, y: tier.bottom), control: CGPoint(x: (x0 + x1) / 2, y: tier.bottom + 11))
        }
        p.addQuadCurve(to: CGPoint(x: cx, y: tier.top),
                       control: CGPoint(x: cx + tier.half * 0.1, y: tier.top + h * 0.6))
        p.closeSubpath()
        return p
    }

    /// A pillow of snow on top of every scallop.
    private static func drawSnow(_ ctx: GraphicsContext, cx: CGFloat, tier: Tier) {
        let step: CGFloat = 2 * tier.half / CGFloat(tier.scallops)
        for i in 0..<tier.scallops {
            let x0: CGFloat = cx - tier.half + CGFloat(i) * step + 3
            let x1: CGFloat = x0 + step - 6
            let mid: CGFloat = (x0 + x1) / 2
            var snow = Path()
            snow.move(to: CGPoint(x: x0, y: tier.bottom - 1))
            snow.addQuadCurve(to: CGPoint(x: x1, y: tier.bottom - 1), control: CGPoint(x: mid, y: tier.bottom + 6))
            snow.addQuadCurve(to: CGPoint(x: x0, y: tier.bottom - 1), control: CGPoint(x: mid, y: tier.bottom - 6))
            snow.closeSubpath()
            ctx.fill(snow, with: .color(Color.white.opacity(0.92)))
        }
    }

    /// A swag of lights across a tier. Each bulb twinkles on its own rhythm.
    private static func drawGarland(_ ctx: GraphicsContext, cx: CGFloat, tier: Tier, seed: Int, t: Double) {
        let y: CGFloat = tier.bottom - 22
        let start = CGPoint(x: cx - tier.half * 0.9, y: y)
        let control = CGPoint(x: cx, y: y + 18)
        let end = CGPoint(x: cx + tier.half * 0.9, y: y - 6)

        var wire = Path()
        wire.move(to: start)
        wire.addQuadCurve(to: end, control: control)
        ctx.stroke(wire, with: .color(Color(hex: "5B3A1E").opacity(0.6)), lineWidth: 1.2)

        let colors: [Color] = [Color(hex: "FFD36B"), Color(hex: "E8503F"), Color(hex: "7FC8F8"), Color(hex: "9BE07A")]
        for i in 0..<7 {
            let u: CGFloat = (CGFloat(i) + 0.5) / 7
            let a: CGFloat = (1 - u) * (1 - u)
            let b: CGFloat = 2 * u * (1 - u)
            let c: CGFloat = u * u
            let bx: CGFloat = a * start.x + b * control.x + c * end.x
            let by: CGFloat = a * start.y + b * control.y + c * end.y + 3
            let color = colors[(i + seed) % colors.count]
            let twinkle: Double = 0.55 + 0.45 * sin(t * 2.0 + Double(i * 7 + seed * 3) * 0.9)
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 7, y: by - 7, width: 14, height: 14)),
                     with: .color(color.opacity(0.28 * twinkle)))
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 2.6, y: by - 3.4, width: 5.2, height: 6.8)),
                     with: .color(color.opacity(0.55 + 0.45 * twinkle)))
        }
    }

    private static func drawOrnaments(_ ctx: GraphicsContext, cx: CGFloat, base: CGFloat) {
        let red = Color(hex: "E8503F")
        let blue = Color(hex: "3B7DD8")
        let gold = Color(hex: "E3B04B")
        let spots: [(CGFloat, CGFloat, Color)] = [
            (cx - 52, base - 62, red), (cx + 40, base - 70, blue), (cx - 18, base - 128, gold),
            (cx + 30, base - 140, red), (cx - 36, base - 196, blue), (cx + 16, base - 205, gold),
            (cx - 6, base - 262, red)
        ]
        for (x, y, color) in spots {
            ctx.fill(Path(CGRect(x: x - 2, y: y - 9, width: 4, height: 3)), with: .color(Color(hex: "C9A24A")))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 6.5, y: y - 6.5, width: 13, height: 13)), with: .color(color))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 3.8, y: y - 4.3, width: 3.6, height: 3.6)),
                     with: .color(Color.white.opacity(0.8)))
        }
    }

    private static func drawStar(_ ctx: GraphicsContext, center: CGPoint, r: CGFloat, t: Double) {
        let glow: Double = 0.20 + 0.08 * sin(t * 1.6)
        let halo: CGFloat = r * 2.4
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
                 with: .color(Color(hex: "FFD36B").opacity(glow)))
        var star = Path()
        for i in 0..<10 {
            let angle: Double = Double(i) * Double.pi / 5 - Double.pi / 2
            let radius: CGFloat = i % 2 == 0 ? r : r * 0.45
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(Color(hex: "FFCF4A")))
        ctx.stroke(star, with: .color(Color(hex: "E6A92A")), lineWidth: 1)
    }
}

// MARK: - Gift stack at the tree's foot (grows with picked gifts)

struct GiftlyGiftStack: View {
    /// 0...1 how full the gift pile is (driven by occasion progress).
    var fullness: Double = 1.0

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            // Box palette
            let boxes: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, box: Color, ribbon: Color, minFull: Double)] = [
                (w * 0.14, h - 46, 56, 46, Color(red: 0.86, green: 0.20, blue: 0.24), Color(red: 0.98, green: 0.84, blue: 0.30), 0.0),
                (w * 0.42, h - 38, 42, 38, Color(red: 0.16, green: 0.52, blue: 0.30), Color(red: 0.95, green: 0.96, blue: 0.99), 0.34),
                (w * 0.30, h - 72, 38, 34, Color(red: 0.38, green: 0.60, blue: 0.95), Color(red: 0.98, green: 0.84, blue: 0.30), 0.67),
            ]
            for b in boxes where fullness >= b.minFull {
                let rect = CGRect(x: b.x, y: b.y, width: b.w, height: b.h)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(b.box))
                // vertical ribbon
                context.fill(Path(CGRect(x: b.x + b.w/2 - 3, y: b.y, width: 6, height: b.h)), with: .color(b.ribbon))
                // horizontal ribbon
                context.fill(Path(CGRect(x: b.x, y: b.y + b.h/2 - 3, width: b.w, height: 6)), with: .color(b.ribbon))
                // bow
                let bowC = CGRect(x: b.x + b.w/2 - 5, y: b.y - 5, width: 10, height: 8)
                context.fill(Path(ellipseIn: bowC), with: .color(b.ribbon))
            }
        }
        .drawingGroup()
    }
}

// MARK: - Peeking Elf (pops in and out from behind the tree)

struct GiftlyElf: View {
    let visibility: Double     // 0 hidden, 1 fully up
    var flip: Bool = false     // face the other way
    var style: ElfStyle = ElfStyle.pip
    var pose: ElfPose = .idle

    var body: some View {
        // The workshop crew peeks out from behind the tree.
        ElfView(pose: pose, size: 50, style: style)
            .frame(width: 54, height: 70)
            .scaleEffect(x: flip ? -1 : 1)
            // "pop" up from behind: slide + fade + a little overshoot scale
            .scaleEffect(0.9 + 0.1 * visibility, anchor: .bottom)
            .offset(y: (1 - visibility) * 60)
            .opacity(visibility)
    }
}

// MARK: - Strolling Reindeer

/// A friendly reindeer in side view: branching antlers, a soft belly and
/// chest, a red collar with a gold bell, and legs that step as it walks.
/// (Brown nose on purpose: a glowing red nose belongs to someone famous.)
struct GiftlyReindeer: View {
    var walking: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion || !walking {
                Canvas { ctx, size in
                    GiftlyReindeer.draw(ctx, size: size, t: 0)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { ctx, size in
                        GiftlyReindeer.draw(ctx, size: size, t: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .frame(width: 112, height: 102)
    }

    /// Drawn on a 140 x 128 grid (antlers reach above the head, so the grid
    /// starts 18 above the drawing's own origin).
    static func draw(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        var c = ctx
        let s: CGFloat = size.width / 140
        c.scaleBy(x: s, y: s)
        c.translateBy(x: 0, y: 18)

        let body = Color(hex: "9A6A43")
        let dark = Color(hex: "7A5132")
        let belly = Color(hex: "E2C49A")
        let muzzle = Color(hex: "C99A6E")
        let antler = Color(hex: "B8956A")
        let hoof = Color(hex: "3B2618")
        let ink = Color(hex: "2A1B11")
        let step: Double = sin(t * 6)

        c.fill(Path(ellipseIn: CGRect(x: 20, y: 100, width: 88, height: 8)), with: .color(Color.black.opacity(0.18)))

        // Far legs (darker), then tail, body, belly, near legs.
        drawLeg(c, x: 46, angle: step * 14, color: dark, hoof: hoof)
        drawLeg(c, x: 82, angle: -step * 14, color: dark, hoof: hoof)
        var tail = c
        tail.translateBy(x: 25, y: 50)
        tail.rotate(by: .degrees(-30))
        tail.fill(Path(ellipseIn: CGRect(x: -7, y: -5, width: 14, height: 10)), with: .color(Color(hex: "F4EADB")))
        c.fill(Path(ellipseIn: CGRect(x: 24, y: 39, width: 76, height: 42)), with: .color(body))
        c.fill(Path(ellipseIn: CGRect(x: 36, y: 61, width: 56, height: 18)), with: .color(belly.opacity(0.9)))
        drawLeg(c, x: 38, angle: -step * 14, color: body, hoof: hoof)
        drawLeg(c, x: 86, angle: step * 14, color: body, hoof: hoof)

        // Neck with a lighter front.
        var neck = Path()
        neck.move(to: CGPoint(x: 84, y: 52))
        neck.addQuadCurve(to: CGPoint(x: 104, y: 24), control: CGPoint(x: 94, y: 30))
        neck.addLine(to: CGPoint(x: 116, y: 34))
        neck.addQuadCurve(to: CGPoint(x: 98, y: 64), control: CGPoint(x: 104, y: 46))
        neck.closeSubpath()
        c.fill(neck, with: .color(body))
        var front = Path()
        front.move(to: CGPoint(x: 92, y: 58))
        front.addQuadCurve(to: CGPoint(x: 106, y: 38), control: CGPoint(x: 98, y: 44))
        front.addLine(to: CGPoint(x: 108, y: 44))
        front.addQuadCurve(to: CGPoint(x: 100, y: 64), control: CGPoint(x: 101, y: 52))
        front.closeSubpath()
        c.fill(front, with: .color(belly.opacity(0.85)))

        // Collar and bell.
        var collar = Path()
        collar.move(to: CGPoint(x: 90, y: 44))
        collar.addQuadCurve(to: CGPoint(x: 110, y: 40), control: CGPoint(x: 100, y: 48))
        collar.addLine(to: CGPoint(x: 112, y: 45))
        collar.addQuadCurve(to: CGPoint(x: 92, y: 50), control: CGPoint(x: 101, y: 54))
        collar.closeSubpath()
        c.fill(collar, with: .color(Workshop.berry))
        c.fill(Path(ellipseIn: CGRect(x: 97, y: 48, width: 8, height: 8)), with: .color(Workshop.brass))

        // Antlers: the far one darker, behind.
        let antlerStyle = StrokeStyle(lineWidth: 3.2, lineCap: .round)
        var farAntler = Path()
        farAntler.move(to: CGPoint(x: 104, y: 16))
        farAntler.addQuadCurve(to: CGPoint(x: 102, y: -8), control: CGPoint(x: 98, y: 4))
        farAntler.move(to: CGPoint(x: 101, y: 3))
        farAntler.addQuadCurve(to: CGPoint(x: 90, y: -6), control: CGPoint(x: 94, y: 0))
        farAntler.move(to: CGPoint(x: 101, y: -3))
        farAntler.addQuadCurve(to: CGPoint(x: 110, y: -10), control: CGPoint(x: 106, y: -8))
        c.stroke(farAntler, with: .color(dark), style: antlerStyle)
        var nearAntler = Path()
        nearAntler.move(to: CGPoint(x: 110, y: 16))
        nearAntler.addQuadCurve(to: CGPoint(x: 120, y: -8), control: CGPoint(x: 112, y: 2))
        nearAntler.move(to: CGPoint(x: 113, y: 5))
        nearAntler.addQuadCurve(to: CGPoint(x: 126, y: 0), control: CGPoint(x: 120, y: 4))
        nearAntler.move(to: CGPoint(x: 116, y: -2))
        nearAntler.addQuadCurve(to: CGPoint(x: 116, y: -16), control: CGPoint(x: 114, y: -10))
        nearAntler.move(to: CGPoint(x: 119, y: -6))
        nearAntler.addQuadCurve(to: CGPoint(x: 130, y: -12), control: CGPoint(x: 126, y: -8))
        c.stroke(nearAntler, with: .color(antler), style: antlerStyle)

        // Head, muzzle, nose.
        c.fill(Path(ellipseIn: CGRect(x: 98, y: 13, width: 28, height: 22)), with: .color(body))
        c.fill(Path(ellipseIn: CGRect(x: 115, y: 22.5, width: 18, height: 13)), with: .color(muzzle))
        c.fill(Path(ellipseIn: CGRect(x: 127.4, y: 24, width: 7.2, height: 6)), with: .color(hoof))
        c.fill(Path(ellipseIn: CGRect(x: 129, y: 25, width: 2, height: 2)), with: .color(Color.white.opacity(0.6)))

        // Ear.
        var ear = Path()
        ear.move(to: CGPoint(x: 102, y: 16))
        ear.addQuadCurve(to: CGPoint(x: 88, y: 12), control: CGPoint(x: 92, y: 8))
        ear.addQuadCurve(to: CGPoint(x: 104, y: 21), control: CGPoint(x: 94, y: 20))
        ear.closeSubpath()
        c.fill(ear, with: .color(dark))

        // Eye, lid line, cheek.
        let blink: Bool = t.truncatingRemainder(dividingBy: 4.3) > 4.18
        if blink {
            var lid = Path()
            lid.move(to: CGPoint(x: 111.6, y: 21))
            lid.addQuadCurve(to: CGPoint(x: 116.4, y: 21), control: CGPoint(x: 114, y: 22.5))
            c.stroke(lid, with: .color(ink), lineWidth: 1.2)
        } else {
            c.fill(Path(ellipseIn: CGRect(x: 111.6, y: 18.2, width: 4.8, height: 5.6)), with: .color(ink))
            c.fill(Path(ellipseIn: CGRect(x: 114, y: 19, width: 1.8, height: 1.8)), with: .color(.white))
        }
        c.fill(Path(ellipseIn: CGRect(x: 116.5, y: 24.5, width: 5, height: 5)), with: .color(Color(hex: "EF8F8F").opacity(0.4)))
    }

    private static func drawLeg(_ ctx: GraphicsContext, x: CGFloat, angle: Double, color: Color, hoof: Color) {
        var leg = ctx
        leg.translateBy(x: x, y: 66)
        leg.rotate(by: .degrees(angle))
        leg.fill(Path(roundedRect: CGRect(x: -4, y: -2, width: 8, height: 36), cornerRadius: 4), with: .color(color))
        leg.fill(Path(roundedRect: CGRect(x: -4.5, y: 29, width: 9, height: 7), cornerRadius: 2), with: .color(hoof))
    }
}
