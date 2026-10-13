//
//  GiftBoxMark.swift
//  Giftly
//
//  A wrapped gift in the person's color that gets livelier as their date
//  approaches: calm far away, wiggling inside two weeks, glinting inside
//  three days, lid popped open with sparkles on the day. A tiny hint of the
//  event rides along (balloon, heart, gold sparkle, holly).
//

import SwiftUI

enum GiftStage {
    case calm, wiggle, glint, open

    static func forDays(_ days: Int) -> GiftStage {
        if days < 0 { return .calm }
        if days == 0 { return .open }
        if days <= 3 { return .glint }
        if days <= 14 { return .wiggle }
        return .calm
    }
}

struct GiftBoxMark: View {
    let color: Color
    var stage: GiftStage = .calm
    var size: CGFloat = 44
    /// Offsets the animation so a column of boxes doesn't move in lockstep.
    var seed: Double = 0
    /// Adds a small hint of the event: a balloon, a heart, a sparkle, holly.
    var kind: OccasionKind? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            // A calm box doesn't move, so it doesn't need a clock running.
            if reduceMotion || (stage == .calm && kind == nil) {
                Canvas { ctx, sz in
                    drawBox(ctx, size: sz, t: 0)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    Canvas { ctx, sz in
                        drawBox(ctx, size: sz, t: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func drawBox(_ ctx: GraphicsContext, size sz: CGSize, t: Double) {
        var c = ctx
        let s = min(sz.width, sz.height) / 60
        c.scaleBy(x: s, y: s)
        let tt = t + seed

        // Wiggle: a short shake every few seconds, faster as the date nears.
        var shake = 0.0
        if stage == .wiggle || stage == .glint {
            let period = stage == .glint ? 2.6 : 4.2
            let phase = tt.truncatingRemainder(dividingBy: period)
            if phase < 0.7 {
                shake = sin(phase * 38) * 6 * (1 - phase / 0.7)
            }
        }
        let sway = sin(tt * 0.9) * 3

        // Shadow.
        c.fill(Path(ellipseIn: CGRect(x: 10, y: 53, width: 40, height: 5)),
               with: .color(Color.black.opacity(0.25)))

        c.translateBy(x: 30, y: 56)
        c.rotate(by: .degrees(shake))
        c.translateBy(x: -30, y: -56)

        let ribbon = Workshop.cream

        // Body.
        let bodyRect = CGRect(x: 9, y: 28, width: 42, height: 27)
        c.fill(Path(roundedRect: bodyRect, cornerRadius: 3), with: .color(color))
        c.fill(Path(CGRect(x: 27, y: 28, width: 6, height: 27)), with: .color(ribbon))
        if stage == .open {
            // Dark inside, seen through the opening.
            c.fill(Path(roundedRect: CGRect(x: 11, y: 28, width: 38, height: 5), cornerRadius: 2),
                   with: .color(Color.black.opacity(0.4)))
        }

        // Lid (lifts and tilts when open).
        var lid = c
        if stage == .open {
            let lift = (sin(tt * 2.4) * 0.5 + 0.5) * 3
            lid.translateBy(x: 30, y: 25)
            lid.rotate(by: .degrees(-12))
            lid.translateBy(x: -30, y: CGFloat(-25 - 9 - lift))
        }
        let lidRect = CGRect(x: 6, y: 20, width: 48, height: 10)
        lid.fill(Path(roundedRect: lidRect, cornerRadius: 3), with: .color(color))
        lid.fill(Path(roundedRect: lidRect, cornerRadius: 3), with: .color(Color.white.opacity(0.14)))
        lid.fill(Path(CGRect(x: 27, y: 20, width: 6, height: 10)), with: .color(ribbon))

        // Bow.
        var left = lid
        left.translateBy(x: 24, y: 18)
        left.rotate(by: .degrees(-28 + sway))
        left.fill(Path(ellipseIn: CGRect(x: -9, y: -5, width: 18, height: 10)), with: .color(ribbon))
        var right = lid
        right.translateBy(x: 36, y: 18)
        right.rotate(by: .degrees(28 - sway))
        right.fill(Path(ellipseIn: CGRect(x: -9, y: -5, width: 18, height: 10)), with: .color(ribbon))
        lid.fill(Path(ellipseIn: CGRect(x: 26.5, y: 15.5, width: 7, height: 7)), with: .color(Workshop.brass))

        // Sparkles.
        if stage == .glint {
            let spots: [CGPoint] = [CGPoint(x: 10, y: 24), CGPoint(x: 52, y: 32), CGPoint(x: 38, y: 12)]
            for (j, spot) in spots.enumerated() {
                let a = max(0, sin(tt * 3 + Double(j) * 2.1))
                let r = CGFloat(2 + 4 * a)
                c.fill(SparkleShape().path(in: CGRect(x: spot.x - r, y: spot.y - r, width: r * 2, height: r * 2)),
                       with: .color(Workshop.brass.opacity(a)))
            }
        } else if stage == .open {
            for j in 0..<3 {
                let p = (tt * 0.8 + Double(j) / 3.0).truncatingRemainder(dividingBy: 1.0)
                let sx = CGFloat(30 + Double(j - 1) * 11 + sin(tt * 2 + Double(j)) * 3)
                let sy = CGFloat(20 - p * 18)
                let r = CGFloat(3.5 - p * 1.5)
                c.fill(SparkleShape().path(in: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)),
                       with: .color(Workshop.brass.opacity(1 - p)))
            }
        }

        drawHint(ctx, scale: s, t: tt)
    }

    /// The event hint, drawn upright (it does not shake with the box).
    private func drawHint(_ ctx: GraphicsContext, scale s: CGFloat, t: Double) {
        guard let kind else { return }
        var c = ctx
        c.scaleBy(x: s, y: s)
        switch kind {
        case .birthday, .babyShower, .quinceanera:
            let bob = CGFloat(sin(t * 1.6) * 1.5)
            let fill: Color = kind == .babyShower ? Color(hex: "A8D8F0") : Color(hex: "FFC63D")
            var string = Path()
            string.move(to: CGPoint(x: 52, y: 16 + bob))
            string.addQuadCurve(to: CGPoint(x: 49, y: 27), control: CGPoint(x: 54, y: 22))
            c.stroke(string, with: .color(Color(hex: "8A7A6A")), lineWidth: 0.8)
            c.fill(Path(ellipseIn: CGRect(x: 47.5, y: 4 + bob, width: 9, height: 11.5)), with: .color(fill))
            c.fill(Path(ellipseIn: CGRect(x: 49.3, y: 6 + bob, width: 2.4, height: 3.4)), with: .color(Color.white.opacity(0.5)))
        case .anniversary, .wedding, .valentines, .engagement, .bridalShower:
            let beat = CGFloat(1 + 0.08 * max(0, sin(t * 3)))
            let heart = SceneProps.heartPath(center: CGPoint(x: 9, y: 14), r: 5 * beat)
            c.fill(heart, with: .color(Color(hex: "E8506A")))
        case .graduation:
            let a = 0.5 + 0.5 * max(0, sin(t * 2.2))
            let r = CGFloat(3 + 2.5 * a)
            c.fill(SparkleShape().path(in: CGRect(x: 52 - r, y: 11 - r, width: r * 2, height: r * 2)),
                   with: .color(Workshop.brass.opacity(0.6 + 0.4 * a)))
        case .christmas, .secretSanta:
            var leafA = c
            leafA.translateBy(x: 41, y: 24)
            leafA.rotate(by: .degrees(-30))
            leafA.fill(Path(ellipseIn: CGRect(x: -5, y: -2, width: 10, height: 4.5)), with: .color(Workshop.pine))
            var leafB = c
            leafB.translateBy(x: 47, y: 25)
            leafB.rotate(by: .degrees(25))
            leafB.fill(Path(ellipseIn: CGRect(x: -5, y: -2, width: 10, height: 4.5)), with: .color(Workshop.pine))
            c.fill(Path(ellipseIn: CGRect(x: 42, y: 22, width: 3.6, height: 3.6)), with: .color(Workshop.berry))
            c.fill(Path(ellipseIn: CGRect(x: 44.6, y: 23.6, width: 3.6, height: 3.6)), with: .color(Workshop.berry))
        default:
            break
        }
    }
}
