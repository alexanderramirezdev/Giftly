//
//  BoxBuddy.swift
//  Giftly
//
//  Pip outside the holidays: a little wrapped gift with a face. Each season
//  gets its own wrapping paper and accessory (Snow Day beanie and scarf,
//  Spring flower crown, Summer sunglasses, Autumn leaf and scarf). He
//  breathes, blinks, wiggles his bow, hops when searching and pops his lid
//  when cheering. At Christmas, Pip is the elf again (ElfView).
//
//  Drawn on the same 100 x 140 grid as ElfView so it drops into any spot
//  that shows Pip. Internally it uses a 300 x 420 design space (the SVG it
//  was sketched in) scaled down by 3.
//

import SwiftUI

enum BoxBuddy {

    private struct Wrap {
        let box: Color, lid: Color, ribbon: Color, ribbonShade: Color, knot: Color
        let pattern: Pattern, patternColor: Color
    }
    private enum Pattern { case dots, stripes, plaid }

    private static func wrap(for season: GiftlySeason) -> Wrap {
        switch season {
        case .snowDay:
            return Wrap(box: Color(hex: "4F86C6"), lid: Color(hex: "6A9DD6"), ribbon: .white,
                        ribbonShade: Color(hex: "DDE7F2"), knot: Color(hex: "FFD36B"),
                        pattern: .dots, patternColor: .white)
        case .spring:
            return Wrap(box: Color(hex: "EC7FA3"), lid: Color(hex: "F296B5"), ribbon: Color(hex: "9BE0C3"),
                        ribbonShade: Color(hex: "7CC9A9"), knot: Color(hex: "FFE07A"),
                        pattern: .dots, patternColor: Color(hex: "FFE3EC"))
        case .summer:
            return Wrap(box: Color(hex: "22A9A0"), lid: Color(hex: "3CBDB3"), ribbon: Color(hex: "FFD447"),
                        ribbonShade: Color(hex: "E9B92B"), knot: Color(hex: "FF7A59"),
                        pattern: .stripes, patternColor: Color(hex: "4CC7BE"))
        case .autumn:
            return Wrap(box: Color(hex: "DB6B2C"), lid: Color(hex: "E8843F"), ribbon: Color(hex: "FFF0D6"),
                        ribbonShade: Color(hex: "EAD3AC"), knot: Color(hex: "A8321E"),
                        pattern: .plaid, patternColor: Color(hex: "C2551E"))
        case .holiday:
            return Wrap(box: Color(hex: "D23A48"), lid: Color(hex: "E25B67"), ribbon: Color(hex: "FFF4E2"),
                        ribbonShade: Color(hex: "EADBC4"), knot: Color(hex: "F2B53C"),
                        pattern: .dots, patternColor: Color(hex: "FFF4E2"))
        }
    }

    private static let ink = Color(hex: "3A2418")
    private static let blush = Color(hex: "FF8F9C")

    // MARK: Entry

    static func draw(_ ctx: GraphicsContext, size sz: CGSize, t: Double, pose: ElfPose, season: GiftlySeason) {
        var c = ctx
        let s = sz.width / 300          // 300 design units across the frame
        c.scaleBy(x: s, y: s)
        let w = wrap(for: season)

        // Motion per pose.
        var hop: CGFloat = 0
        var tilt: Double = 0
        var squash: CGFloat = 1 + CGFloat(sin(t * 2.2)) * 0.025
        var lidLift: CGFloat = 0
        var happy = false
        var lookDown = false
        switch pose {
        case .running, .carrying:
            let step = abs(sin(t * 8))
            hop = -CGFloat(step) * 18
            tilt = sin(t * 8) * 4
            squash = 1 - CGFloat(1 - step) * 0.06
        case .cheering:
            let jump = max(0, sin(t * 4.5))
            hop = -CGFloat(jump) * 22
            lidLift = 8 + CGFloat(jump) * 10
            happy = true
        case .waving:
            tilt = sin(t * 3) * 6
        case .reading:
            lookDown = true
        case .idle:
            break
        }

        // Shadow stays on the ground and shrinks as he hops.
        let shadowW: CGFloat = 164 + hop * 2
        c.fill(Path(ellipseIn: CGRect(x: 150 - shadowW / 2, y: 380, width: shadowW, height: 16)),
               with: .color(Color.black.opacity(0.10)))

        if pose == .running || pose == .carrying {
            // Speed lines behind him.
            for i in 0..<3 {
                let y = CGFloat(250 + i * 34)
                let phase = SceneProps.frac(t * 2 + Double(i) * 0.3)
                let len = CGFloat(30 + 20 * (1 - phase))
                var line = Path()
                line.move(to: CGPoint(x: 52 - CGFloat(phase) * 20, y: y))
                line.addLine(to: CGPoint(x: 52 - CGFloat(phase) * 20 - len, y: y))
                c.stroke(line, with: .color(ink.opacity(0.25 * (1 - phase))),
                         style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }

        // Body transform: hop, squash from the base, tilt from the base.
        var b = c
        b.translateBy(x: 150, y: 380 + hop)
        b.rotate(by: .degrees(tilt))
        b.scaleBy(x: 2 - squash, y: squash)
        b.translateBy(x: -150, y: -380)

        drawBox(b, w: w)
        if season == .snowDay || season == .autumn { drawScarf(b, season: season) }
        drawFace(b, t: t, happy: happy, lookDown: lookDown, glasses: season == .summer)

        // Lid and what sits on top lift together.
        var top = b
        top.translateBy(x: 0, y: -lidLift)
        drawLid(top, w: w)
        switch season {
        case .snowDay:
            drawBeanie(top)
        case .spring:
            drawFlowerCrown(top, t: t)
        case .autumn:
            drawBow(top, w: w, t: t)
            drawLeaf(top, t: t)
        default:
            drawBow(top, w: w, t: t)
        }

        if pose == .reading { drawListCard(b, t: t) }
        if pose == .cheering { drawSparkles(c, t: t) }
    }

    // MARK: Box

    private static let bodyRect = CGRect(x: 66, y: 224, width: 168, height: 156)

    private static func drawBox(_ c: GraphicsContext, w: Wrap) {
        let shape = Path(roundedRect: bodyRect, cornerRadius: 28, style: .continuous)
        c.fill(shape, with: .color(w.box))

        var paper = c
        paper.clip(to: shape)
        switch w.pattern {
        case .dots:
            for row in 0..<6 {
                for col in 0..<8 {
                    let x = bodyRect.minX + 12 + CGFloat(col) * 26 + (row % 2 == 1 ? 13 : 0)
                    let y = bodyRect.minY + 14 + CGFloat(row) * 26
                    SceneProps.dot(paper, x, y, 4, w.patternColor.opacity(0.35))
                }
            }
        case .stripes:
            var stripes = paper
            stripes.translateBy(x: bodyRect.midX, y: bodyRect.midY)
            stripes.rotate(by: .degrees(20))
            for i in -8..<9 {
                stripes.fill(Path(CGRect(x: CGFloat(i) * 24, y: -140, width: 10, height: 280)),
                             with: .color(w.patternColor.opacity(0.55)))
            }
        case .plaid:
            for i in 0..<8 {
                paper.fill(Path(CGRect(x: bodyRect.minX, y: bodyRect.minY + 8 + CGFloat(i) * 22, width: bodyRect.width, height: 6)),
                           with: .color(w.patternColor.opacity(0.45)))
                paper.fill(Path(CGRect(x: bodyRect.minX + 8 + CGFloat(i) * 24, y: bodyRect.minY, width: 6, height: bodyRect.height)),
                           with: .color(w.patternColor.opacity(0.35)))
            }
        }
        // Soft shine across the top.
        paper.fill(Path(roundedRect: CGRect(x: 66, y: 224, width: 168, height: 34), cornerRadius: 17),
                   with: .color(Color.white.opacity(0.12)))

        // Ribbon down the front, with a clean patch behind the face.
        c.fill(Path(CGRect(x: 141, y: 224, width: 18, height: 156)), with: .color(w.ribbon))
        c.fill(Path(roundedRect: CGRect(x: 126, y: 274, width: 48, height: 54), cornerRadius: 18), with: .color(w.box))
    }

    private static func drawLid(_ c: GraphicsContext, w: Wrap) {
        c.fill(Path(roundedRect: CGRect(x: 56, y: 204, width: 188, height: 42), cornerRadius: 16, style: .continuous),
               with: .color(w.lid))
        c.fill(Path(CGRect(x: 141, y: 204, width: 18, height: 42)), with: .color(w.ribbon))
    }

    private static func drawBow(_ c: GraphicsContext, w: Wrap, t: Double) {
        var g = c
        g.translateBy(x: 150, y: 204)
        g.scaleBy(x: 1.25, y: 1.25)
        let wiggle = sin(t * 2.5) * 4

        // Tails.
        var lt = Path()
        lt.move(to: CGPoint(x: -6, y: 4)); lt.addLine(to: CGPoint(x: -24, y: 32))
        lt.addLine(to: CGPoint(x: -13, y: 30)); lt.addLine(to: CGPoint(x: -8, y: 40)); lt.closeSubpath()
        g.fill(lt, with: .color(w.ribbonShade))
        g.fill(lt.applying(CGAffineTransform(scaleX: -1, y: 1)), with: .color(w.ribbonShade))

        for side in [-1.0, 1.0] {
            var loop = g
            loop.rotate(by: .degrees(wiggle * side))
            loop.scaleBy(x: CGFloat(side), y: 1)
            var p = Path()
            p.move(to: .zero)
            p.addCurve(to: CGPoint(x: -52, y: -8), control1: CGPoint(x: -14, y: -30), control2: CGPoint(x: -58, y: -34))
            p.addCurve(to: .zero, control1: CGPoint(x: -48, y: 10), control2: CGPoint(x: -16, y: 8))
            loop.fill(p, with: .color(w.ribbon))
            var inner = Path()
            inner.move(to: CGPoint(x: -6, y: -2))
            inner.addCurve(to: CGPoint(x: -38, y: -10), control1: CGPoint(x: -18, y: -16), control2: CGPoint(x: -38, y: -20))
            inner.addCurve(to: CGPoint(x: -6, y: -2), control1: CGPoint(x: -36, y: -2), control2: CGPoint(x: -18, y: 0))
            loop.fill(inner, with: .color(w.ribbonShade.opacity(0.7)))
        }
        g.fill(Path(ellipseIn: CGRect(x: -11, y: -10, width: 22, height: 20)), with: .color(w.knot))
    }

    // MARK: Face

    private static func drawFace(_ c: GraphicsContext, t: Double, happy: Bool, lookDown: Bool, glasses: Bool) {
        let cx: CGFloat = 150
        let cy: CGFloat = lookDown ? 304 : 300
        // Blink for a moment every few seconds.
        let blinkPhase = (t + 1.3).truncatingRemainder(dividingBy: 4.2)
        let blinking = blinkPhase < 0.13
        let eyeH: CGFloat = blinking ? 2.5 : (lookDown ? 17 : 21)

        if glasses {
            let lens = Color(hex: "1E2A33")
            c.fill(Path(roundedRect: CGRect(x: cx - 44, y: cy - 18, width: 34, height: 24), cornerRadius: 10), with: .color(lens))
            c.fill(Path(roundedRect: CGRect(x: cx + 10, y: cy - 18, width: 34, height: 24), cornerRadius: 10), with: .color(lens))
            c.fill(Path(CGRect(x: cx - 10, y: cy - 10, width: 20, height: 5)), with: .color(lens))
            c.fill(Path(roundedRect: CGRect(x: cx - 38, y: cy - 13, width: 10, height: 3), cornerRadius: 1.5), with: .color(Color.white.opacity(0.5)))
            c.fill(Path(roundedRect: CGRect(x: cx + 16, y: cy - 13, width: 10, height: 3), cornerRadius: 1.5), with: .color(Color.white.opacity(0.5)))
        } else {
            for side in [-1.0, 1.0] {
                let ex = cx + CGFloat(side) * 26
                c.fill(Path(ellipseIn: CGRect(x: ex - 8.5, y: cy - 4 - eyeH / 2, width: 17, height: eyeH)), with: .color(ink))
                if !blinking {
                    SceneProps.dot(c, ex + 3, cy - (lookDown ? 6 : 8), 3.4, .white)
                }
            }
        }
        SceneProps.dot(c, cx - 40, cy + 12, 9, blush.opacity(0.7))
        SceneProps.dot(c, cx + 40, cy + 12, 9, blush.opacity(0.7))

        var mouth = Path()
        if happy {
            mouth.move(to: CGPoint(x: cx - 10, y: cy + 8))
            mouth.addQuadCurve(to: CGPoint(x: cx + 10, y: cy + 8), control: CGPoint(x: cx, y: cy + 24))
            mouth.closeSubpath()
            c.fill(mouth, with: .color(ink))
            SceneProps.dot(c, cx, cy + 15, 4, Color(hex: "E8707A"))
        } else {
            mouth.move(to: CGPoint(x: cx - 9, y: cy + 10))
            mouth.addQuadCurve(to: CGPoint(x: cx + 9, y: cy + 10), control: CGPoint(x: cx, y: cy + 19))
            c.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
        }
    }

    // MARK: Seasonal accessories

    private static func drawScarf(_ c: GraphicsContext, season: GiftlySeason) {
        let color = season == .snowDay ? Color(hex: "E8503F") : Color(hex: "7A3B2E")
        var band = Path()
        band.move(to: CGPoint(x: 66, y: 332))
        band.addQuadCurve(to: CGPoint(x: 234, y: 332), control: CGPoint(x: 150, y: 354))
        band.addLine(to: CGPoint(x: 234, y: 348))
        band.addQuadCurve(to: CGPoint(x: 66, y: 348), control: CGPoint(x: 150, y: 370))
        band.closeSubpath()
        c.fill(band, with: .color(color))
        let tailX: CGFloat = season == .snowDay ? 186 : 94
        c.fill(Path(roundedRect: CGRect(x: tailX, y: 340, width: 20, height: 42), cornerRadius: 6), with: .color(color))
        c.fill(Path(CGRect(x: tailX, y: 372, width: 20, height: 3)), with: .color(Color.white.opacity(0.4)))
    }

    private static func drawBeanie(_ c: GraphicsContext) {
        var cap = Path()
        cap.move(to: CGPoint(x: 84, y: 210))
        cap.addQuadCurve(to: CGPoint(x: 150, y: 132), control: CGPoint(x: 86, y: 140))
        cap.addQuadCurve(to: CGPoint(x: 216, y: 210), control: CGPoint(x: 214, y: 140))
        cap.closeSubpath()
        c.fill(cap, with: .color(Color(hex: "F3F7FB")))
        c.fill(Path(roundedRect: CGRect(x: 76, y: 196, width: 148, height: 24), cornerRadius: 12), with: .color(Color(hex: "DDE7F2")))
        for i in 0..<10 {
            c.fill(Path(roundedRect: CGRect(x: 88 + CGFloat(i) * 14, y: 199, width: 6, height: 18), cornerRadius: 3),
                   with: .color(Color(hex: "C9D8E8")))
        }
        SceneProps.dot(c, 150, 128, 18, .white)
    }

    private static func drawFlowerCrown(_ c: GraphicsContext, t: Double) {
        var vine = Path()
        vine.move(to: CGPoint(x: 70, y: 206))
        vine.addQuadCurve(to: CGPoint(x: 232, y: 206), control: CGPoint(x: 150, y: 176))
        c.stroke(vine, with: .color(Color(hex: "6FBF8E")), lineWidth: 6)
        let flowers: [(CGFloat, CGFloat, String)] = [
            (84, 200, "FFFFFF"), (112, 190, "FFD36B"), (140, 186, "B07FD8"),
            (168, 186, "FFFFFF"), (196, 190, "FF9AB8"), (222, 200, "FFD36B")
        ]
        for (i, f) in flowers.enumerated() {
            let bob = CGFloat(sin(t * 2 + Double(i))) * 1.5
            SceneProps.dot(c, f.0, f.1 + bob, 13, Color(hex: f.2))
            SceneProps.dot(c, f.0, f.1 + bob, 5, Color(hex: "FFE07A"))
        }
    }

    private static func drawLeaf(_ c: GraphicsContext, t: Double) {
        var g = c
        g.translateBy(x: 206, y: 178)
        g.rotate(by: .degrees(30 + sin(t * 1.8) * 6))
        var leaf = Path()
        leaf.move(to: CGPoint(x: 0, y: -26))
        leaf.addCurve(to: CGPoint(x: 0, y: 26), control1: CGPoint(x: 16, y: -14), control2: CGPoint(x: 16, y: 14))
        leaf.addCurve(to: CGPoint(x: 0, y: -26), control1: CGPoint(x: -16, y: 14), control2: CGPoint(x: -16, y: -14))
        g.fill(leaf, with: .color(Color(hex: "B5462A")))
        var vein = Path()
        vein.move(to: CGPoint(x: 0, y: -26)); vein.addLine(to: CGPoint(x: 0, y: 30))
        g.stroke(vein, with: .color(Color(hex: "7A2E18")), lineWidth: 2)
    }

    // MARK: Pose extras

    /// A little wish list card he's reading, beside him.
    private static func drawListCard(_ c: GraphicsContext, t: Double) {
        var g = c
        g.translateBy(x: 238, y: 300)
        g.rotate(by: .degrees(12 + sin(t * 1.5) * 3))
        g.fill(Path(roundedRect: CGRect(x: -22, y: -30, width: 44, height: 58), cornerRadius: 6), with: .color(.white))
        g.stroke(Path(roundedRect: CGRect(x: -22, y: -30, width: 44, height: 58), cornerRadius: 6),
                 with: .color(Color.black.opacity(0.08)), lineWidth: 1.5)
        for i in 0..<4 {
            let width: CGFloat = i == 3 ? 18 : 30
            g.fill(Path(roundedRect: CGRect(x: -15, y: -20 + CGFloat(i) * 11, width: width, height: 4), cornerRadius: 2),
                   with: .color(ink.opacity(0.35)))
        }
    }

    private static func drawSparkles(_ c: GraphicsContext, t: Double) {
        let spots: [CGPoint] = [CGPoint(x: 60, y: 170), CGPoint(x: 246, y: 160), CGPoint(x: 232, y: 250), CGPoint(x: 70, y: 260)]
        for (i, p) in spots.enumerated() {
            let a = max(0, sin(t * 3 + Double(i) * 1.7))
            let r = CGFloat(5 + 8 * a)
            c.fill(SparkleShape().path(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                   with: .color(Color(hex: "FFC63D").opacity(0.4 + 0.6 * a)))
        }
    }
}
