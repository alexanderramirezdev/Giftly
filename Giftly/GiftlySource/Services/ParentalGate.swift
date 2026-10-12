//
//  ParentalGate.swift
//  Giftly
//
//  Apple's "ask a grown-up" gate — the friction a young child won't casually
//  pass — before entering grown-up mode or spending money. We use a
//  PRESS-AND-HOLD gate rather than arithmetic: it's warmer, instant for an
//  adult, and a small child won't deliberately hold for the full duration.
//  Apple accepts press-and-hold / long-interaction gates for kids-adjacent apps.
//

import SwiftUI

struct ParentalGateView: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    private let holdDuration: Double = 1.5

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var done = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 150, height: 150)

                // progress ring fills as you hold
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: progress)

                Image(systemName: done ? "checkmark" : "hand.tap.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.tint)
                    .scaleEffect(holding ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3), value: holding)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !holding && !done { startHold() } }
                    .onEnded { _ in if !done { cancelHold() } }
            )

            VStack(spacing: 8) {
                Text(done ? "Welcome back 👋" : "Grown-ups only")
                    .font(.title2.bold())
                Text(done ? "" : "Press and hold the circle for a moment to continue.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 44)
            }

            Spacer()

            Button("Cancel", role: .cancel) { cancelHold(); onCancel() }
                .buttonStyle(.bordered)
                .padding(.bottom, 8)
        }
        .padding(32)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground()
    }

    private func startHold() {
        holding = true
        Haptics.tap()
        timer?.invalidate()
        let step = 0.05
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { t in
            progress += CGFloat(step / holdDuration)
            if progress >= 1 {
                t.invalidate()
                succeed()
            }
        }
    }

    private func cancelHold() {
        holding = false
        timer?.invalidate()
        withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
    }

    private func succeed() {
        holding = false
        done = true
        progress = 1
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onSuccess() }
    }
}
