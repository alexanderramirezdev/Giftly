//
//  AppSession.swift
//  Giftly
//
//  App-wide runtime state that is NOT persisted to SwiftData/CloudKit:
//  which role the app is currently in, and whether the parental gate has
//  been cleared this session. Role is the single most important switch in
//  the app — it decides whether the network and prices are reachable at all.
//

import Foundation
import SwiftUI

enum Role: String, Codable, CaseIterable {
    case parent
    case kid

    var display: String {
        switch self {
        case .parent: return "Grown-up"
        case .kid:    return "Kid"
        }
    }
}

/// Observable session state. Injected into the environment at the app root.
///
/// Design rule: the KID role must never be able to reach the price/network
/// layer. We enforce that in two places — the UI simply doesn't show those
/// controls in kid mode, AND the services check `session.role == .parent`
/// before doing any network call. Belt and suspenders, because this is the
/// COPPA-relevant boundary.
@Observable
final class AppSession {
    /// v1 ships parent only. Flip to true in v2 (January) to bring back the
    /// role picker, kid mode and the parental gate. All kid code stays in the
    /// project; this flag is the only switch.
    static let kidModeEnabled = false

    var role: Role = AppSession.kidModeEnabled ? .kid : .parent   // with kid mode on, start locked down
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "giftly_onboarded")

    /// Set true for the duration of a parent session once the gate is passed.
    /// Reset to false whenever the app backgrounds, so a kid can't pick up an
    /// unlocked phone and be in parent mode.
    private(set) var gateCleared: Bool = false

    /// The device's declared age range, if the system told us (iOS 18.4+).
    /// nil = unknown / not asked / older OS.
    var declaredAgeIsChild: Bool? = nil

    func clearGate() { gateCleared = true }
    func lockGate()  { gateCleared = false; role = AppSession.kidModeEnabled ? .kid : .parent }

    /// Marks first launch done and remembers it across launches.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "giftly_onboarded")
    }

    /// Can the current context touch the network / show prices?
    var networkAllowed: Bool { role == .parent }

    /// Should we DEFAULT to kid role based on the declared age signal?
    var shouldDefaultToKid: Bool { declaredAgeIsChild == true }

    /// The device AFFIRMATIVELY says this is an adult (iOS 18.4+ Declared Age
    /// Range returned an adult band). Only this bypasses the parental gate for
    /// "I'm a grown-up". nil (unknown) or child does NOT bypass — the gate is
    /// required. This is the COPPA-safe default: a kid on an unknown-age device
    /// cannot enter parent mode without passing the gate.
    var deviceSaysAdult: Bool { declaredAgeIsChild == false }
}
