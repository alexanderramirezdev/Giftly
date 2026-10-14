//
//  WishFetcher.swift
//  Giftly
//
//  Background price fetch: the thing that makes the app feel alive.
//  Instead of making the parent wait on a spinner, we:
//    1. add the wish instantly (status .finding)
//    2. kick off this fetcher
//    3. it reads the wish (FM), searches prices, ranks them, and fills in the
//       result
//    4. the SwiftData update flows to the UI automatically
//
//  Rule: a wish never comes back empty without a reason and a next step.
//    • hiccups (Render waking up, a timeout, a busy notice) get one retry
//    • no match tries broader searches before giving up
//    • the monthly limit, offline, and no match each leave a plain note
//    • no match also leaves Pip's alternative searches, one tap each
//
//  Runs on the main actor because it mutates SwiftData models bound to the
//  view context. The network/FM awaits don't block the UI; they suspend.
//

import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum WishFetcher {

    /// The note on a wish that failed only because the price service couldn't
    /// be reached. ProxyWarmup retries these on its own.
    static let unreachableNote = "Couldn't reach the stores just now. Pip will try again on its own, or tap Search again."
    /// The proxy refused the app key. Also retried on its own, so fixing the
    /// key on the server heals these without a new build.
    static let keyRejectedNote = "Price search turned this version of Pip away. Please let the developer know."

    /// Fetch a price for a wish and update it in place.
    /// `autoPick` = true commits the best result (parent can swap later).
    static func fetchPrice(
        for wish: Wish,
        using brain: GiftIntelligence,
        priceService: PriceService,
        entitlements: Entitlements,
        autoPick: Bool = true
    ) async {
        wish.status = .finding
        wish.statusNote = ""
        wish.suggestionsRaw = ""

        // 1) read the wish on device. A bare device name ("PS5", "Xbox",
        //    "iPad") means the device itself, so search for that.
        let intent = ProductIntent.detect(wish.rawText)
        let interpretation = await brain.clean(wish.rawText)
        if let intent {
            wish.cleanedQuery = intent.query
        } else {
            wish.cleanedQuery = interpretation.query.isEmpty ? wish.rawText : interpretation.query
        }
        wish.detailsRaw = interpretation.detailsLine

        // 2) allowance check, with a reason instead of a silent "Idea"
        guard entitlements.canDoPriceLookup else {
            wish.status = .idea
            wish.statusNote = "You've used this month's \(entitlements.freeMonthlyLookups) free price checks. Plus removes the limit."
            return
        }

        // 3) make sure the proxy is awake (Render naps after a quiet stretch
        //    and takes up to a minute to wake). Without this the first
        //    searches failed fast and looked like "no match".
        guard await ProxyWarmup.wake() else {
            wish.status = .notFound
            wish.statusNote = unreachableNote
            Haptics.soft()
            return
        }

        // 4) search ladder: exact, then broader, then the parent's own words
        var queries: [String] = [wish.cleanedQuery]
        queries += GiftIntelligence.broaderQueries(for: wish.cleanedQuery, details: interpretation)
        queries.append(wish.rawText)
        queries = unique(queries)

        var products: [RemoteProduct] = []
        var gotAnyResponse = false
        var onlyUntrusted = false
        var charged = false
        var limitStatus = 0     // 429 (too many this hour) or 503 (daily cap) from the proxy
        var keyRejected = false
        var failures = 0
        for query in queries.prefix(4) {
            do {
                let result = try await searchWithRetry(query, priceService: priceService)
                gotAnyResponse = true
                if !charged {
                    // One wish = one price check, however many searches it took.
                    entitlements.recordLookup()
                    charged = true
                }
                // Reputable stores only (Target, Walmart, Amazon...), never
                // marketplaces like Mercari. Also enforced by the proxy.
                var trusted = result.products.filter { StoreLinks.isTrusted($0.retailer) }
                // For a bare device name, keep the device itself and drop
                // controllers, cases and games (when any real device came back).
                if let intent { trusted = intent.filter(trusted) }
                if !trusted.isEmpty {
                    products = trusted
                    if query != wish.cleanedQuery { wish.cleanedQuery = query }
                    break
                }
                if !result.products.isEmpty { onlyUntrusted = true }
            } catch PriceServiceError.badResponse(let code) where code == 429 || code == 503 {
                limitStatus = code
                break
            } catch PriceServiceError.badResponse(let code) where code == 401 || code == 403 {
                keyRejected = true
                break
            } catch {
                // Two failed searches in a row with no answer at all: the
                // service is down, so stop instead of burning the ladder.
                failures += 1
                if !gotAnyResponse && failures >= 2 { break }
                continue
            }
        }

        // 5) nothing at all: say why, and give Pip's alternatives
        guard !products.isEmpty else {
            wish.status = .notFound
            if keyRejected {
                wish.statusNote = keyRejectedNote
                Haptics.soft()
                return
            }
            if !gotAnyResponse && limitStatus == 0 {
                // Not a real "no match": no ideas, and it retries on its own.
                wish.statusNote = unreachableNote
                Haptics.soft()
                return
            }
            if limitStatus == 429 {
                wish.statusNote = "That's a lot of searching for one hour. Give \(Workshop.elfName) a little break and try again soon."
            } else if limitStatus == 503 {
                wish.statusNote = "Price search is resting for the rest of today. Try again tomorrow."
            } else if onlyUntrusted {
                wish.statusNote = "Only resellers had this one, and \(Workshop.elfName) sticks to big stores. Try one of these ideas."
            } else {
                wish.statusNote = "No store had an exact match. Try one of \(Workshop.elfName)'s ideas below."
            }
            let ideas = await brain.alternatives(for: wish.rawText)
            wish.suggestionsRaw = ideas.joined(separator: "|")
            Haptics.soft()
            return
        }

        // 6) Pip puts the best match first, then we make it budget aware and
        //    varied: the pick is the best match that FITS the budget, and the
        //    other options spread across prices and stores instead of five
        //    near copies.
        let rankWish: String = intent.map { "\(wish.rawText) (meaning the \($0.label) itself)" } ?? wish.rawText
        let ranked = await brain.rank(products, for: rankWish, details: interpretation)
        let budgetLeft = remainingBudget(for: wish)
        let lineup = Self.lineup(from: ranked.products, budgetLeftCents: budgetLeft)

        let matches = lineup.products.map { p in
            let m = ProductMatch(title: p.title,
                                 priceCents: p.priceCents,
                                 currencyCode: p.currencyCode,
                                 retailer: p.retailer,
                                 buyURLString: p.buyURL,
                                 imageURLString: p.imageURL ?? "")
            m.wish = wish
            return m
        }
        wish.matches = matches
        if lineup.pickIsTopRanked {
            wish.matchReason = ranked.reason
        } else if let budgetLeft, lineup.pickFitsBudget {
            wish.matchReason = "Best match that fits the $\(budgetLeft / 100) left in the budget."
        } else if budgetLeft != nil {
            wish.matchReason = "Everything found is over budget, so this is the closest price."
        } else {
            wish.matchReason = ranked.reason
        }

        if autoPick, let top = matches.first {
            top.isChosen = true
            wish.chosenMatch = top
            wish.status = .matched
        } else {
            wish.status = .idea
        }
        Haptics.success()
    }

    // MARK: Budget + variety

    /// Budget left on this wish's occasion, not counting this wish itself.
    /// nil when the occasion has no budget.
    private static func remainingBudget(for wish: Wish) -> Int? {
        guard let occasion = wish.occasion, occasion.hasBudget else { return nil }
        let others = (occasion.wishes ?? [])
            .filter { $0 !== wish }
            .compactMap { $0.chosenMatch?.priceCents }
            .reduce(0, +)
        return max(0, occasion.budgetCents - others)
    }

    struct Lineup {
        var products: [RemoteProduct]   // pick first, then varied options
        var pickIsTopRanked: Bool
        var pickFitsBudget: Bool
    }

    /// Pick = best ranked product within budget (or the cheapest if nothing
    /// fits). Options = up to 5 more, skipping near duplicate titles and
    /// favoring a spread of stores and price points.
    static func lineup(from ranked: [RemoteProduct], budgetLeftCents: Int?) -> Lineup {
        guard !ranked.isEmpty else { return Lineup(products: [], pickIsTopRanked: true, pickFitsBudget: true) }

        var pickIndex = 0
        var fits = true
        if let budget = budgetLeftCents {
            if let i = ranked.firstIndex(where: { $0.priceCents <= budget }) {
                pickIndex = i
            } else {
                fits = false
                pickIndex = ranked.indices.min { ranked[$0].priceCents < ranked[$1].priceCents } ?? 0
            }
        }
        let pick = ranked[pickIndex]
        var chosen: [RemoteProduct] = [pick]
        var rest = ranked.enumerated().filter { $0.offset != pickIndex }.map { $0.element }

        while chosen.count < 6, !rest.isEmpty {
            // Score each candidate: new store and new price band earn points,
            // near duplicate titles are skipped.
            var bestIdx: Int?
            var bestScore = Int.min
            for (i, candidate) in rest.enumerated() {
                if chosen.contains(where: { similarity($0.title, candidate.title) > 0.7 }) { continue }
                var score = -i                                   // keep relevance order as a base
                if !chosen.contains(where: { $0.retailer.lowercased() == candidate.retailer.lowercased() }) { score += 3 }
                if !chosen.contains(where: { priceBand($0.priceCents) == priceBand(candidate.priceCents) }) { score += 2 }
                if let budget = budgetLeftCents, candidate.priceCents <= budget { score += 2 }
                if score > bestScore { bestScore = score; bestIdx = i }
            }
            guard let idx = bestIdx else { break }
            chosen.append(rest.remove(at: idx))
        }
        return Lineup(products: chosen, pickIsTopRanked: pickIndex == 0, pickFitsBudget: fits)
    }

    private static func priceBand(_ cents: Int) -> Int {
        switch cents {
        case ..<2_500: return 0
        case ..<7_500: return 1
        case ..<15_000: return 2
        default: return 3
        }
    }

    /// Word overlap (Jaccard) between two titles, 0...1.
    private static func similarity(_ a: String, _ b: String) -> Double {
        func words(_ s: String) -> Set<String> {
            Set(s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 2 })
        }
        let wa = words(a), wb = words(b)
        guard !wa.isEmpty, !wb.isEmpty else { return 0 }
        return Double(wa.intersection(wb).count) / Double(wa.union(wb).count)
    }

    /// One retry covers a timeout or a momentary hiccup. If the proxy went
    /// back to sleep, wait for it to wake before the retry.
    private static func searchWithRetry(_ query: String, priceService: PriceService) async throws -> PriceQueryResult {
        do {
            return try await priceService.search(query: query, limit: 10)
        } catch PriceServiceError.badResponse(let code) where code == 429 || code == 503 {
            throw PriceServiceError.badResponse(code)     // a limit, not a hiccup: don't retry
        } catch PriceServiceError.badResponse(let code) where code == 401 || code == 403 {
            throw PriceServiceError.badResponse(code)     // wrong app key: retrying won't help
        } catch {
            _ = await ProxyWarmup.wake(force: true)
            return try await priceService.search(query: query, limit: 10)
        }
    }

    private static func unique(_ queries: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for q in queries {
            let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            guard !trimmed.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(trimmed)
        }
        return out
    }
}

// MARK: - Haptics (tiny wrapper so views don't import UIKit directly)

enum Haptics {
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func soft() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
