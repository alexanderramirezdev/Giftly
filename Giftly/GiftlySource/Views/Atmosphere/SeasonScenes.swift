//
//  SeasonScenes.swift
//  Giftly
//
//  The four non holiday home scenes. Each one is a single Canvas built from
//  SceneProps, with that season's holiday touches layered on during their
//  window (or when previewed from Settings). The Holiday Workshop scene
//  with the elf crew lives in GiftlyAtmosphereView / WinterScene.
//

import SwiftUI

// MARK: - Snow Day (Jan 7 to Feb)

struct SnowDayScene: View {
    let reduceMotion: Bool
    let touches: [SeasonalTouch]

    var body: some View {
        SceneCanvas(reduceMotion: reduceMotion) { ctx, size, t in
            SnowDayScene.draw(ctx, size: size, t: t, valentine: touches.contains(.valentine))
        }
    }

    static func draw(_ c: GraphicsContext, size: CGSize, t: Double, valentine: Bool) {
        let w = size.width
        let h = size.height
        SceneProps.ground(c, size: size, back: Color(hex: "E4EDF4"), front: Color(hex: "F4F8FB"))
        SceneProps.littlePine(c, x: w * 0.56, base: h - 74, height: 46)
        SceneProps.littlePine(c, x: w * 0.64, base: h - 80, height: 60)
        SceneProps.littlePine(c, x: w * 0.93, base: h - 66, height: 52)
        SceneProps.snowman(c, x: w * 0.78, y: h - 34, t: t)
        if valentine {
            SceneProps.particles(c, size: size, t: t, kind: .heartsRising, count: 10, seed: 3)
        }
        SceneProps.particles(c, size: size, t: t, kind: .snow, count: 26)
    }
}

// MARK: - Spring (Mar to May)

struct SpringScene: View {
    let reduceMotion: Bool
    let touches: [SeasonalTouch]

    var body: some View {
        SceneCanvas(reduceMotion: reduceMotion) { ctx, size, t in
            SpringScene.draw(ctx, size: size, t: t,
                             easter: touches.contains(.easter),
                             mothersDay: touches.contains(.mothersDay))
        }
    }

    static func draw(_ c: GraphicsContext, size: CGSize, t: Double, easter: Bool, mothersDay: Bool) {
        let w = size.width
        let h = size.height
        SceneProps.ground(c, size: size, back: Color(hex: "CFE8C4"), front: Color(hex: "E2F2D8"))
        let blossoms: [Color] = [Color(hex: "FFFFFF"), Color(hex: "F28FB0"), Color(hex: "FFE3EC")]
        SceneProps.canopyTree(c, x: w * 0.82, base: h - 40, leaf: Color(hex: "F7C6D6"),
                              leafShade: Color(hex: "D9789A"), accents: blossoms,
                              sway: sin(t * 0.6) * 1.2)
        if mothersDay {
            let colors: [Color] = [Color(hex: "E8503F"), Color(hex: "F28FB0"), Color(hex: "FFD36B"), Color(hex: "B07FD8")]
            for i in 0..<5 {
                let x = w * (0.52 + CGFloat(i) * 0.05)
                let sway = sin(t * 1.1 + Double(i))
                SceneProps.tulip(c, x: x, y: h - 30, color: colors[i % colors.count], sway: sway)
            }
        }
        if easter {
            let eggs: [(CGFloat, String, String)] = [(0.60, "A8D8F0", "FFFFFF"), (0.68, "FFD36B", "F28FB0"), (0.95, "C9B6F0", "FFFFFF")]
            for (fx, color, stripe) in eggs {
                SceneProps.egg(c, x: w * fx, y: h - 26, color: Color(hex: color), stripe: Color(hex: stripe))
            }
        }
        SceneProps.butterfly(c, x: w * 0.30 + CGFloat(sin(t * 0.4)) * 40, y: h * 0.62 + CGFloat(sin(t * 0.9)) * 18,
                             color: Color(hex: "F2A541"), t: t)
        SceneProps.butterfly(c, x: w * 0.62 + CGFloat(cos(t * 0.33)) * 30, y: h * 0.48 + CGFloat(sin(t * 0.7)) * 14,
                             color: Color(hex: "7FC8F8"), t: t + 1.7)
        SceneProps.particles(c, size: size, t: t, kind: .petals, count: 14)
    }
}

// MARK: - Summer (Jun to Aug)

struct SummerScene: View {
    let reduceMotion: Bool
    let touches: [SeasonalTouch]

    var body: some View {
        SceneCanvas(reduceMotion: reduceMotion) { ctx, size, t in
            SummerScene.draw(ctx, size: size, t: t, fathersDay: touches.contains(.fathersDay))
        }
    }

    static func draw(_ c: GraphicsContext, size: CGSize, t: Double, fathersDay: Bool) {
        let w = size.width
        let h = size.height
        SceneProps.sun(c, x: w * 0.84, y: h * 0.16, t: t)
        let drift = CGFloat(SceneProps.frac(t / 90))
        SceneProps.cloud(c, x: -80 + (w + 160) * drift, y: h * 0.12, scale: 1.0)
        SceneProps.cloud(c, x: -80 + (w + 160) * CGFloat(SceneProps.frac(t / 120 + 0.55)), y: h * 0.26, scale: 0.7)
        SceneProps.ground(c, size: size, back: Color(hex: "BFE3B0"), front: Color(hex: "D6EFC8"))
        if fathersDay {
            let blues: [Color] = [Color(hex: "3A6EA5"), Color(hex: "7FB2E5"), Color(hex: "1F8A84"), Color(hex: "FFFFFF")]
            SceneProps.bunting(c, from: w * 0.48, to: w + 10, y: h - 160, colors: blues, leafy: false)
        }
        SceneProps.kite(c, x: w * 0.70, y: h * 0.40, t: t)
        SceneProps.butterfly(c, x: w * 0.40 + CGFloat(sin(t * 0.5)) * 36, y: h * 0.70 + CGFloat(sin(t * 1.1)) * 12,
                             color: Color(hex: "F2A541"), t: t)
    }
}

// MARK: - Autumn (Sep to Thanksgiving)

struct AutumnScene: View {
    let reduceMotion: Bool
    let touches: [SeasonalTouch]

    var body: some View {
        SceneCanvas(reduceMotion: reduceMotion) { ctx, size, t in
            AutumnScene.draw(ctx, size: size, t: t,
                             halloween: touches.contains(.halloween),
                             thanksgiving: touches.contains(.thanksgiving))
        }
    }

    static func draw(_ c: GraphicsContext, size: CGSize, t: Double, halloween: Bool, thanksgiving: Bool) {
        let w = size.width
        let h = size.height
        SceneProps.ground(c, size: size, back: Color(hex: "EAD9BE"), front: Color(hex: "F3E6D0"))
        let fall: [Color] = [Color(hex: "C25B1A"), Color(hex: "E8A33D"), Color(hex: "A8321E")]
        SceneProps.canopyTree(c, x: w * 0.84, base: h - 40, leaf: Color(hex: "E08A2E"),
                              leafShade: Color(hex: "A8501E"), accents: fall,
                              sway: sin(t * 0.55) * 1.0)
        if thanksgiving {
            SceneProps.bunting(c, from: w * 0.46, to: w + 10, y: h - 200, colors: fall, leafy: true)
        }
        SceneProps.pumpkin(c, x: w * 0.62, y: h - 30, r: 22, face: halloween, t: t)
        SceneProps.pumpkin(c, x: w * 0.71, y: h - 24, r: 15, face: false, t: t)
        if halloween {
            SceneProps.pumpkin(c, x: w * 0.95, y: h - 26, r: 18, face: true, t: t + 0.8)
        }
        SceneProps.particles(c, size: size, t: t, kind: .leaves, count: 14)
    }
}
