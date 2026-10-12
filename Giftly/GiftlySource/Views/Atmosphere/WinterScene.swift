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

struct GiftlyPineTree: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let trunk = Color(red: 0.34, green: 0.22, blue: 0.14).opacity(0.80)
            let needleDeep = Color(red: 0.10, green: 0.34, blue: 0.22).opacity(0.92)
            let needleMid  = Color(red: 0.14, green: 0.44, blue: 0.28).opacity(0.92)
            let snow = Color(red: 0.95, green: 0.97, blue: 1.0).opacity(0.92)

            let cx = w * 0.80          // anchored toward the right
            let baseY = h

            // Trunk
            var trunkPath = Path()
            trunkPath.addRect(CGRect(x: cx - 10, y: baseY - 70, width: 20, height: 70))
            context.fill(trunkPath, with: .color(trunk))

            // Three stacked conifer tiers, widest at the bottom
            let tiers: [(y: CGFloat, halfW: CGFloat, hgt: CGFloat)] = [
                (baseY - 60, 95, 120),
                (baseY - 150, 78, 110),
                (baseY - 235, 58, 100),
            ]
            for (i, tier) in tiers.enumerated() {
                var tri = Path()
                tri.move(to: CGPoint(x: cx, y: tier.y - tier.hgt))
                tri.addLine(to: CGPoint(x: cx - tier.halfW, y: tier.y))
                tri.addLine(to: CGPoint(x: cx + tier.halfW, y: tier.y))
                tri.closeSubpath()
                context.fill(tri, with: .color(i == 1 ? needleMid : needleDeep))

                // Snow cap on each tier (a lighter triangle sitting on the slopes)
                var cap = Path()
                cap.move(to: CGPoint(x: cx, y: tier.y - tier.hgt))
                cap.addLine(to: CGPoint(x: cx - tier.halfW * 0.5, y: tier.y - tier.hgt * 0.5))
                cap.addQuadCurve(to: CGPoint(x: cx + tier.halfW * 0.5, y: tier.y - tier.hgt * 0.5),
                                 control: CGPoint(x: cx, y: tier.y - tier.hgt * 0.38))
                cap.closeSubpath()
                context.fill(cap, with: .color(snow))
            }

            // A warm star on top
            let star = Color(red: 1.0, green: 0.85, blue: 0.30)
            let starC = CGPoint(x: cx, y: baseY - 235 - 100 - 6)
            context.fill(starPath(center: starC, r: 11), with: .color(star))
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: star.opacity(0.8), radius: 6))
                layer.fill(starPath(center: starC, r: 11), with: .color(star))
            }

            // A few ornament baubles
            let baubles: [(CGFloat, CGFloat, Color)] = [
                (cx - 30, baseY - 70, Color(red: 0.90, green: 0.20, blue: 0.24)),
                (cx + 24, baseY - 95, Color(red: 0.95, green: 0.80, blue: 0.28)),
                (cx - 10, baseY - 150, Color(red: 0.38, green: 0.72, blue: 0.95)),
                (cx + 34, baseY - 175, Color(red: 0.90, green: 0.20, blue: 0.24)),
                (cx - 6, baseY - 235, Color(red: 0.95, green: 0.80, blue: 0.28)),
            ]
            for (bx, by, c) in baubles {
                context.fill(Path(ellipseIn: CGRect(x: bx - 5, y: by - 5, width: 10, height: 10)), with: .color(c))
                context.fill(Path(ellipseIn: CGRect(x: bx - 2, y: by - 3, width: 2.4, height: 2.4)), with: .color(.white.opacity(0.8)))
            }
        }
        .drawingGroup()
    }

    private func starPath(center: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5 - .pi / 2
            let radius = i % 2 == 0 ? r : r * 0.45
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                             y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
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

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let hat = Color(red: 0.86, green: 0.20, blue: 0.24)
            let hatTrim = Color(red: 0.97, green: 0.98, blue: 1.0)
            let skin = Color(red: 0.98, green: 0.84, blue: 0.74)
            let suit = Color(red: 0.16, green: 0.56, blue: 0.32)
            let cheek = Color(red: 0.96, green: 0.60, blue: 0.60).opacity(0.6)

            let cx = w * 0.5
            // head
            context.fill(Path(ellipseIn: CGRect(x: cx - 13, y: h * 0.34, width: 26, height: 26)), with: .color(skin))
            // pointy ears
            var earL = Path()
            earL.move(to: CGPoint(x: cx - 12, y: h * 0.44))
            earL.addLine(to: CGPoint(x: cx - 20, y: h * 0.40))
            earL.addLine(to: CGPoint(x: cx - 11, y: h * 0.48))
            earL.closeSubpath()
            context.fill(earL, with: .color(skin))
            var earR = Path()
            earR.move(to: CGPoint(x: cx + 12, y: h * 0.44))
            earR.addLine(to: CGPoint(x: cx + 20, y: h * 0.40))
            earR.addLine(to: CGPoint(x: cx + 11, y: h * 0.48))
            earR.closeSubpath()
            context.fill(earR, with: .color(skin))
            // cheeks
            context.fill(Path(ellipseIn: CGRect(x: cx - 10, y: h * 0.45, width: 6, height: 5)), with: .color(cheek))
            context.fill(Path(ellipseIn: CGRect(x: cx + 4, y: h * 0.45, width: 6, height: 5)), with: .color(cheek))
            // eyes
            context.fill(Path(ellipseIn: CGRect(x: cx - 6, y: h * 0.41, width: 3, height: 3)), with: .color(.black))
            context.fill(Path(ellipseIn: CGRect(x: cx + 3, y: h * 0.41, width: 3, height: 3)), with: .color(.black))
            // smile
            var smile = Path()
            smile.move(to: CGPoint(x: cx - 4, y: h * 0.50))
            smile.addQuadCurve(to: CGPoint(x: cx + 4, y: h * 0.50), control: CGPoint(x: cx, y: h * 0.53))
            context.stroke(smile, with: .color(.black.opacity(0.6)), lineWidth: 1.2)
            // pointy hat
            var hatPath = Path()
            hatPath.move(to: CGPoint(x: cx - 14, y: h * 0.36))
            hatPath.addQuadCurve(to: CGPoint(x: cx + 10, y: h * 0.12), control: CGPoint(x: cx + 2, y: h * 0.20))
            hatPath.addLine(to: CGPoint(x: cx + 14, y: h * 0.36))
            hatPath.closeSubpath()
            context.fill(hatPath, with: .color(hat))
            context.fill(Path(ellipseIn: CGRect(x: cx + 7, y: h * 0.10, width: 7, height: 7)), with: .color(hatTrim))
            context.fill(Path(CGRect(x: cx - 15, y: h * 0.35, width: 30, height: 5)), with: .color(hatTrim))
            // little shoulders/suit peeking at the bottom
            context.fill(Path(roundedRect: CGRect(x: cx - 16, y: h * 0.60, width: 32, height: h * 0.40), cornerRadius: 8), with: .color(suit))
        }
        .frame(width: 54, height: 70)
        .scaleEffect(x: flip ? -1 : 1)
        // "pop" up from behind: slide + fade + a little overshoot scale
        .scaleEffect(0.9 + 0.1 * visibility, anchor: .bottom)
        .offset(y: (1 - visibility) * 60)
        .opacity(visibility)
        .drawingGroup()
    }
}

// MARK: - Strolling Reindeer

struct GiftlyReindeer: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let body = Color(red: 0.52, green: 0.36, blue: 0.22)
            let bodyDark = Color(red: 0.40, green: 0.27, blue: 0.16)
            let antler = Color(red: 0.74, green: 0.60, blue: 0.42)
            let nose = Color(red: 0.92, green: 0.22, blue: 0.20)

            // body
            context.fill(Path(ellipseIn: CGRect(x: w * 0.22, y: h * 0.40, width: w * 0.52, height: h * 0.34)), with: .color(body))
            // legs
            for lx in [w * 0.30, w * 0.42, w * 0.56, w * 0.66] {
                context.fill(Path(CGRect(x: lx, y: h * 0.68, width: 4.5, height: h * 0.28)), with: .color(bodyDark))
            }
            // neck + head
            context.fill(Path(roundedRect: CGRect(x: w * 0.64, y: h * 0.26, width: w * 0.14, height: h * 0.30), cornerRadius: 6), with: .color(body))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.70, y: h * 0.18, width: w * 0.22, height: h * 0.22)), with: .color(body))
            // ears
            context.fill(Path(ellipseIn: CGRect(x: w * 0.70, y: h * 0.16, width: 8, height: 5)), with: .color(bodyDark))
            // antlers
            var ant = Path()
            ant.move(to: CGPoint(x: w * 0.76, y: h * 0.20))
            ant.addLine(to: CGPoint(x: w * 0.72, y: h * 0.04))
            ant.move(to: CGPoint(x: w * 0.74, y: h * 0.10))
            ant.addLine(to: CGPoint(x: w * 0.68, y: h * 0.06))
            ant.move(to: CGPoint(x: w * 0.84, y: h * 0.20))
            ant.addLine(to: CGPoint(x: w * 0.88, y: h * 0.04))
            ant.move(to: CGPoint(x: w * 0.86, y: h * 0.10))
            ant.addLine(to: CGPoint(x: w * 0.92, y: h * 0.06))
            context.stroke(ant, with: .color(antler), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            // eye
            context.fill(Path(ellipseIn: CGRect(x: w * 0.84, y: h * 0.25, width: 3, height: 3)), with: .color(.black))
            // glowing red nose
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: nose.opacity(0.9), radius: 5))
                layer.fill(Path(ellipseIn: CGRect(x: w * 0.90, y: h * 0.30, width: 7, height: 7)), with: .color(nose))
            }
        }
        .frame(width: 90, height: 70)
        .drawingGroup()
    }
}
