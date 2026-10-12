//
//  WishFetcher.swift
//  Giftly
//
//  Background price fetch — the thing that makes the app feel alive.
//  Instead of making the parent wait on a spinner, we:
//    1. add the wish instantly (status .finding)
//    2. kick off this fetcher
//    3. it cleans the text (FM), searches prices, and fills in the result
//    4. the SwiftData update flows to the UI automatically
//
//  Runs on the main actor because it mutates SwiftData models bound to the
//  view context. The network/FM awaits don't block the UI — they suspend.
//

import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum WishFetcher {

    /// Fetch a price for a freshly-added wish and update it in place.
    /// `autoPick` = true commits the top result automatically (parent can swap
    /// later); false just attaches candidates for the parent to choose.
    static func fetchPrice(
        for wish: Wish,
        using brain: GiftIntelligence,
        priceService: PriceService,
        entitlements: Entitlements,
        autoPick: Bool = true
    ) async {
        wish.status = .finding

        // 1) clean the wish text on-device
        let interpretation = await brain.clean(wish.rawText)
        wish.cleanedQuery = interpretation.query.isEmpty ? wish.rawText : interpretation.query

        // 2) allowance check
        guard entitlements.canDoPriceLookup else {
            wish.status = .idea   // leave as idea; parent can retry / upgrade
            return
        }

        // 3) price search
        do {
            let result = try await priceService.search(query: wish.cleanedQuery, limit: 5)
            entitlements.recordLookup()

            guard !result.products.isEmpty else {
                wish.status = .notFound
                Haptics.soft()
                return
            }

            // attach all candidates
            let matches = result.products.map { p in
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

            if autoPick, let top = matches.first {
                top.isChosen = true
                wish.chosenMatch = top
                wish.status = .matched
            } else {
                wish.status = .idea
            }
            Haptics.success()
        } catch {
            wish.status = .notFound
            Haptics.soft()
        }
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
