//
//  ParentalGate.swift
//  Giftly
//
//  The grown-ups gate, used before switching to Parent role (v2 kid mode)
//  or anything that spends money.
//
//  Step 1: pick your birth year. Under 18 ends here for this attempt.
//  Step 2: Face ID / Touch ID (or the device passcode) confirms the device
//          owner. A kid can guess a year; they can't pass the owner's Face ID.
//  Fallback: if the device has no passcode at all, a dynamic arithmetic or
//          spelling challenge (Apple's classic parental gate) replaces step 2.
//
//  The birth year is only compared, never stored or sent anywhere.
//  Requires NSFaceIDUsageDescription in Info.plist.
//

import SwiftUI
import LocalAuthentication

struct ParentalGateChallenge {
    let prompt: String
    let answer: String

    static func random() -> ParentalGateChallenge {
        if Bool.random() {
            let a = Int.random(in: 11...19)
            let b = Int.random(in: 2...9)
            return .init(prompt: "To continue, type the answer: \(a) + \(b)", answer: String(a + b))
        } else {
            let n = Int.random(in: 3...9)
            let words = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
            return .init(prompt: "To continue, spell the number \(n) in letters.", answer: words[n])
        }
    }

    func accepts(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == answer.lowercased()
    }
}

struct ParentalGateView: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    private enum Step { case birthYear, authenticating, challenge, tooYoung }

    private static let currentYear = Calendar.current.component(.year, from: .now)
    private static let adultAge = 18

    @State private var step: Step = .birthYear
    // Starts on the current year on purpose: nobody passes by tapping Continue.
    @State private var birthYear = ParentalGateView.currentYear
    @State private var authFailed = false
    @State private var challenge = ParentalGateChallenge.random()
    @State private var answer = ""
    @State private var wrongAnswer = false

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(GiftlyTheme.cranberry)

                Text("Grown-ups only")
                    .font(.workshop(24, weight: .bold))
                    .foregroundStyle(.primary)

                switch step {
                case .birthYear:      birthYearStep
                case .authenticating: ProgressView().tint(GiftlyTheme.cranberry)
                case .challenge:      challengeStep
                case .tooYoung:       tooYoungStep
                }
            }
            .padding(28)
            .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground()
    }

    // MARK: Steps

    private var birthYearStep: some View {
        VStack(spacing: 16) {
            Text("What year were you born?")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("Birth year", selection: $birthYear) {
                ForEach((ParentalGateView.currentYear - 100)...ParentalGateView.currentYear, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)

            if authFailed {
                Text("That didn't work. Try again.")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            buttons(continueTitle: "Continue", disabled: false) { checkYear() }
        }
    }

    private var challengeStep: some View {
        VStack(spacing: 16) {
            Text(challenge.prompt)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            TextField("Answer", text: $answer)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .frame(maxWidth: 220)

            if wrongAnswer {
                Text("Not quite. Try again.")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            buttons(continueTitle: "Continue", disabled: answer.isEmpty) { checkAnswer() }
        }
    }

    private var tooYoungStep: some View {
        VStack(spacing: 16) {
            Text("This part is for grown-ups. Ask a parent to help.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("OK", action: onCancel)
                .buttonStyle(.borderedProminent)
                .tint(GiftlyTheme.cranberry)
        }
    }

    private func buttons(continueTitle: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button("Cancel", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
            Button(continueTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(GiftlyTheme.cranberry)
                .disabled(disabled)
        }
    }

    // MARK: Logic

    private func checkYear() {
        let age = ParentalGateView.currentYear - birthYear
        guard age >= ParentalGateView.adultAge else {
            step = .tooYoung
            return
        }
        authenticate()
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        // .deviceOwnerAuthentication = Face ID / Touch ID with passcode fallback.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode on this device: fall back to the classic challenge.
            step = .challenge
            return
        }
        step = .authenticating
        authFailed = false
        Task {
            do {
                let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                          localizedReason: "Confirm you're the grown-up")
                if ok {
                    onSuccess()
                } else {
                    step = .birthYear
                    authFailed = true
                }
            } catch {
                step = .birthYear
                authFailed = true
            }
        }
    }

    private func checkAnswer() {
        if challenge.accepts(answer) {
            onSuccess()
        } else {
            wrongAnswer = true
            answer = ""
            challenge = .random()
        }
    }
}
