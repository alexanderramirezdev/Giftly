//
//  RootView.swift
//  Giftly
//
//  Top-level router: onboarding → role → the right experience.
//  The role switch is the app's spine. Kid role shows the stripped kid home
//  and can only reach parent mode through the parental gate.
//

import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @AppStorage(GiftlySeason.settingKey) private var seasonSetting = "auto"

    @State private var showingGate = false

    var body: some View {
        Group {
            if !session.hasCompletedOnboarding {
                if AppSession.kidModeEnabled {
                    OnboardingView()
                } else {
                    WorkshopWelcomeView()
                }
            } else {
                switch session.role {
                case .parent:
                    ParentHomeView(onLock: { session.lockGate() })
                case .kid:
                    KidHomeView(onRequestParent: { showingGate = true })
                }
            }
        }
        .sheet(isPresented: $showingGate) {
            ParentalGateView(
                onSuccess: {
                    session.clearGate()
                    session.role = .parent
                    GiftIntelligence.shared.prewarm()
                    showingGate = false
                },
                onCancel: { showingGate = false }
            )
            .presentationDetents([.large])
        }
        // The app's accent follows the season (or the parent's pick in Settings).
        .tint(GiftlySeason.resolve(setting: seasonSetting).accent)
    }
}

// MARK: - Onboarding / role pick

struct OnboardingView: View {
    @Environment(AppSession.self) private var session
    @State private var showingGate = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "gift.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Giftly")
                .font(.largeTitle.bold())
            Text("Every wishlist, every occasion — with real prices, so gifting is one calm list instead of a dozen tabs.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Text("Who's using Giftly?")
                .font(.headline)

            VStack(spacing: 12) {
                Button {
                    // COPPA-safe: entering grown-up mode ALWAYS requires the
                    // parental gate, UNLESS the device affirmatively says adult.
                    // Unknown age or child => gate required.
                    if session.deviceSaysAdult {
                        session.role = .parent
                        session.clearGate()
                        session.completeOnboarding()
                    } else {
                        showingGate = true
                    }
                } label: {
                    Label("I'm a grown-up", systemImage: "person.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    session.role = .kid
                    session.completeOnboarding()
                } label: {
                    Label("I'm a kid", systemImage: "figure.child")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .frame(maxWidth: 420)

            Spacer()
        }
        .padding()
        .frame(maxWidth: 640)                     // iPad: constrain-and-center
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground(.full)
        .sheet(isPresented: $showingGate) {
            ParentalGateView(
                onSuccess: {
                    session.role = .parent
                    session.clearGate()
                    session.completeOnboarding()
                    showingGate = false
                },
                onCancel: { showingGate = false }
            )
            .presentationDetents([.large])
        }
    }
}
