//
//  ElfView.swift
//  Giftly
//
//  Pip, the workshop's head elf. Drawn entirely in code (no image assets)
//  on a 100 x 140 grid: big expressive eyes, brows, droopy hat with a fur
//  brim, curly bell toed boots, and a wrapped gift he hugs while idle.
//  Four poses, all animated, all static under Reduce Motion.
//

import SwiftUI

enum ElfPose {
    case idle       // hugging a gift, breathing, blinking
    case reading    // holding your wish slip, eyes down
    case running    // knees up, arms pumping, hat bouncing
    case cheering   // arms up, ears flapping, big grin
    case waving     // one arm up, waving hello
    case carrying   // walking with a wrapped gift held overhead
}

/// What Pip wears on his head (and whether he's in elf gear at all).
enum PipOutfit {
    case elfHat, beanie, flowerCrown, sunHat, beret
}

/// An elf's outfit and look. Pip is the default; the rest of the workshop
/// crew wear their own colors and come in a range of skin tones.
struct ElfStyle {
    var hat: Color
    var hatShade: Color
    var tunic: Color
    var tunicShade: Color
    var legs: Color
    var skin: Color
    var skinShade: Color
    var hair: Color?
    var outfit: PipOutfit = .elfHat
    var furTrim: Bool = true           // Christmas fur hem, collar, belt, curly boots
    var hatColor: Color? = nil         // beanie / sun hat / beret body
    var hatColorShade: Color? = nil
    var accentColor: Color? = nil      // pompom, hat band
    var scarf: Color? = nil

    static let pip = ElfStyle(hat: Color(hex: "C0392B"), hatShade: Color(hex: "9E2C21"),
                              tunic: Color(hex: "2F7D4F"), tunicShade: Color(hex: "245F3C"),
                              legs: Color(hex: "C0392B"),
                              skin: Color(hex: "F6D0A8"), skinShade: Color(hex: "E3B48A"), hair: nil)
    static let juniper = ElfStyle(hat: Color(hex: "2F7D4F"), hatShade: Color(hex: "245F3C"),
                                  tunic: Color(hex: "C0392B"), tunicShade: Color(hex: "9E2C21"),
                                  legs: Color(hex: "2F7D4F"),
                                  skin: Color(hex: "C68A5E"), skinShade: Color(hex: "A9714A"), hair: Color(hex: "3A2414"))
    static let tinsel = ElfStyle(hat: Color(hex: "2C5D8F"), hatShade: Color(hex: "214870"),
                                 tunic: Color(hex: "7A2E3A"), tunicShade: Color(hex: "5F222C"),
                                 legs: Color(hex: "2C5D8F"),
                                 skin: Color(hex: "8D5A3B"), skinShade: Color(hex: "74482E"), hair: Color(hex: "1E120B"))
    /// Pip dressed for the season: elf gear only for the Holiday Workshop,
    /// off duty the rest of the year. Precomputed so drawing stays cheap.
    static func pip(for season: GiftlySeason) -> ElfStyle {
        switch season {
        case .holiday: return .pip
        case .snowDay: return .snowDayPip
        case .spring:  return .springPip
        case .summer:  return .summerPip
        case .autumn:  return .autumnPip
        }
    }

    static let snowDayPip = ElfStyle(hat: Color(hex: "E8503F"), hatShade: Color(hex: "C23E30"),
        tunic: Color(hex: "3A6EA5"), tunicShade: Color(hex: "2C5784"),
        legs: Color(hex: "2A3A55"),
        skin: Color(hex: "F6D0A8"), skinShade: Color(hex: "E3B48A"), hair: nil,
        outfit: .beanie, furTrim: false,
        hatColor: Color(hex: "E8503F"), hatColorShade: Color(hex: "C23E30"),
        accentColor: Color(hex: "F6E9D2"), scarf: Color(hex: "F2C14E"))
    static let springPip = ElfStyle(hat: Color(hex: "C0392B"), hatShade: Color(hex: "9E2C21"),
        tunic: Color(hex: "8DBF8B"), tunicShade: Color(hex: "73A571"),
        legs: Color(hex: "6B5A8E"),
        skin: Color(hex: "F6D0A8"), skinShade: Color(hex: "E3B48A"), hair: nil,
        outfit: .flowerCrown, furTrim: false)
    static let summerPip = ElfStyle(hat: Color(hex: "C0392B"), hatShade: Color(hex: "9E2C21"),
        tunic: Color(hex: "3FA7A0"), tunicShade: Color(hex: "2F8C86"),
        legs: Color(hex: "E3B04B"),
        skin: Color(hex: "F6D0A8"), skinShade: Color(hex: "E3B48A"), hair: nil,
        outfit: .sunHat, furTrim: false,
        hatColor: Color(hex: "F0D68A"), hatColorShade: Color(hex: "D9BC6A"),
        accentColor: Color(hex: "E8503F"))
    static let autumnPip = ElfStyle(hat: Color(hex: "C0392B"), hatShade: Color(hex: "9E2C21"),
        tunic: Color(hex: "C9852E"), tunicShade: Color(hex: "A86C22"),
        legs: Color(hex: "5B3A1E"),
        skin: Color(hex: "F6D0A8"), skinShade: Color(hex: "E3B48A"), hair: nil,
        outfit: .beret, furTrim: false,
        hatColor: Color(hex: "7A4A2A"), hatColorShade: Color(hex: "5F3920"),
        accentColor: Color(hex: "E8503F"), scarf: Color(hex: "9E2C21"))

    static let holly = ElfStyle(hat: Color(hex: "B5447A"), hatShade: Color(hex: "93365F"),
                                tunic: Color(hex: "3E7C6B"), tunicShade: Color(hex: "2F6355"),
                                legs: Color(hex: "B5447A"),
                                skin: Color(hex: "EFC09A"), skinShade: Color(hex: "D9A47C"), hair: Color(hex: "C9772E"))
}

struct ElfView: View {
    var pose: ElfPose = .idle
    var size: CGFloat = 120
    /// nil = Pip, dressed for the current season.
    var style: ElfStyle? = nil

    @AppStorage(GiftlySeason.settingKey) private var seasonSetting = "auto"
    @AppStorage(GiftlySeason.previewTouchKey) private var previewTouch = "none"

    /// The look actually drawn.
    var look: ElfStyle {
        if let style { return style }
        return ElfStyle.pip(for: GiftlySeason.shown(setting: seasonSetting, preview: previewTouch))
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { ctx, sz in
                    drawElf(ctx, size: sz, t: 0)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { ctx, sz in
                        drawElf(ctx, size: sz, t: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .frame(width: size, height: size * 1.4)
        .accessibilityHidden(true)
    }
}

// MARK: - Palette

private enum ElfInk {
    static let skin      = Color(hex: "F6D0A8")
    static let skinShade = Color(hex: "E3B48A")
    static let innerEar  = Color(hex: "E9A890")
    static let blush     = Color(hex: "EF8F8F")
    static let nose      = Color(hex: "E8A27F")
    static let mouth     = Color(hex: "7A1F1A")
    static let tongue    = Color(hex: "E46B6B")
    static let ink       = Color(hex: "2A1B11")
    static let boot      = Color(hex: "5B3A1E")
    static let pineShade = Color(hex: "245F3C")
    static let hatShade  = Color(hex: "9E2C21")
}

// MARK: - Drawing

private extension ElfView {

    func drawElf(_ ctx: GraphicsContext, size sz: CGSize, t: Double) {
        var c = ctx
        let s = sz.width / 100
        c.scaleBy(x: s, y: s)

        let running = pose == .running || pose == .carrying
        let step = sin(t * 9)
        let bob = running ? -abs(step) * 4 : sin(t * 2.2) * 1.5

        // Ground shadow stays put while he bobs.
        c.fill(Path(ellipseIn: CGRect(x: 28, y: 129.5, width: 44, height: 7)),
               with: .color(Color.black.opacity(0.3)))
        c.translateBy(x: 0, y: CGFloat(bob))

        // Legs: alternating knee lift when running.
        let lean = running ? step * 10 : 0
        drawLeg(c, side: -1, angle: lean, lift: running ? max(0, step) * 7 : 0)
        drawLeg(c, side: 1, angle: lean, lift: running ? max(0, -step) * 7 : 0)

        drawTunic(c)

        // Arms and whatever he's holding.
        switch pose {
        case .idle:
            drawGift(c)
            drawArm(c, side: -1, hand: CGPoint(x: 38, y: 95), control: CGPoint(x: 29, y: 90))
            drawArm(c, side: 1, hand: CGPoint(x: 62, y: 95), control: CGPoint(x: 71, y: 90))
        case .reading:
            drawSlip(c)
            drawArm(c, side: -1, hand: CGPoint(x: 39, y: 94), control: CGPoint(x: 30, y: 90))
            drawArm(c, side: 1, hand: CGPoint(x: 61, y: 94), control: CGPoint(x: 70, y: 90))
        case .running:
            let radians = step * 40 * Double.pi / 180
            for side in [-1.0, 1.0] {
                let shoulder = CGPoint(x: 50 + 15 * side, y: 79)
                let hand = CGPoint(x: shoulder.x - CGFloat(20 * sin(radians)),
                                   y: shoulder.y + CGFloat(20 * cos(radians)))
                let mid = CGPoint(x: (shoulder.x + hand.x) / 2, y: (shoulder.y + hand.y) / 2)
                drawArm(c, side: side, hand: hand, control: mid)
            }
        case .cheering:
            let wave = sin(t * 8) * 3
            drawArm(c, side: -1, hand: CGPoint(x: 19, y: 56 + wave), control: CGPoint(x: 22, y: 74))
            drawArm(c, side: 1, hand: CGPoint(x: 81, y: 56 - wave), control: CGPoint(x: 78, y: 74))
        case .waving:
            let wave = sin(t * 8) * 6
            drawArm(c, side: -1, hand: CGPoint(x: 38, y: 95), control: CGPoint(x: 29, y: 90))
            drawArm(c, side: 1, hand: CGPoint(x: 84, y: 52 + wave), control: CGPoint(x: 80, y: 72))
        case .carrying:
            // Arms go up behind the head; the gift is drawn after the head.
            drawArm(c, side: -1, hand: CGPoint(x: 33, y: 24), control: CGPoint(x: 14, y: 52))
            drawArm(c, side: 1, hand: CGPoint(x: 67, y: 24), control: CGPoint(x: 86, y: 52))
        }

        drawEars(c, t: t)
        drawHead(c, t: t)
        if let scarf = look.scarf {
            drawScarf(c, color: scarf)
        }
        if pose == .carrying {
            drawShortHat(c)
            drawCarriedGift(c)
        } else {
            switch look.outfit {
            case .elfHat:      drawHat(c, t: t, running: running, step: step)
            case .beanie:      drawBeanie(c)
            case .flowerCrown: drawFlowerCrown(c, t: t)
            case .sunHat:      drawSunHat(c)
            case .beret:       drawBeret(c)
            }
        }
    }

    // MARK: Body parts

    func drawLeg(_ ctx: GraphicsContext, side sx: Double, angle: Double, lift: Double) {
        var l = ctx
        let hx = 50 + 9 * sx
        l.translateBy(x: 0, y: CGFloat(-lift))
        l.translateBy(x: CGFloat(hx), y: 110)
        l.rotate(by: .degrees(angle))
        l.translateBy(x: CGFloat(-hx), y: -110)

        if !look.furTrim {
            // Off duty: plain trousers and round shoes.
            l.fill(Path(CGRect(x: hx - 4, y: 106, width: 8, height: 20)), with: .color(look.legs))
            func q(_ dx: Double, _ dy: Double) -> CGPoint { CGPoint(x: hx + sx * dx, y: dy) }
            var shoe = Path()
            shoe.move(to: q(-6, 126))
            shoe.addQuadCurve(to: q(8, 124), control: q(0, 120))
            shoe.addQuadCurve(to: q(11, 130), control: q(12, 126))
            shoe.addQuadCurve(to: q(-6, 130), control: q(2, 132))
            shoe.closeSubpath()
            l.fill(shoe, with: .color(ElfInk.boot))
            return
        }
        l.fill(Path(CGRect(x: hx - 4, y: 110, width: 8, height: 16)), with: .color(look.legs))
        l.fill(Path(CGRect(x: hx - 4, y: 113, width: 8, height: 3)), with: .color(Workshop.cream))
        l.fill(Path(CGRect(x: hx - 4, y: 119, width: 8, height: 3)), with: .color(Workshop.cream))

        // Curly toed boot pointing outward, with a bell on the tip.
        func p(_ dx: Double, _ dy: Double) -> CGPoint { CGPoint(x: hx + sx * dx, y: dy) }
        var boot = Path()
        boot.move(to: p(-6, 126))
        boot.addQuadCurve(to: p(7, 126), control: p(0, 120))
        boot.addQuadCurve(to: p(16, 121), control: p(14, 127))
        boot.addQuadCurve(to: p(3, 131), control: p(18, 131))
        boot.addQuadCurve(to: p(-6, 126), control: p(-5, 131))
        boot.closeSubpath()
        l.fill(boot, with: .color(ElfInk.boot))
        let bell = p(16, 120.5)
        l.fill(Path(ellipseIn: CGRect(x: bell.x - 2.4, y: bell.y - 2.4, width: 4.8, height: 4.8)),
               with: .color(Workshop.brass))
    }

    func drawTunic(_ c: GraphicsContext) {
        if !look.furTrim {
            drawSweater(c)
            return
        }
        var tunic = Path()
        tunic.move(to: CGPoint(x: 34, y: 76))
        tunic.addQuadCurve(to: CGPoint(x: 66, y: 76), control: CGPoint(x: 50, y: 72))
        tunic.addQuadCurve(to: CGPoint(x: 76, y: 110), control: CGPoint(x: 73, y: 94))
        tunic.addQuadCurve(to: CGPoint(x: 24, y: 110), control: CGPoint(x: 50, y: 116))
        tunic.addQuadCurve(to: CGPoint(x: 34, y: 76), control: CGPoint(x: 27, y: 94))
        tunic.closeSubpath()
        c.fill(tunic, with: .color(look.tunic))

        var shade = Path()
        shade.move(to: CGPoint(x: 58, y: 75))
        shade.addLine(to: CGPoint(x: 66, y: 76))
        shade.addQuadCurve(to: CGPoint(x: 76, y: 110), control: CGPoint(x: 73, y: 94))
        shade.addQuadCurve(to: CGPoint(x: 62, y: 113), control: CGPoint(x: 68, y: 112))
        shade.addQuadCurve(to: CGPoint(x: 58, y: 75), control: CGPoint(x: 64, y: 94))
        shade.closeSubpath()
        c.fill(shade, with: .color(look.tunicShade))

        // Fur hem.
        for i in 0..<7 {
            circle(c, CGPoint(x: 27 + Double(i) * 7.7, y: 110.5), 4.6, Workshop.cream)
        }

        // Belt and buckle.
        var belt = Path()
        belt.move(to: CGPoint(x: 28, y: 95))
        belt.addQuadCurve(to: CGPoint(x: 72, y: 95), control: CGPoint(x: 50, y: 99))
        belt.addLine(to: CGPoint(x: 73, y: 101))
        belt.addQuadCurve(to: CGPoint(x: 27, y: 101), control: CGPoint(x: 50, y: 105))
        belt.closeSubpath()
        c.fill(belt, with: .color(ElfInk.boot))
        c.fill(Path(roundedRect: CGRect(x: 45, y: 94.5, width: 10, height: 9), cornerRadius: 1.5),
               with: .color(Workshop.brass))
        c.fill(Path(CGRect(x: 47.8, y: 97.2, width: 4.4, height: 3.6)), with: .color(ElfInk.boot))

        // Fur collar.
        for i in 0..<5 {
            circle(c, CGPoint(x: 38 + Double(i) * 6, y: 77), 4.2, Workshop.cream)
        }
    }

    func drawGift(_ c: GraphicsContext) {
        let box = CGRect(x: 38, y: 84, width: 24, height: 18)
        c.fill(Path(roundedRect: box, cornerRadius: 2.5), with: .color(Workshop.berry))
        c.fill(Path(roundedRect: CGRect(x: 38, y: 84, width: 24, height: 5), cornerRadius: 2),
               with: .color(Color.white.opacity(0.15)))
        c.fill(Path(CGRect(x: 48, y: 84, width: 4, height: 18)), with: .color(Workshop.cream))
        rotatedEllipse(c, center: CGPoint(x: 45, y: 82), rx: 5, ry: 3, degrees: -25, color: Workshop.cream)
        rotatedEllipse(c, center: CGPoint(x: 55, y: 82), rx: 5, ry: 3, degrees: 25, color: Workshop.cream)
        circle(c, CGPoint(x: 50, y: 83), 2.3, Workshop.brass)
    }

    func drawSlip(_ ctx: GraphicsContext) {
        var p = ctx
        p.translateBy(x: 50, y: 94)
        p.rotate(by: .degrees(-4))
        p.translateBy(x: -50, y: -94)
        p.fill(Path(roundedRect: CGRect(x: 35, y: 85, width: 30, height: 19), cornerRadius: 1.5),
               with: .color(Workshop.cream))
        for i in 0..<3 {
            p.fill(Path(roundedRect: CGRect(x: 39, y: 89 + Double(i) * 4.5,
                                            width: 22 - Double(i) * 5, height: 1.4), cornerRadius: 0.7),
                   with: .color(ElfInk.boot.opacity(0.55)))
        }
    }

    func drawArm(_ c: GraphicsContext, side: Double, hand: CGPoint, control: CGPoint) {
        var sleeve = Path()
        sleeve.move(to: CGPoint(x: 50 + 15 * side, y: 79))
        sleeve.addQuadCurve(to: hand, control: control)
        c.stroke(sleeve, with: .color(look.tunic), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        circle(c, hand, 4.3, look.skin)
    }

    func drawEars(_ c: GraphicsContext, t: Double) {
        let wiggle = pose == .cheering ? sin(t * 8) * 8 : sin(t * 2.8) * 3

        var left = c
        left.translateBy(x: 32, y: 50)
        left.rotate(by: .degrees(wiggle))
        left.translateBy(x: -32, y: -50)
        left.fill(triangleEar(base1: CGPoint(x: 37, y: 44), control1: CGPoint(x: 20, y: 40),
                              tip: CGPoint(x: 5, y: 31), control2: CGPoint(x: 12, y: 52),
                              base2: CGPoint(x: 36, y: 62)), with: .color(look.skin))
        left.fill(triangleEar(base1: CGPoint(x: 31, y: 47), control1: CGPoint(x: 20, y: 43),
                              tip: CGPoint(x: 11, y: 37), control2: CGPoint(x: 17, y: 51),
                              base2: CGPoint(x: 31, y: 57)), with: .color(ElfInk.innerEar))

        var right = c
        right.translateBy(x: 68, y: 50)
        right.rotate(by: .degrees(-wiggle))
        right.translateBy(x: -68, y: -50)
        right.fill(triangleEar(base1: CGPoint(x: 63, y: 44), control1: CGPoint(x: 80, y: 40),
                               tip: CGPoint(x: 95, y: 31), control2: CGPoint(x: 88, y: 52),
                               base2: CGPoint(x: 64, y: 62)), with: .color(look.skin))
        right.fill(triangleEar(base1: CGPoint(x: 69, y: 47), control1: CGPoint(x: 80, y: 43),
                               tip: CGPoint(x: 89, y: 37), control2: CGPoint(x: 83, y: 51),
                               base2: CGPoint(x: 69, y: 57)), with: .color(ElfInk.innerEar))
    }

    func drawHead(_ c: GraphicsContext, t: Double) {
        let headRect = CGRect(x: 27, y: 31, width: 46, height: 46)
        // Side hair peeks out under the hat for elves who have it.
        if let hair = look.hair {
            c.fill(Path(ellipseIn: CGRect(x: 25, y: 41, width: 12, height: 18)), with: .color(hair))
            c.fill(Path(ellipseIn: CGRect(x: 63, y: 41, width: 12, height: 18)), with: .color(hair))
        }
        c.fill(Path(ellipseIn: headRect), with: .color(look.skin))

        // Soft shade on the right: tint the whole head, then repaint skin
        // with a circle nudged up and left, leaving a crescent.
        var shade = c
        shade.clip(to: Path(ellipseIn: headRect))
        shade.fill(Path(ellipseIn: headRect), with: .color(look.skinShade.opacity(0.6)))
        shade.fill(Path(ellipseIn: headRect.offsetBy(dx: -4, dy: -3)), with: .color(look.skin))
        if let hair = look.hair {
            var bangs = Path()
            bangs.move(to: CGPoint(x: 30, y: 44))
            bangs.addQuadCurve(to: CGPoint(x: 44, y: 38), control: CGPoint(x: 34, y: 36))
            bangs.addQuadCurve(to: CGPoint(x: 56, y: 38), control: CGPoint(x: 50, y: 42))
            bangs.addQuadCurve(to: CGPoint(x: 70, y: 44), control: CGPoint(x: 66, y: 36))
            bangs.addQuadCurve(to: CGPoint(x: 58, y: 42), control: CGPoint(x: 66, y: 40))
            bangs.addQuadCurve(to: CGPoint(x: 42, y: 42), control: CGPoint(x: 50, y: 46))
            bangs.addQuadCurve(to: CGPoint(x: 30, y: 44), control: CGPoint(x: 34, y: 40))
            bangs.closeSubpath()
            c.fill(bangs, with: .color(hair))
        }

        // Cheeks.
        circle(c, CGPoint(x: 37, y: 60), 4.5, ElfInk.blush.opacity(0.5))
        circle(c, CGPoint(x: 63, y: 60), 4.5, ElfInk.blush.opacity(0.5))

        // Eyes: blink briefly at the end of each cycle (open at t = 0, so
        // the Reduce Motion still frame has open eyes).
        let eyeY: Double = pose == .reading ? 54.5 : 53
        let blinking = t.truncatingRemainder(dividingBy: 3.7) > 3.58
        for ex in [42.0, 58.0] {
            if blinking {
                var lid = Path()
                lid.move(to: CGPoint(x: ex - 3.4, y: eyeY))
                lid.addQuadCurve(to: CGPoint(x: ex + 3.4, y: eyeY), control: CGPoint(x: ex, y: eyeY + 2))
                c.stroke(lid, with: .color(ElfInk.ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            } else {
                c.fill(Path(ellipseIn: CGRect(x: ex - 3.4, y: eyeY - 4.4, width: 6.8, height: 8.8)),
                       with: .color(ElfInk.ink))
                circle(c, CGPoint(x: ex + 1.2, y: eyeY - 1.6), 1.3, .white)
                circle(c, CGPoint(x: ex - 1, y: eyeY + 2), 0.6, .white)
            }
        }

        // Brows (raised when cheering).
        let lift: Double = pose == .cheering ? -2.5 : 0
        var browL = Path()
        browL.move(to: CGPoint(x: 38, y: 46.5 + lift))
        browL.addQuadCurve(to: CGPoint(x: 46, y: 46 + lift), control: CGPoint(x: 42, y: 44 + lift))
        var browR = Path()
        browR.move(to: CGPoint(x: 54, y: 46 + lift))
        browR.addQuadCurve(to: CGPoint(x: 62, y: 46.5 + lift), control: CGPoint(x: 58, y: 44 + lift))
        let browStyle = StrokeStyle(lineWidth: 1.6, lineCap: .round)
        c.stroke(browL, with: .color(ElfInk.boot), style: browStyle)
        c.stroke(browR, with: .color(ElfInk.boot), style: browStyle)

        // Nose.
        c.fill(Path(ellipseIn: CGRect(x: 47.4, y: 56.4, width: 5.2, height: 4.2)), with: .color(ElfInk.nose))

        // Mouth: open grin when excited, closed smile otherwise.
        var mouth = Path()
        if pose == .cheering || pose == .running || pose == .waving || pose == .carrying {
            mouth.move(to: CGPoint(x: 42.5, y: 62))
            mouth.addQuadCurve(to: CGPoint(x: 57.5, y: 62), control: CGPoint(x: 50, y: 73))
            mouth.addQuadCurve(to: CGPoint(x: 42.5, y: 62), control: CGPoint(x: 50, y: 64))
            mouth.closeSubpath()
            c.fill(mouth, with: .color(ElfInk.mouth))
            c.fill(Path(ellipseIn: CGRect(x: 46.8, y: 65.7, width: 6.4, height: 3.2)), with: .color(ElfInk.tongue))
        } else {
            mouth.move(to: CGPoint(x: 43.5, y: 62.5))
            mouth.addQuadCurve(to: CGPoint(x: 56.5, y: 62.5), control: CGPoint(x: 50, y: 70))
            mouth.addQuadCurve(to: CGPoint(x: 43.5, y: 62.5), control: CGPoint(x: 50, y: 64.5))
            mouth.closeSubpath()
            c.fill(mouth, with: .color(ElfInk.mouth))
        }
    }

    func drawHat(_ c: GraphicsContext, t: Double, running: Bool, step: Double) {
        let bend = sin(t * 2.0) * 3 + (running ? step * 3 : 0)
        let tip = CGPoint(x: 90 + bend, y: 30 + abs(bend) * 0.3)
        let fold = 80 + bend * 0.5
        let under = 82 + bend * 0.5

        var hat = Path()
        hat.move(to: CGPoint(x: 27, y: 40))
        hat.addQuadCurve(to: CGPoint(x: 52, y: 9), control: CGPoint(x: 26, y: 14))
        hat.addQuadCurve(to: tip, control: CGPoint(x: fold, y: 4))
        hat.addQuadCurve(to: CGPoint(x: 72, y: 22), control: CGPoint(x: under, y: 22))
        hat.addQuadCurve(to: CGPoint(x: 73, y: 40), control: CGPoint(x: 74, y: 30))
        hat.closeSubpath()
        c.fill(hat, with: .color(look.hat))

        var shade = Path()
        shade.move(to: CGPoint(x: 60, y: 9))
        shade.addQuadCurve(to: tip, control: CGPoint(x: fold, y: 4))
        shade.addQuadCurve(to: CGPoint(x: 72, y: 22), control: CGPoint(x: under, y: 22))
        shade.addQuadCurve(to: CGPoint(x: 60, y: 9), control: CGPoint(x: 70, y: 14))
        shade.closeSubpath()
        c.fill(shade, with: .color(look.hatShade))

        // Fur brim and pompom.
        for i in 0..<8 {
            circle(c, CGPoint(x: 26 + Double(i) * 6.9, y: 39), 4.8, Workshop.cream)
        }
        circle(c, CGPoint(x: tip.x, y: tip.y + 1), 6, Workshop.cream)
    }

    // MARK: Off duty outfits

    /// A plain sweater (no fur hem, collar or belt) for the off season.
    func drawSweater(_ c: GraphicsContext) {
        var top = Path()
        top.move(to: CGPoint(x: 34, y: 76))
        top.addQuadCurve(to: CGPoint(x: 66, y: 76), control: CGPoint(x: 50, y: 72))
        top.addQuadCurve(to: CGPoint(x: 75, y: 108), control: CGPoint(x: 73, y: 94))
        top.addQuadCurve(to: CGPoint(x: 25, y: 108), control: CGPoint(x: 50, y: 113))
        top.addQuadCurve(to: CGPoint(x: 34, y: 76), control: CGPoint(x: 27, y: 94))
        top.closeSubpath()
        c.fill(top, with: .color(look.tunic))

        var shade = Path()
        shade.move(to: CGPoint(x: 58, y: 75))
        shade.addLine(to: CGPoint(x: 66, y: 76))
        shade.addQuadCurve(to: CGPoint(x: 75, y: 108), control: CGPoint(x: 73, y: 94))
        shade.addQuadCurve(to: CGPoint(x: 62, y: 111), control: CGPoint(x: 68, y: 110))
        shade.addQuadCurve(to: CGPoint(x: 58, y: 75), control: CGPoint(x: 64, y: 94))
        shade.closeSubpath()
        c.fill(shade, with: .color(look.tunicShade))

        // Ribbed hem and a neckline.
        var rib = Path()
        rib.move(to: CGPoint(x: 26, y: 104))
        rib.addQuadCurve(to: CGPoint(x: 74, y: 104), control: CGPoint(x: 50, y: 109))
        rib.addLine(to: CGPoint(x: 75, y: 108))
        rib.addQuadCurve(to: CGPoint(x: 25, y: 108), control: CGPoint(x: 50, y: 113))
        rib.closeSubpath()
        c.fill(rib, with: .color(look.tunicShade))
        var neck = Path()
        neck.move(to: CGPoint(x: 42, y: 75))
        neck.addQuadCurve(to: CGPoint(x: 58, y: 75), control: CGPoint(x: 50, y: 80))
        c.stroke(neck, with: .color(look.tunicShade), lineWidth: 2.5)

        if look.outfit == .flowerCrown {
            for point in [CGPoint(x: 44, y: 92), CGPoint(x: 56, y: 98), CGPoint(x: 50, y: 86)] {
                circle(c, point, 2.2, Workshop.cream)
            }
        }
    }

    func drawScarf(_ c: GraphicsContext, color: Color) {
        var wrap = Path()
        wrap.move(to: CGPoint(x: 33, y: 72))
        wrap.addQuadCurve(to: CGPoint(x: 67, y: 72), control: CGPoint(x: 50, y: 80))
        wrap.addLine(to: CGPoint(x: 68, y: 79))
        wrap.addQuadCurve(to: CGPoint(x: 32, y: 79), control: CGPoint(x: 50, y: 87))
        wrap.closeSubpath()
        c.fill(wrap, with: .color(color))
        var tail = Path()
        tail.move(to: CGPoint(x: 58, y: 78))
        tail.addLine(to: CGPoint(x: 66, y: 78))
        tail.addLine(to: CGPoint(x: 64, y: 98))
        tail.addLine(to: CGPoint(x: 57, y: 96))
        tail.closeSubpath()
        c.fill(tail, with: .color(color))
        var fringe = Path()
        fringe.move(to: CGPoint(x: 57, y: 95))
        fringe.addLine(to: CGPoint(x: 64, y: 97))
        fringe.addLine(to: CGPoint(x: 63, y: 100))
        fringe.addLine(to: CGPoint(x: 56, y: 98))
        fringe.closeSubpath()
        c.fill(fringe, with: .color(Workshop.cream.opacity(0.7)))
    }

    func drawBeanie(_ c: GraphicsContext) {
        let body: Color = look.hatColor ?? look.hat
        let shade: Color = look.hatColorShade ?? look.hatShade
        var dome = Path()
        dome.move(to: CGPoint(x: 27, y: 42))
        dome.addQuadCurve(to: CGPoint(x: 50, y: 14), control: CGPoint(x: 26, y: 16))
        dome.addQuadCurve(to: CGPoint(x: 73, y: 42), control: CGPoint(x: 74, y: 16))
        dome.closeSubpath()
        c.fill(dome, with: .color(body))
        var side = Path()
        side.move(to: CGPoint(x: 58, y: 15))
        side.addQuadCurve(to: CGPoint(x: 73, y: 42), control: CGPoint(x: 74, y: 18))
        side.addLine(to: CGPoint(x: 64, y: 42))
        side.addQuadCurve(to: CGPoint(x: 58, y: 15), control: CGPoint(x: 66, y: 24))
        side.closeSubpath()
        c.fill(side, with: .color(shade))
        c.fill(Path(roundedRect: CGRect(x: 25, y: 36, width: 50, height: 9), cornerRadius: 4.5), with: .color(shade))
        for i in 0..<6 {
            c.fill(Path(CGRect(x: 29 + Double(i) * 7.5, y: 37, width: 2, height: 7)), with: .color(body.opacity(0.7)))
        }
        circle(c, CGPoint(x: 50, y: 12), 7, look.accentColor ?? Workshop.cream)
    }

    func drawFlowerCrown(_ c: GraphicsContext, t: Double) {
        var vine = Path()
        vine.move(to: CGPoint(x: 28, y: 40))
        vine.addQuadCurve(to: CGPoint(x: 72, y: 40), control: CGPoint(x: 50, y: 30))
        c.stroke(vine, with: .color(Color(hex: "6E9C55")), lineWidth: 2.5)
        let colors: [Color] = [Color(hex: "F28FB0"), Color(hex: "FFD36B"), Workshop.cream,
                               Color(hex: "B98AE0"), Color(hex: "F28FB0"), Color(hex: "FFD36B")]
        for (i, color) in colors.enumerated() {
            let u: Double = (Double(i) + 0.5) / 6
            let x: Double = 28 + 44 * u
            let y: Double = 40 - 10 * 4 * u * (1 - u)
            let wobble: Double = sin(t * 1.5 + Double(i)) * 0.4
            for k in 0..<5 {
                let angle: Double = Double(k) * 2 * Double.pi / 5 + wobble
                circle(c, CGPoint(x: x + cos(angle) * 3.2, y: y + sin(angle) * 3.2), 2.6, color)
            }
            circle(c, CGPoint(x: x, y: y), 1.8, Workshop.brass)
        }
    }

    func drawSunHat(_ c: GraphicsContext) {
        let straw: Color = look.hatColor ?? Color(hex: "F0D68A")
        let strawShade: Color = look.hatColorShade ?? Color(hex: "D9BC6A")
        let brim = CGRect(x: 12, y: 29, width: 76, height: 18)
        c.fill(Path(ellipseIn: brim), with: .color(straw))
        c.stroke(Path(ellipseIn: brim), with: .color(strawShade), lineWidth: 1.5)
        var crown = Path()
        crown.move(to: CGPoint(x: 32, y: 38))
        crown.addQuadCurve(to: CGPoint(x: 50, y: 17), control: CGPoint(x: 32, y: 18))
        crown.addQuadCurve(to: CGPoint(x: 68, y: 38), control: CGPoint(x: 68, y: 18))
        crown.closeSubpath()
        c.fill(crown, with: .color(straw))
        var crownShade = Path()
        crownShade.move(to: CGPoint(x: 58, y: 18))
        crownShade.addQuadCurve(to: CGPoint(x: 68, y: 38), control: CGPoint(x: 68, y: 20))
        crownShade.addLine(to: CGPoint(x: 62, y: 38))
        crownShade.addQuadCurve(to: CGPoint(x: 58, y: 18), control: CGPoint(x: 63, y: 26))
        crownShade.closeSubpath()
        c.fill(crownShade, with: .color(strawShade))
        c.fill(Path(CGRect(x: 32, y: 31, width: 36, height: 5)), with: .color(look.accentColor ?? Workshop.berry))
    }

    func drawBeret(_ c: GraphicsContext) {
        let felt: Color = look.hatColor ?? Color(hex: "7A4A2A")
        let feltShade: Color = look.hatColorShade ?? Color(hex: "5F3920")
        c.fill(Path(ellipseIn: CGRect(x: 28, y: 22, width: 44, height: 18)), with: .color(felt))
        c.fill(Path(ellipseIn: CGRect(x: 27, y: 21, width: 36, height: 14)), with: .color(felt))
        circle(c, CGPoint(x: 50, y: 22), 2.5, feltShade)
        var leaf = Path()
        leaf.move(to: CGPoint(x: 64, y: 34))
        leaf.addQuadCurve(to: CGPoint(x: 72, y: 36), control: CGPoint(x: 70, y: 30))
        leaf.addQuadCurve(to: CGPoint(x: 64, y: 34), control: CGPoint(x: 68, y: 40))
        leaf.closeSubpath()
        c.fill(leaf, with: .color(look.accentColor ?? Workshop.berry))
    }

    /// A short cap for carrying, so the gift can sit on top of the head.
    func drawShortHat(_ c: GraphicsContext) {
        var cap = Path()
        cap.move(to: CGPoint(x: 27, y: 40))
        cap.addQuadCurve(to: CGPoint(x: 50, y: 22), control: CGPoint(x: 30, y: 24))
        cap.addQuadCurve(to: CGPoint(x: 73, y: 40), control: CGPoint(x: 70, y: 24))
        cap.closeSubpath()
        c.fill(cap, with: .color(look.hat))
        for i in 0..<8 {
            circle(c, CGPoint(x: 26 + Double(i) * 6.9, y: 39), 4.8, Workshop.cream)
        }
    }

    /// The wrapped gift held overhead while carrying.
    func drawCarriedGift(_ c: GraphicsContext) {
        c.fill(Path(roundedRect: CGRect(x: 30, y: 0, width: 40, height: 26), cornerRadius: 3),
               with: .color(Workshop.brass))
        c.fill(Path(CGRect(x: 47, y: 0, width: 6, height: 26)), with: .color(Workshop.berry))
        c.fill(Path(CGRect(x: 30, y: 10, width: 40, height: 5)), with: .color(Workshop.berry))
    }

    // MARK: Helpers

    func circle(_ c: GraphicsContext, _ center: CGPoint, _ r: CGFloat, _ color: Color) {
        c.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
               with: .color(color))
    }

    func rotatedEllipse(_ ctx: GraphicsContext, center: CGPoint, rx: CGFloat, ry: CGFloat,
                        degrees: Double, color: Color) {
        var e = ctx
        e.translateBy(x: center.x, y: center.y)
        e.rotate(by: .degrees(degrees))
        e.fill(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)), with: .color(color))
    }

    func triangleEar(base1: CGPoint, control1: CGPoint, tip: CGPoint,
                     control2: CGPoint, base2: CGPoint) -> Path {
        var p = Path()
        p.move(to: base1)
        p.addQuadCurve(to: tip, control: control1)
        p.addQuadCurve(to: base2, control: control2)
        p.closeSubpath()
        return p
    }
}
