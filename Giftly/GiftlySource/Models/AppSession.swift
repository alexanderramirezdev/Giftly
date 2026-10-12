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
    var role: Role = .kid                 // start locked-down; upgrade to parent via gate
    var hasCompletedOnboarding: Bool = false

    /// Set true for the duration of a parent session once the gate is passed.
    /// Reset to false whenever the app backgrounds, so a kid can't pick up an
    /// unlocked phone and be in parent mode.
    private(set) var gateCleared: Bool = false

    /// The device's declared age range, if the system told us (iOS 18.4+).
    /// nil = unknown / not asked / older OS.
    var declaredAgeIsChild: Bool? = nil

    func clearGate() { gateCleared = true }
    func lockGate()  { gateCleared = false; role = .kid }

    /// Can the current context touch the network / show prices?
    var networkAllowed: Bool { role == .parent }

    /// Should we DEFAULT to kid role based on the declared age signal?
    var shouldDefaultToKid: Bool { declaredAgeIsChild == true }
}
