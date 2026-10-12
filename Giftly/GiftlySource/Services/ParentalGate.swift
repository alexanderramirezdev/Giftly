//
//  ParentalGate.swift
//  Giftly
//
//  Apple's standard "ask a grown-up" pattern. This is NOT a security
//  mechanism — it's a friction gate a young child can't casually pass, used
//  before switching to Parent role or doing anything that spends money.
//  Apple requires exactly this for kid-adjacent apps; it must NOT be a plain
//  "are you a grown-up? [Yes]" tap (that's an auto-reject). We use a dynamic
//  challenge (spell a number word, or simple arithmetic) that changes each time.
//

import SwiftUI

struct ParentalGateChallenge {
    let prompt: String
    let answer: String

    static func random() -> ParentalGateChallenge {
        // Mix of challenge types so it isn't memorizable.
        if Bool.random() {
            let a = Int.random(in: 11...19)
            let b = Int.random(in: 2...9)
            return .init(prompt: "To continue, type the answer: \(a) + \(b)",
                         answer: String(a + b))
        } else {
            let n = Int.random(in: 3...9)
            let words = ["", "one", "two", "three", "four", "five",
                         "six", "seven", "eight", "nine"]
            return .init(prompt: "To continue, spell the number \(n) in letters.",
                         answer: words[n])
        }
    }

    func accepts(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == answer.lowercased()
    }
}

struct ParentalGateView: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var challenge = ParentalGateChallenge.random()
    @State private var input = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.key")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Grown-ups only")
                .font(.title2.bold())

            Text(challenge.prompt)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            TextField("Answer", text: $input)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .frame(maxWidth: 220)

            if wrong {
                Text("Not quite — try again.")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                Button("Continue") { check() }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.isEmpty)
            }
        }
        .padding(32)
        .frame(maxWidth: 640)                 // iPad: constrain-and-center
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func check() {
        if challenge.accepts(input) {
            onSuccess()
        } else {
            wrong = true
            input = ""
            challenge = .random()             // new challenge on each miss
        }
    }
}
