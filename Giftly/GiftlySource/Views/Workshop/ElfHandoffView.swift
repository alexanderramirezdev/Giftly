//
//  ElfHandoffView.swift
//  Giftly
//
//  The moment that makes adding a wish memorable. While the app cleans the
//  wish and looks up real prices, the elf takes your slip, reads it, runs
//  the shelves, and cheers when it has results. It replaces a plain spinner
//  and gives the wait a reason to exist.
//

import SwiftUI

struct ElfHandoffView: View {
    enum Stage { case reading, searching, found }

    let stage: Stage
    let wish: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var slipIn = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                ShelvesBackdrop()
                content
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            caption
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Stage content

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .reading:
            ZStack {
                ElfView(pose: .reading, size: 88)
                    .offset(y: 8)
                WishSlip(text: wish)
                    .offset(x: slipIn ? 0 : -190, y: 34)
                    .rotationEffect(.degrees(slipIn ? -3 : -18))
            }
            .onAppear {
                if reduceMotion {
                    slipIn = true
                } else {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { slipIn = true }
                }
            }

        case .searching:
            GeometryReader { geo in
                if reduceMotion {
                    ElfView(pose: .running, size: 78)
                        .position(x: geo.size.width / 2, y: 84)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        ElfView(pose: .running, size: 78)
                            .position(x: geo.size.width / 2 + CGFloat(sin(t * 0.9)) * geo.size.width * 0.30,
                                      y: 84)
                    }
                }
            }

        case .found:
            ZStack {
                ElfView(pose: .cheering, size: 84)
                    .offset(y: 6)
                sparkles
            }
        }
    }

    private var sparkles: some View {
        GeometryReader { geo in
            let spots: [CGPoint] = [
                CGPoint(x: geo.size.width * 0.22, y: 40),
                CGPoint(x: geo.size.width * 0.80, y: 56),
                CGPoint(x: geo.size.width * 0.66, y: 24)
            ]
            if reduceMotion {
                ForEach(0..<spots.count, id: \.self) { i in
                    SparkleShape()
                        .fill(Workshop.brass)
                        .frame(width: 14, height: 14)
                        .position(spots[i])
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<spots.count, id: \.self) { i in
                            let pulse = 0.6 + 0.4 * sin(t * 3 + Double(i) * 1.7)
                            SparkleShape()
                                .fill(Workshop.brass.opacity(0.5 + 0.5 * pulse))
                                .frame(width: 16, height: 16)
                                .scaleEffect(CGFloat(pulse))
                                .position(spots[i])
                        }
                    }
                }
            }
        }
    }

    // MARK: Caption

    private var messages: [String] {
        switch stage {
        case .reading:
            return ["\(Workshop.elfName) is reading your slip…",
                    "Squinting at the handwriting…",
                    "Asking the head elf what that means…"]
        case .searching:
            return ["Peeking in the Target aisle…",
                    "Checking Amazon's shelves…",
                    "Asking Walmart's elves…",
                    "Digging through eBay for a deal…"]
        case .found:
            return ["Found some! Pick the right one."]
        }
    }

    private var caption: some View {
        TimelineView(.periodic(from: .now, by: 2.4)) { timeline in
            let list = messages
            let index = reduceMotion ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 2.4) % list.count
            Text(list[index])
                .font(.workshop(14, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
    }

    private var accessibilityText: String {
        switch stage {
        case .reading:   return "The elf is reading your wish."
        case .searching: return "The elves are searching for real prices."
        case .found:     return "The elves found some options."
        }
    }
}

// MARK: - Pieces

private struct WishSlip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .serif))
            .foregroundStyle(Color(hex: "3B2718"))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(8)
            .frame(width: 96, height: 56)
            .background(Workshop.cream, in: RoundedRectangle(cornerRadius: 4))
            .shadow(color: Color.black.opacity(0.3), radius: 3, y: 2)
    }
}

/// Static shelves with little boxes, plus a warm lantern glow.
private struct ShelvesBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            let c = ctx
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Workshop.woodLight))

            // Lantern glow, top right.
            let center = CGPoint(x: size.width * 0.86, y: 14)
            let r = size.width * 0.5
            c.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                   with: .radialGradient(
                    Gradient(colors: [Workshop.brass.opacity(0.22), Color.clear]),
                    center: center, startRadius: 0, endRadius: r))

            // Two planks with boxes.
            let colors: [Color] = [Workshop.berry, Workshop.pine, Workshop.brass, Color(hex: "4C8BF5"), Color(hex: "B565C9")]
            for (row, plankY) in [58.0, 118.0].enumerated() {
                let y = CGFloat(plankY)
                var x: CGFloat = 8
                var n = row * 3
                while x < size.width - 20 {
                    let side = CGFloat(16 + (n % 3) * 5)
                    let color = colors[n % colors.count]
                    c.fill(Path(roundedRect: CGRect(x: x, y: y - side, width: side, height: side), cornerRadius: 2),
                           with: .color(color.opacity(0.55)))
                    c.fill(Path(CGRect(x: x + side / 2 - 1.5, y: y - side, width: 3, height: side)),
                           with: .color(Workshop.cream.opacity(0.35)))
                    x += side + 9
                    n += 1
                }
                c.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 5)), with: .color(Workshop.grain))
            }
        }
        .accessibilityHidden(true)
    }
}
