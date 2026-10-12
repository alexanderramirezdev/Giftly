//
//  GiftIntelligence.swift
//  Giftly
//
//  The on-device Foundation Models layer — the "brain" that runs with NO
//  network. Two jobs:
//    1. clean(_:)      messy input → a tight, searchable product query
//    2. ideas(for:)    a person's interests → fresh gift suggestions
//
//  Mirrors the Doctor-Brief synthesizer pattern from KehaiCare: a real
//  LanguageModelSession when available, a deterministic fallback otherwise,
//  a prewarm, and a timeout so first-token latency never hangs the UI.
//
//  NOTE: the `import FoundationModels` + @Generable code is gated behind a
//  compile check so this file still builds on older toolchains; swap the
//  `#if canImport` fallbacks for the real calls once you're on the 26 SDK.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// Structured output we want back from the model when cleaning a wish.
#if canImport(FoundationModels)
@Generable
struct CleanedWish {
    @Guide(description: "A concise, searchable product name a shopping site would match, 2-6 words, no filler")
    var query: String

    @Guide(description: "Rough price band: budget, mid, or premium")
    var priceBand: String

    @Guide(description: "One-line reason this is a good gift, friendly tone")
    var blurb: String
}

@Generable
struct GiftIdeaList {
    @Guide(description: "3 to 5 distinct, specific gift ideas tailored to the interests")
    var ideas: [String]
}
#endif

/// Plain structs the rest of the app consumes, independent of the FM SDK.
struct WishInterpretation {
    var query: String
    var priceBand: String
    var blurb: String
}

@Observable
final class GiftIntelligence {

    static let shared = GiftIntelligence()

    private let timeout: TimeInterval = 12   // same budget KehaiCare settled on

    private init() {}

    // MARK: Prewarm

    /// Call once on app launch (parent role only) so the first real request
    /// isn't a 2-3 minute cold load.
    func prewarm() {
        #if canImport(FoundationModels)
        Task.detached(priority: .utility) {
            let session = LanguageModelSession()
            session.prewarm()
        }
        #endif
    }

    // MARK: Clean a wish into a searchable query

    func clean(_ rawText: String) async -> WishInterpretation {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WishInterpretation(query: "", priceBand: "mid", blurb: "")
        }

        #if canImport(FoundationModels)
        do {
            let result = try await withTimeout(timeout) {
                let session = LanguageModelSession(instructions: Self.cleanInstructions)
                let response = try await session.respond(
                    to: "Turn this gift wish into a clean product search. Wish: \"\(trimmed)\"",
                    generating: CleanedWish.self
                )
                return response.content
            }
            return WishInterpretation(query: Self.noDashes(result.query),
                                      priceBand: result.priceBand,
                                      blurb: Self.noDashes(result.blurb))
        } catch {
            return Self.deterministicClean(trimmed)
        }
        #else
        return Self.deterministicClean(trimmed)
        #endif
    }

    // MARK: Generate gift ideas

    func ideas(for person: Person) async -> [String] {
        let interests = person.interests
        guard !interests.isEmpty else { return [] }

        #if canImport(FoundationModels)
        do {
            let prompt = """
            Suggest gift ideas for \(person.ageBand.isEmpty ? "someone" : person.ageBand) \
            who likes \(interests.joined(separator: ", ")). \
            Be specific and buyable, not generic categories.
            """
            let result = try await withTimeout(timeout) {
                let session = LanguageModelSession(instructions: Self.ideaInstructions)
                let response = try await session.respond(to: prompt, generating: GiftIdeaList.self)
                return response.content.ideas
            }
            return result.isEmpty ? Self.deterministicIdeas(interests) : result.map(Self.noDashes)
        } catch {
            return Self.deterministicIdeas(interests)
        }
        #else
        return Self.deterministicIdeas(interests)
        #endif
    }

    // MARK: Instructions (system prompts)

    #if canImport(FoundationModels)
    private static let cleanInstructions = """
    You convert a child's or parent's casual gift wish into a tight product \
    search query a shopping website would match. Strip filler words. Keep brand \
    names if present. Never invent a specific brand or model that wasn't implied. \
    Keep it to 2 to 6 words. Never use dashes, hyphens, or em dashes in any \
    output; write plain words separated by spaces or commas.
    """

    private static let ideaInstructions = """
    You suggest thoughtful, specific, buyable gift ideas based on a person's \
    interests. Avoid vague categories like "a book"; name the kind of thing. \
    Keep each idea short. Never suggest anything unsafe or age inappropriate. \
    Never use dashes, hyphens, or em dashes; write plain words separated by \
    spaces or commas.
    """
    #endif

    // MARK: Deterministic fallbacks (no model available / timed out)

    /// Hard guarantee that FM output carries no dashes, per product rule.
    /// Em/en dashes between clauses become a comma; a hyphen between words
    /// becomes a space. Collapses doubled spaces left behind.
    static func noDashes(_ s: String) -> String {
        var out = s
            .replacingOccurrences(of: " — ", with: ", ")
            .replacingOccurrences(of: " – ", with: ", ")
            .replacingOccurrences(of: "—", with: ", ")
            .replacingOccurrences(of: "–", with: ", ")
            .replacingOccurrences(of: "-", with: " ")
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out
            .replacingOccurrences(of: " ,", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func deterministicClean(_ raw: String) -> WishInterpretation {
        // Light cleanup: trim, collapse whitespace, drop obvious filler.
        let filler: Set<String> = ["the", "a", "an", "some", "thing", "that",
                                   "with", "like", "kind", "of", "really", "want"]
        let cleaned = raw
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !filler.contains($0) }
            .joined(separator: " ")
        return WishInterpretation(
            query: cleaned.isEmpty ? raw : cleaned,
            priceBand: "mid",
            blurb: ""
        )
    }

    private static func deterministicIdeas(_ interests: [String]) -> [String] {
        // Minimal, honest fallback — just echoes interests as search seeds.
        interests.prefix(5).map { "\($0) gift set" }
    }

    // MARK: Timeout helper

    private func withTimeout<T>(_ seconds: TimeInterval,
                                _ operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
