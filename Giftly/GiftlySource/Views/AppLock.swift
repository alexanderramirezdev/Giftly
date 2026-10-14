//
//  AppLock.swift
//  Giftly
//
//  Optional Face ID lock (Settings > Privacy > Lock with Face ID), so kids or
//  a partner can't open Pip and see their presents. When it's on, Pip locks
//  whenever the app goes to the background and the app switcher shows a
//  cover instead of your lists. Uses Face ID or Touch ID with the passcode
//  as a fallback; iOS handles all of it, Pip only learns pass or fail.
//

import SwiftUI
import LocalAuthentication

enum AppLock {
    static let settingKey = "giftly_require_faceid"

    /// The name of this device's biometry, for labels.
    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return "Passcode"
        }
    }

    /// Can this device lock at all (has a passcode)?
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// Wraps the app: shows the lock screen when locked, and a privacy cover in
/// the app switcher.
struct AppLockContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @AppStorage(AppLock.settingKey) private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var locked = UserDefaults.standard.bool(forKey: AppLock.settingKey)
    @State private var authenticating = false

    var body: some View {
        ZStack {
            content()
            if lockEnabled && locked {
                LockScreen(authenticating: authenticating, onUnlock: unlock)
                    .transition(.opacity)
                    .zIndex(2)
            } else if lockEnabled && scenePhase != .active {
                // App switcher snapshot: hide the lists.
                PrivacyCover()
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: locked)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, lockEnabled { locked = true }
            if phase == .active, lockEnabled, locked { unlock() }
        }
        .onChange(of: lockEnabled) { _, on in
            if !on { locked = false }
        }
        .task {
            if lockEnabled && locked { unlock() }
        }
    }

    private func unlock() {
        guard !authenticating else { return }
        authenticating = true
        Task {
            let ok = await AppLock.authenticate(reason: "Unlock Pip to see your gift lists")
            authenticating = false
            if ok { locked = false }
        }
    }
}

private struct LockScreen: View {
    let authenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ElfView(pose: .idle, size: 120)
            Text("Shh, It's a Surprise")
                .font(.workshop(24, weight: .bold))
            Text("\(Workshop.elfName) is keeping your gift lists safe.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onUnlock) {
                Label("Unlock with \(AppLock.biometryName)", systemImage: "lock.open.fill")
            }
            .buttonStyle(GiftlyPrimaryButtonStyle())
            .disabled(authenticating)
            .frame(maxWidth: 420)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GiftlyTheme.background.ignoresSafeArea())
        .giftlyBackground()
    }
}

private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            GiftlyTheme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                ElfView(pose: .idle, size: 90)
                Text("Pip")
                    .font(.workshop(28, weight: .bold))
            }
        }
    }
}
