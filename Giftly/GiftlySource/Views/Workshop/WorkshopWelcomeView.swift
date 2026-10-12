//
//  WorkshopWelcomeView.swift
//  Giftly
//
//  First launch: a short swipeable intro that shows what Giftly does, each
//  page with a small live illustration (not screenshots), ending in the
//  workshop door. The same pages can be replayed from Settings.
//

import SwiftUI

struct WorkshopWelcomeView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        IntroView(isReplay: false, onFinish: enter)
    }

    private func enter() {
        session.role = .parent
        session.clearGate()
        session.completeOnboarding()
        GiftIntelligence.shared.prewarm()
    }
}

// MARK: - Intro pages

struct IntroView: View {
    var isReplay: Bool = false
    let onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 5

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $page) {
                IntroPage(title: "Welcome to the workshop",
                          message: "Giftly keeps every wish for everyone you shop for in one calm place, with real prices from real stores.") {
                    WelcomeArt()
                }
                .tag(0)

                IntroPage(title: "Say it like they said it",
                          message: "Type the wish in plain words. \(Workshop.elfName) finds the actual product at stores like Target, Walmart and Amazon, and picks the best match for your budget.") {
                    WishToProductArt()
                }
                .tag(1)

                IntroPage(title: "Every date, one list",
                          message: "Birthdays, Christmas, anniversaries. See what's coming up, what's picked, what's bought, and how the budget is holding.") {
                    ComingUpArt()
                }
                .tag(2)

                IntroPage(title: "Scan their Christmas list",
                          message: "Snap a photo of a handwritten list and every wish lands on their page, ready to price.") {
                    ScanArt()
                }
                .tag(3)

                IntroPage(title: "Private by design",
                          message: "Profiles stay on your iPhone and in your own iCloud. No accounts, no ads. Only a product search like \"lego race car\" ever leaves your phone.") {
                    PrivacyArt()
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            dots
                .padding(.bottom, 18)

            Button(action: next) {
                if page == pageCount - 1 {
                    Label(isReplay ? "Done" : "Step into the workshop", systemImage: "gift.fill")
                } else {
                    Text("Next")
                }
            }
            .buttonStyle(GiftlyPrimaryButtonStyle())
            .frame(maxWidth: 420)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground()
    }

    private var topBar: some View {
        HStack {
            Spacer()
            if page < pageCount - 1 {
                Button(isReplay ? "Close" : "Skip") {
                    Haptics.tap()
                    onFinish()
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == page ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                    .frame(width: i == page ? 22 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35), value: page)
        .accessibilityElement()
        .accessibilityLabel("Page \(page + 1) of \(pageCount)")
    }

    private func next() {
        Haptics.tap()
        if page < pageCount - 1 {
            withAnimation { page += 1 }
        } else {
            onFinish()
        }
    }
}

private struct IntroPage<Art: View>: View {
    let title: String
    let message: String
    @ViewBuilder var art: () -> Art

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)
            art()
                .frame(height: 300)
                .frame(maxWidth: .infinity)
            VStack(spacing: 10) {
                Text(title)
                    .font(.workshop(28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 8)
        }
    }
}

// MARK: - Page art

private struct WelcomeArt: View {
    var body: some View {
        VStack(spacing: 6) {
            ElfView(pose: .cheering, size: 150)
            Text("Giftly")
                .font(.workshop(44, weight: .bold))
        }
    }
}

/// A plain words wish turning into a priced product, on a loop.
private struct WishToProductArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var found = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 8) {
                Text("\"the lego race car with lights\"")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GiftlyTheme.card))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                ElfView(pose: found ? .cheering : .reading, size: 56)
            }

            Image(systemName: "arrow.down")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .opacity(found ? 1 : 0.3)

            GiftlyCard(padding: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.tint.opacity(0.12))
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: "car.side.fill").font(.title2).foregroundStyle(.tint))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LEGO Speed Champions Race Car")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("Target  ·  $24.99")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label("\(Workshop.elfName)'s pick, fits the budget", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(GiftlyTheme.evergreen)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: 320)
            .opacity(found ? 1 : 0)
            .scaleEffect(found ? 1 : 0.92)
        }
        .padding(.horizontal, 24)
        .task {
            if reduceMotion { found = true; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { found = true }
                try? await Task.sleep(for: .seconds(3.2))
                withAnimation(.easeOut(duration: 0.3)) { found = false }
            }
        }
    }
}

/// Mock "Coming up" rows with the live gift boxes.
private struct ComingUpArt: View {
    var body: some View {
        GiftlyCard(padding: 6) {
            VStack(spacing: 0) {
                row(title: "Mom's Birthday", detail: "in 9 days  ·  2 of 3 picked",
                    color: Color(hex: "E4572E"), stage: .wiggle, kind: .birthday, seed: 0)
                Divider().padding(.leading, 62)
                row(title: "Sophia's Christmas", detail: "in 2 days  ·  all bought",
                    color: Color(hex: "2F7D4F"), stage: .glint, kind: .christmas, seed: 1.3)
                Divider().padding(.leading, 62)
                row(title: "Our Anniversary", detail: "in 5 weeks  ·  1 idea",
                    color: Color(hex: "B565C9"), stage: .calm, kind: .anniversary, seed: 2.1)
                BudgetDemo()
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: 340)
        .padding(.horizontal, 24)
    }

    private func row(title: String, detail: String, color: Color, stage: GiftStage,
                     kind: OccasionKind, seed: Double) -> some View {
        HStack(spacing: 12) {
            GiftBoxMark(color: color, stage: stage, size: 40, seed: seed, kind: kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

private struct BudgetDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Mom's budget").font(.caption.weight(.semibold))
                Spacer()
                Text("$62 of $100").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: 0.62)
        }
    }
}

/// A handwritten list becoming wish chips.
private struct ScanArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0
    private let items = ["bike with a bell", "slime kit", "Switch", "unicorn pajamas"]

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dear Santa,")
                    .font(.system(.headline, design: .serif).italic())
                ForEach(items.indices, id: \.self) { i in
                    Text("\(i + 1). \(items[i])")
                        .font(.system(.subheadline, design: .serif).italic())
                }
                Text("love, Sophia")
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(width: 160, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "FFFDF5")))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.black.opacity(0.06))
            )
            .rotationEffect(.degrees(-3))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { i in
                    Label(items[i], systemImage: "gift")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.tint.opacity(0.12)))
                        .foregroundStyle(.tint)
                        .opacity(i < shown ? 1 : 0)
                        .offset(x: i < shown ? 0 : -14)
                }
            }
            .frame(width: 150, alignment: .leading)
        }
        .task {
            if reduceMotion { shown = items.count; return }
            while !Task.isCancelled {
                shown = 0
                try? await Task.sleep(for: .seconds(0.8))
                for _ in items {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { shown += 1 }
                    try? await Task.sleep(for: .seconds(0.45))
                }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 0.3)) { shown = 0 }
                try? await Task.sleep(for: .seconds(0.4))
            }
        }
    }
}

private struct PrivacyArt: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.tint.opacity(0.10))
                .frame(width: 200, height: 200)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 84))
                .foregroundStyle(.tint)
            ElfView(pose: .waving, size: 76)
                .offset(x: 92, y: 70)
        }
    }
}
