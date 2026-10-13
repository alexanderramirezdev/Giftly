//
//  GiftIntelligence.swift
//  Giftly
//
//  The on-device Foundation Models layer: the "brain" that runs with NO
//  network. Every feature has a deterministic fallback, so the app works the
//  same (just plainer) on phones without Apple Intelligence.
//
//    1. clean(_:)          messy wish -> search query + brand, color, size,
//                          age range, must haves
//    2. rank(_:for:)       orders the returned products against the wish and
//                          says why the best one fits ("Pip's pick")
//    3. ideas(for:...)     gift ideas from the WHOLE profile, budget left and
//                          what's already on the list
//    4. giftNote(...)      drafts the card message to go with a gift
//    5. elfGreeting(...)   Pip's home screen line, from facts only
//    6. readEvent(...)     reads a calendar event: is it a gift occasion,
//                          whose, and what kind (Calendar / Invites import)
//
//  Pattern: check availability first (instant fallback when the model isn't
//  there), a fresh session per request, a timeout so a slow first token never
//  hangs the UI, and strings built BEFORE entering the async closure so no
//  SwiftData model crosses a concurrency boundary.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Structured output

#if canImport(FoundationModels)
@Generable
struct CleanedWish {
    @Guide(description: "A concise, searchable product name a shopping site would match, 2 to 6 words, no filler")
    var query: String

    @Guide(description: "Brand only if the wish names or clearly implies one, otherwise an empty string")
    var brand: String

    @Guide(description: "Color if the wish mentions one, otherwise an empty string")
    var color: String

    @Guide(description: "Size if the wish mentions one, like medium, size 10, or 64GB, otherwise an empty string")
    var size: String

    @Guide(description: "Age range if mentioned, like 6 to 8 or teen, otherwise an empty string")
    var ageRange: String

    @Guide(description: "Up to 3 short must have features from the wish, like lights up or wireless. Empty if none.")
    var mustHaves: [String]

    @Guide(description: "Rough price band: budget, mid, or premium")
    var priceBand: String

    @Guide(description: "One line reason this is a good gift, friendly tone")
    var blurb: String
}

@Generable
struct ProductPick {
    @Guide(description: "The number of the product that best matches the wish")
    var bestIndex: Int

    @Guide(description: "Every product number, ordered from best match to worst match, each listed once")
    var ranking: [Int]

    @Guide(description: "One short, friendly sentence on why the best product fits the wish, under 20 words")
    var reason: String
}

@Generable
struct GiftIdeaDraft {
    @Guide(description: "A specific, buyable gift idea, 2 to 8 words")
    var idea: String

    @Guide(description: "Why it fits this person, under 15 words, based only on the profile")
    var why: String
}

@Generable
struct GiftIdeaDraftList {
    @Guide(description: "4 to 6 distinct gift ideas tailored to the profile")
    var ideas: [GiftIdeaDraft]
}

@Generable
struct GiftNoteDraft {
    @Guide(description: "The card message, 1 to 3 sentences, written in first person from the gift giver")
    var message: String
}

@Generable
struct AlternativeSearches {
    @Guide(description: "3 short product searches, 2 to 5 words each, for things a store would actually sell that are close to the wish")
    var searches: [String]
}

@Generable
struct PipLine {
    @Guide(description: "Pip's rewrite of the message: one or two short sentences, at most 24 words, keeping every name, number and day word exactly")
    var line: String
}

@Generable
struct ScannedWishList {
    @Guide(description: "The child's first name if the list says who wrote it, like 'Love, Mia' or 'Mia's list', otherwise an empty string")
    var childName: String

    @Guide(description: "Each separate gift wish on the list, in plain words, 2 to 8 words each, with kid spelling fixed and brand names kept. Leave out greetings, sign offs, numbering, and anything that isn't a gift.")
    var items: [String]
}

@Generable
struct TextedWishList {
    @Guide(description: "First name of the person the gifts are for, if the messages say (it may be the other person, or a child they mention like 'for Mia'). Otherwise an empty string.")
    var forName: String

    @Guide(description: "Each gift they asked for or agreed to, in plain searchable words, 2 to 8 words each, brand and model names kept. Leave out chit chat, questions, prices, times, links text, and anything that isn't a gift.")
    var items: [String]
}

@Generable
struct EventReading {
    @Guide(description: "True only if this event is an occasion where people usually give gifts: a birthday, birthday party, holiday, anniversary, wedding, baby shower, graduation, or similar")
    var isGiftOccasion: Bool

    @Guide(description: "The first name of the person the occasion is for, taken from the title, or an empty string if unclear")
    var personName: String

    @Guide(description: "One of: birthday, christmas, anniversary, holiday, graduation, wedding, babyShower, other")
    var kind: String
}
#endif

// MARK: - Plain types the rest of the app uses (independent of the SDK)

struct WishInterpretation {
    var query: String
    var priceBand: String
    var blurb: String
    var brand: String = ""
    var color: String = ""
    var size: String = ""
    var ageRange: String = ""
    var mustHaves: [String] = []

    /// "LEGO · red · ages 6 to 8 · lights up", for chips and storage.
    var detailsLine: String {
        var parts: [String] = []
        if !brand.isEmpty { parts.append(brand) }
        if !color.isEmpty { parts.append(color) }
        if !size.isEmpty { parts.append(size) }
        if !ageRange.isEmpty { parts.append("ages \(ageRange)") }
        parts.append(contentsOf: mustHaves)
        return parts.joined(separator: " · ")
    }
}

struct RankedProducts {
    var products: [RemoteProduct]
    /// Why products[0] is the pick. Empty when no model was available.
    var reason: String
}

struct GiftSuggestion: Identifiable, Hashable {
    let id = UUID()
    let idea: String
    let why: String
}

enum NoteTone: String, CaseIterable, Identifiable {
    case warm, funny, short
    var id: String { rawValue }
    var display: String {
        switch self {
        case .warm:  return "Warm"
        case .funny: return "Funny"
        case .short: return "Short"
        }
    }
}

struct EventGuess {
    var isGiftOccasion: Bool
    var personName: String
    var kind: OccasionKind
}

// MARK: - Service

@Observable
final class GiftIntelligence {

    static let shared = GiftIntelligence()

    private let timeout: TimeInterval = 12
    private var greetingCache: [String: String] = [:]

    private init() {}

    /// True when Apple Intelligence's on-device model is ready on this phone.
    var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    // MARK: Prewarm

    /// Call once on launch so the first real request isn't a cold load.
    func prewarm() {
        #if canImport(FoundationModels)
        guard isModelAvailable else { return }
        Task.detached(priority: .utility) {
            let session = LanguageModelSession()
            session.prewarm()
        }
        #endif
    }

    // MARK: 1. Clean a wish into a query plus details

    func clean(_ rawText: String) async -> WishInterpretation {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WishInterpretation(query: "", priceBand: "mid", blurb: "")
        }

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.cleanInstructions
            let prompt = "Turn this gift wish into a clean product search and pull out its details. Wish: \"\(trimmed)\""
            do {
                let result = try await withTimeout(timeout) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: CleanedWish.self)
                    return response.content
                }
                let query = Self.noDashes(result.query)
                return WishInterpretation(
                    query: query.isEmpty ? trimmed : query,
                    priceBand: result.priceBand,
                    blurb: Self.noDashes(result.blurb),
                    brand: Self.noDashes(result.brand),
                    color: Self.noDashes(result.color),
                    size: Self.noDashes(result.size),
                    ageRange: Self.noDashes(result.ageRange),
                    mustHaves: Array(result.mustHaves
                        .map { Self.noDashes($0) }
                        .filter { !$0.isEmpty }
                        .prefix(3))
                )
            } catch {
                return Self.deterministicClean(trimmed)
            }
        }
        #endif
        return Self.deterministicClean(trimmed)
    }

    // MARK: 2. Rank the returned products ("Pip's pick")

    func rank(_ products: [RemoteProduct], for wish: String, details: WishInterpretation) async -> RankedProducts {
        guard products.count > 1 else { return RankedProducts(products: products, reason: "") }

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.rankInstructions
            let list = products.enumerated().map { index, p in
                let price = String(format: "$%.2f", Double(p.priceCents) / 100)
                return "\(index). \(p.title) | \(p.retailer) | \(price)"
            }.joined(separator: "\n")
            let detailText = details.detailsLine.isEmpty ? "none" : details.detailsLine
            let prompt = """
            The wish, in the gift giver's words: "\(wish)"
            Details pulled from it: \(detailText)
            Products:
            \(list)
            """
            do {
                let pick = try await withTimeout(timeout) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: ProductPick.self)
                    return response.content
                }
                // Never trust indices blindly: keep only valid, unique ones,
                // then append anything the model left out.
                var order: [Int] = []
                let valid = 0..<products.count
                if valid.contains(pick.bestIndex) { order.append(pick.bestIndex) }
                for i in pick.ranking where valid.contains(i) && !order.contains(i) { order.append(i) }
                for i in valid where !order.contains(i) { order.append(i) }
                return RankedProducts(products: order.map { products[$0] },
                                      reason: Self.noDashes(pick.reason))
            } catch {
                return Self.deterministicRank(products, details: details)
            }
        }
        #endif
        return Self.deterministicRank(products, details: details)
    }

    // MARK: 3. Gift ideas from the whole profile

    /// - Parameters:
    ///   - occasionTitle: e.g. "Mom's Birthday", if ideas are for one occasion
    ///   - budgetLeftCents: remaining budget, if one is set
    func ideas(for person: Person, occasionTitle: String? = nil, budgetLeftCents: Int? = nil) async -> [GiftSuggestion] {
        let profile = person.profileSummary
        var listed: [String] = []
        for occasion in person.occasions ?? [] {
            for wish in occasion.wishes ?? [] {
                let title: String = wish.chosenMatch?.title ?? wish.rawText
                listed.append(title)
            }
        }
        let onList: String = listed.prefix(15).joined(separator: "; ")
        let interests = person.interests
        let colors = person.favoriteColors
        let stores = person.favoriteStores
        let name = person.firstName

        guard !profile.isEmpty else { return [] }

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.ideaInstructions
            var prompt = "Suggest gifts for \(name).\nProfile:\n\(profile)"
            if let occasionTitle { prompt += "\nOccasion: \(occasionTitle)" }
            if let budgetLeftCents, budgetLeftCents > 0 {
                prompt += "\nBudget left: about $\(budgetLeftCents / 100). Keep ideas within it."
            }
            if !onList.isEmpty { prompt += "\nAlready on their list (do not repeat): \(onList)" }
            do {
                let drafts = try await withTimeout(timeout) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: GiftIdeaDraftList.self)
                    return response.content.ideas
                }
                let suggestions = drafts
                    .filter { !$0.idea.trimmingCharacters(in: .whitespaces).isEmpty }
                    .map { GiftSuggestion(idea: Self.noDashes($0.idea), why: Self.noDashes($0.why)) }
                if !suggestions.isEmpty { return suggestions }
            } catch {
                // fall through to the fallback
            }
        }
        #endif
        return Self.deterministicIdeas(interests: interests, colors: colors, stores: stores)
    }

    // MARK: 4. Gift note

    func giftNote(recipient: String, relationship: String, occasion: String,
                  gift: String, tone: NoteTone) async -> String {
        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.noteInstructions
            let toneText: String
            switch tone {
            case .warm:  toneText = "warm and heartfelt"
            case .funny: toneText = "lighthearted and a little funny, never mean"
            case .short: toneText = "short and sweet, one sentence"
            }
            let prompt = """
            Write a gift card message.
            To: \(recipient)\(relationship.isEmpty ? "" : " (\(relationship))")
            Occasion: \(occasion)
            The gift: \(gift)
            Tone: \(toneText)
            """
            do {
                let note = try await withTimeout(timeout) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: GiftNoteDraft.self)
                    return response.content.message
                }
                let cleaned = Self.noDashes(note)
                if !cleaned.isEmpty { return cleaned }
            } catch {
                // fall through
            }
        }
        #endif
        return Self.templateNote(recipient: recipient, occasion: occasion, tone: tone)
    }

    // MARK: 5. Pip's greeting

    /// Returns a model written line built only from `facts`, or `fallback`.
    /// Cached per facts string so it doesn't regenerate on every appear.
    func elfGreeting(facts: String, fallback: String) async -> String {
        if let cached = greetingCache[facts] { return cached }

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.elfInstructions
            let prompt = "Facts:\n\(facts)\nWrite Pip's one line for the home screen."
            do {
                let line = try await withTimeout(8) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt)
                    return response.content
                }
                let cleaned = Self.noDashes(line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
                // Guard rails: short, single line, otherwise use the template.
                if !cleaned.isEmpty, cleaned.count <= 140, !cleaned.contains("\n") {
                    greetingCache[facts] = cleaned
                    return cleaned
                }
            } catch {
                // fall through
            }
        }
        #endif
        return fallback
    }

    // MARK: 5b. Pip's voice (the good version)

    /// Rewrites an already correct message in Pip's voice. The template is
    /// built from real data, so the facts are right before the model sees
    /// them; the model only changes the wording. Every token in `keep`
    /// (names, amounts, day counts) must survive or the template is used.
    /// Cached per message per day, so Pip doesn't reword on every appear but
    /// still feels fresh day to day.
    func pipVoice(_ template: String, keep: [String]) async -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        let key = "\(day)|\(template)"
        if let cached = greetingCache[key] { return cached }

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.pipVoiceInstructions
            let moods = ["cozy", "excited", "cheerful", "proud", "busy but happy"]
            let mood = moods[day % moods.count]
            let prompt = "Today Pip feels \(mood).\nMessage: \"\(template)\""
            do {
                let result = try await withTimeout(8) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: PipLine.self)
                    return response.content.line
                }
                let line = Self.noDashes(result).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if Self.isFaithful(line, to: template, keep: keep) {
                    greetingCache[key] = line
                    return line
                }
            } catch {
                // fall through to the template
            }
        }
        #endif
        greetingCache[key] = template
        return template
    }

    /// Guard rails for Pip's rewrite: short, single line, every kept fact
    /// present, every number in the output also in the template (so nothing
    /// is invented), and no spelled out number words.
    static func isFaithful(_ line: String, to template: String, keep: [String]) -> Bool {
        guard !line.isEmpty, !line.contains("\n") else { return false }
        let words = line.split(separator: " ")
        guard words.count >= 4, words.count <= 30 else { return false }
        let lowerLine = line.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        for token in keep where !token.isEmpty {
            let wanted = token.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
            if !lowerLine.contains(wanted) { return false }
        }
        // Same numbers in and out: nothing dropped, nothing invented.
        let numbersIn: (String) -> Set<String> = { text in
            Set(text.split(whereSeparator: { !$0.isNumber }).map(String.init).filter { !$0.isEmpty })
        }
        if numbersIn(line) != numbersIn(template) { return false }
        // Day words must survive too.
        for dayWord in ["today", "tomorrow"] where template.lowercased().contains(dayWord) {
            if !lowerLine.contains(dayWord) { return false }
        }
        let spelled = ["zero", "one hundred", "twenty", "thirty", "forty", "fifty", "hundred"]
        for word in spelled where lowerLine.contains(word) && !template.lowercased().contains(word) {
            return false
        }
        return true
    }

    // MARK: 6a. Read a scanned wish list

    /// Turns text read off a photo of a kid's list (often messy handwriting)
    /// into clean wishes, plus the child's name if the list is signed.
    func parseWishList(_ text: String) async -> (childName: String, items: [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", []) }
        let fallback = Self.fallbackListParse(trimmed)

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.listInstructions
            let prompt = "Text read from a photo of a wish list:\n\(String(trimmed.prefix(2500)))"
            do {
                let result = try await withTimeout(15) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: ScannedWishList.self)
                    return response.content
                }
                var seen = Set<String>()
                var items: [String] = []
                for raw in result.items {
                    let item = Self.noDashes(raw)
                    let key = item.lowercased()
                    if !item.isEmpty, !seen.contains(key) {
                        seen.insert(key)
                        items.append(item)
                    }
                }
                if !items.isEmpty {
                    return (Self.noDashes(result.childName), items)
                }
            } catch {
                // fall through
            }
        }
        #endif
        return fallback
    }

    /// Gift wishes from a text conversation (screenshots or pasted text).
    /// Lines may start with "Them:" (the other person) or "Me:" (the parent).
    func parseConversation(_ transcript: String, contactName: String = "") async -> (forName: String, items: [String]) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (contactName, []) }

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.textedListInstructions
            var prompt = "Text conversation:\n\(String(trimmed.prefix(3000)))"
            if !contactName.isEmpty { prompt += "\nThe other person in the thread is named: \(contactName)" }
            do {
                let result = try await withTimeout(15) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: TextedWishList.self)
                    return response.content
                }
                var seen = Set<String>()
                var items: [String] = []
                for raw in result.items {
                    let item = Self.noDashes(raw)
                    if !item.isEmpty, seen.insert(item.lowercased()).inserted { items.append(item) }
                }
                if !items.isEmpty {
                    let name = Self.noDashes(result.forName)
                    return (name.isEmpty ? contactName : name, items)
                }
            } catch {
                // fall through
            }
        }
        #endif
        return (contactName, Self.fallbackConversationParse(trimmed))
    }

    /// Without the model: the other person's lines, with "I want" style lead ins
    /// stripped and lists split on commas and "and".
    static func fallbackConversationParse(_ text: String) -> [String] {
        let leadIns = ["i would love", "i'd love", "i really want", "i want", "can i get", "could i get",
                       "can you get me", "maybe", "also", "and", "a ", "an ", "the "]
        let chatter = ["lol", "haha", "ok", "okay", "thanks", "thank you", "love you", "yes", "no", "sure", "omg"]
        var out: [String] = []
        for raw in text.split(whereSeparator: { $0.isNewline }) {
            var line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Me:") { continue }
            if line.hasPrefix("Them:") { line = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
            if line.hasSuffix("?") { continue }
            for piece in line.components(separatedBy: CharacterSet(charactersIn: ",;\n")) {
                for part in piece.components(separatedBy: " and ") {
                    var item = part.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                    var changed = true
                    while changed {
                        changed = false
                        for lead in leadIns where item.lowercased().hasPrefix(lead) {
                            item = String(item.dropFirst(lead.count)).trimmingCharacters(in: .whitespaces)
                            changed = true
                        }
                    }
                    let words = item.split(separator: " ").count
                    if words >= 1, words <= 8, !chatter.contains(item.lowercased()) {
                        out.append(noDashes(item))
                    }
                }
            }
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Without the model: one wish per line, numbering and bullets stripped,
    /// greetings and sign offs dropped.
    static func fallbackListParse(_ text: String) -> (childName: String, items: [String]) {
        var name = ""
        var items: [String] = []
        let skip = ["dear santa", "santa", "thank you", "thanks", "merry christmas", "my list", "wish list", "christmas list"]
        for rawLine in text.split(whereSeparator: { $0.isNewline }) {
            var line = String(rawLine).trimmingCharacters(in: .whitespaces)
            while let first = line.first, first.isNumber || "-*.)•·#".contains(first) || first == " " {
                line.removeFirst()
            }
            line = line.trimmingCharacters(in: .whitespaces)
            let lower = line.lowercased()
            if lower.hasPrefix("love") || lower.hasPrefix("from") {
                let parts = line.split(separator: " ")
                if parts.count >= 2 { name = String(parts[parts.count - 1]).trimmingCharacters(in: .punctuationCharacters) }
                continue
            }
            if line.count < 2 || skip.contains(where: { lower.hasPrefix($0) }) { continue }
            if !items.contains(where: { $0.lowercased() == lower }) { items.append(line) }
        }
        return (name, items)
    }

    // MARK: 6b. Alternatives when nothing matched

    /// 3 close, searchable alternatives so a wish never dead ends.
    func alternatives(for wish: String) async -> [String] {
        let trimmed = wish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let fallback = Self.fallbackAlternatives(trimmed)

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.alternativeInstructions
            let prompt = "A store search for this gift wish found nothing: \"\(trimmed)\". Suggest close alternatives."
            do {
                let result = try await withTimeout(8) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: AlternativeSearches.self)
                    return response.content.searches
                }
                let cleaned = result.map { Self.noDashes($0) }.filter { !$0.isEmpty }
                if !cleaned.isEmpty { return Array(cleaned.prefix(3)) }
            } catch {
                // fall through
            }
        }
        #endif
        return fallback
    }

    /// Simpler versions of a query for the search ladder: drop the extracted
    /// details, then keep only the first few words.
    static func broaderQueries(for query: String, details: WishInterpretation) -> [String] {
        let detailWords = Set((details.color + " " + details.size + " " + details.ageRange + " " + details.mustHaves.joined(separator: " "))
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init))
        let words = query.split(separator: " ").map(String.init)
        var out: [String] = []
        let stripped = words.filter { !detailWords.contains($0.lowercased()) }.joined(separator: " ")
        if !stripped.isEmpty { out.append(stripped) }
        if words.count > 3 { out.append(words.prefix(3).joined(separator: " ")) }
        if words.count > 2 { out.append(words.prefix(2).joined(separator: " ")) }
        return out
    }

    // MARK: 6. Read a calendar event

    func readEvent(title: String, notes: String?) async -> EventGuess {
        let fallback = Self.heuristicEvent(title: title)

        #if canImport(FoundationModels)
        if isModelAvailable {
            let instructions = Self.eventInstructions
            let notesText = String((notes ?? "").prefix(300))
            let prompt = "Event title: \"\(title)\"\nEvent notes: \"\(notesText)\""
            do {
                let reading = try await withTimeout(6) {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt, generating: EventReading.self)
                    return response.content
                }
                let kind = OccasionKind(rawValue: reading.kind) ?? fallback.kind
                let name = Self.noDashes(reading.personName)
                return EventGuess(isGiftOccasion: reading.isGiftOccasion,
                                  personName: name.isEmpty ? fallback.personName : name,
                                  kind: kind)
            } catch {
                return fallback
            }
        }
        #endif
        return fallback
    }

    // MARK: - Instructions

    #if canImport(FoundationModels)
    private static let cleanInstructions = """
    You convert a casual gift wish into a tight product search query a shopping \
    website would match, and you pull out any details the wish states. Strip filler \
    words. Keep brand names if present. Never invent a brand, model, color, or size \
    that the wish did not state or clearly imply. Leave a detail empty when unsure. \
    When the wish is only a device or console name, like PS5, Xbox, Switch or iPad, \
    the giver means the device itself, so search for the console or device, not \
    games, controllers or accessories. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let rankInstructions = """
    You help a parent pick the product that best matches a gift wish. Compare each \
    numbered product title to the wish and its details. Prefer exact matches on \
    brand, product type, and must have features. Ignore price unless the wish \
    mentions one. If the wish names only a console or device, pick the console or \
    device itself over games, controllers, cases and other accessories. \
    Answer with product numbers from the list only. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let ideaInstructions = """
    You suggest thoughtful, specific, buyable gift ideas from a person's profile. \
    Name the kind of thing, not a vague category. Respect sizes, favorite colors, \
    and favorite stores when they help. Never suggest anything they already own, \
    anything they dislike, or anything already on their list. Never suggest \
    anything unsafe or age inappropriate. Base every reason only on the profile. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let noteInstructions = """
    You write short gift card messages that sound like a real person, not a \
    greeting card company. Use the recipient's name once. Do not mention the price. \
    Do not use emojis or hashtags. Do not invent memories or facts. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let elfInstructions = """
    You are Pip, a cheerful elf in Santa's workshop who helps a parent plan gifts. \
    Write exactly one short line, at most 18 words, for the home screen. Use ONLY \
    the facts given. Never invent names, dates, numbers, or gifts. No emojis. Be \
    warm and a little playful, never pushy about spending. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let alternativeInstructions = """
    You help when a shopping search for a gift wish found nothing. Suggest close, \
    common products a big store would carry, in plain search words. Keep the spirit \
    of the wish. Never invent brands or model numbers. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let pipVoiceInstructions = """
    You are Pip, a cheerful elf in Santa's workshop who helps a parent plan gifts. \
    Rewrite the message in your own warm, slightly playful voice for the app's home \
    screen. Keep every name, dollar amount, number, and day word (today, tomorrow, \
    in 3 days) exactly as written. Do not add any new facts, numbers, or gifts. One \
    or two short sentences, at most 24 words. No emojis. Never pushy about spending.
    Examples:
    Message: "Mom's birthday is tomorrow and the list is empty. Add a wish and I'll find prices."
    Pip: "Mom's birthday is tomorrow and her list is still empty! Give me one wish and I'll hunt down prices."
    Message: "Andrew's birthday is $46 over budget. Want to swap something cheaper?"
    Pip: "Uh oh, Andrew's birthday is $46 over budget. Want me to find something a little cheaper?"
    Message: "Sophia's birthday is in 6 days. 2 gifts left to buy."
    Pip: "Sophia's birthday is in 6 days and we've got 2 gifts left to buy. Let's do this!" \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let listInstructions = """
    You read the text from a photo of a child's wish list or letter to Santa, which \
    may have messy handwriting and spelling. Return each separate gift wish as a short, \
    clean, searchable phrase. Fix spelling (legos becomes LEGO, pokemon becomes Pokemon). \
    Keep brand and character names. Split lines that list two things. Leave out \
    greetings, sign offs, numbering, and anything that is not a gift. Never invent \
    items that aren't on the list. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let textedListInstructions = """
    You read a text message conversation where someone says what they want as a \
    gift. Lines starting with "Them:" are the other person; lines starting with \
    "Me:" are the gift giver. Return every gift the other person asked for, plus \
    anything the gift giver suggested that the other person agreed to. Turn each \
    into a short, searchable phrase with brand, model, size and color kept (for \
    example "the blue one in a medium" after "Nike hoodie" becomes "blue Nike hoodie \
    medium"). Leave out greetings, questions, jokes, prices, times, and anything \
    that isn't a gift. Never invent items. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """

    private static let eventInstructions = """
    You read one calendar event and decide whether it is an occasion where people \
    give gifts, whose occasion it is, and what kind it is. Meetings, appointments, \
    work events, and reminders are not gift occasions. \
    Never use dashes, hyphens, or em dashes in any output; write plain words \
    separated by spaces or commas.
    """
    #endif

    // MARK: - No dashes (product rule)

    /// Hard guarantee that model output carries no dashes. Em/en dashes
    /// between clauses become a comma; a hyphen between words becomes a space.
    static func noDashes(_ s: String) -> String {
        var out = s
            .replacingOccurrences(of: " \u{2014} ", with: ", ")
            .replacingOccurrences(of: " \u{2013} ", with: ", ")
            .replacingOccurrences(of: "\u{2014}", with: ", ")
            .replacingOccurrences(of: "\u{2013}", with: ", ")
            .replacingOccurrences(of: "-", with: " ")
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out
            .replacingOccurrences(of: " ,", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Deterministic fallbacks

    private static func deterministicClean(_ raw: String) -> WishInterpretation {
        let filler: Set<String> = ["the", "a", "an", "some", "thing", "that",
                                   "with", "like", "kind", "of", "really", "want"]
        let cleaned = raw
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !filler.contains($0) }
            .joined(separator: " ")
        return WishInterpretation(query: cleaned.isEmpty ? raw : cleaned, priceBand: "mid", blurb: "")
    }

    /// Word overlap between the wish details and each title. Honest and fast.
    private static func deterministicRank(_ products: [RemoteProduct], details: WishInterpretation) -> RankedProducts {
        let words = Set((details.query + " " + details.detailsLine)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 })
        guard !words.isEmpty else { return RankedProducts(products: products, reason: "") }
        let scored = products.enumerated().map { index, p -> (Int, Int) in
            let title = p.title.lowercased()
            return (index, words.filter { title.contains($0) }.count)
        }
        let order = scored.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }.map { $0.0 }
        return RankedProducts(products: order.map { products[$0] }, reason: "")
    }

    private static func deterministicIdeas(interests: [String], colors: String, stores: String) -> [GiftSuggestion] {
        var out = interests.prefix(4).map { GiftSuggestion(idea: "\($0) gift set", why: "They're into \($0)") }
        let firstStore = stores.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        if !firstStore.isEmpty {
            out.append(GiftSuggestion(idea: "\(firstStore) gift card", why: "One of their favorite stores"))
        }
        let firstColor = colors.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        if !firstColor.isEmpty && !out.isEmpty {
            out.append(GiftSuggestion(idea: "Anything above in \(firstColor)", why: "Their favorite color"))
        }
        return out
    }

    private static func fallbackAlternatives(_ wish: String) -> [String] {
        let words = wish.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 && !["the", "and", "with", "for", "that", "want", "wants"].contains($0) }
        var out: [String] = []
        if words.count >= 2 { out.append(words.prefix(2).joined(separator: " ")) }
        if let first = words.first { out.append("\(first) gift") }
        if let last = words.last, words.count > 1 { out.append("\(last) gift set") }
        return Array(NSOrderedSet(array: out).array.compactMap { $0 as? String }.prefix(3))
    }

    private static func templateNote(recipient: String, occasion: String, tone: NoteTone) -> String {
        switch tone {
        case .warm:
            return "\(recipient), happy \(occasion.lowercased())! I hope this makes you smile as much as you make me smile."
        case .funny:
            return "\(recipient), the elves worked overtime on this one. Happy \(occasion.lowercased())!"
        case .short:
            return "Happy \(occasion.lowercased()), \(recipient)!"
        }
    }

    /// Keyword and "Name's ..." heuristics for calendar events.
    static func heuristicEvent(title: String) -> EventGuess {
        let lower = title.lowercased()
        let kind: OccasionKind
        if lower.contains("birthday") || lower.contains("bday") || lower.contains("b-day") {
            kind = .birthday
        } else if lower.contains("christmas") || lower.contains("xmas") {
            kind = .christmas
        } else if lower.contains("anniversary") {
            kind = .anniversary
        } else if lower.contains("graduation") || lower.contains("grad party") {
            kind = .graduation
        } else if lower.contains("wedding") {
            kind = .wedding
        } else if lower.contains("baby shower") || lower.contains("babyshower") {
            kind = .babyShower
        } else if lower.contains("hanukkah") || lower.contains("diwali") || lower.contains("eid") || lower.contains("kwanzaa") {
            kind = .holiday
        } else {
            kind = .other
        }
        var name = ""
        for mark in ["'s ", "\u{2019}s "] {
            if let range = title.range(of: mark) {
                let candidate = title[title.startIndex..<range.lowerBound]
                name = candidate.split(separator: " ").last.map(String.init) ?? ""
                break
            }
        }
        return EventGuess(isGiftOccasion: kind != .other || lower.contains("party") || lower.contains("shower"),
                          personName: name, kind: kind)
    }

    // MARK: - Timeout helper

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
