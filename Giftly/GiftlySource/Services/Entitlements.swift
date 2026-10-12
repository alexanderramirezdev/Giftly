//
//  Entitlements.swift
//  Giftly
//
//  Free vs Plus. Maps directly onto the cost model: price lookups cost YOU
//  money, so the free tier gets a monthly lookup allowance and Plus removes
//  the cap and adds the "smart" extras. Mirrors KehaiCare's "free = the core,
//  premium = the interpreter" split.
//
//  This is a stub around StoreKit 2 — wire `GiftlyPlus.monthly` to your real
//  product ID in App Store Connect, then replace `isPlus` with a Transaction
//  check. Kept deliberately thin so the UI can gate features today.
//

import Foundation
import SwiftUI

@Observable
final class Entitlements {

    static let shared = Entitlements()

    // Flip in previews/testing. In production this comes from StoreKit.
    var isPlus: Bool = false

    // Free-tier allowance: how many price lookups per calendar month.
    let freeMonthlyLookups = 15

    private(set) var lookupsThisMonth: Int = 0
    private var lookupMonthKey: String = Entitlements.currentMonthKey()

    private init() { restore() }

    // MARK: Feature gates

    var canDoPriceLookup: Bool {
        isPlus || remainingFreeLookups > 0
    }

    var remainingFreeLookups: Int {
        rolloverIfNeeded()
        return max(0, freeMonthlyLookups - lookupsThisMonth)
    }

    /// Features reserved for Plus.
    var allowsPriceDropAlerts: Bool { isPlus }
    var allowsUnlimitedPeople: Bool { isPlus }
    let freePeopleLimit = 3

    // MARK: Record usage

    func recordLookup() {
        rolloverIfNeeded()
        lookupsThisMonth += 1
        persist()
    }

    // MARK: Month rollover + persistence (UserDefaults is fine for a counter)

    private func rolloverIfNeeded() {
        let key = Entitlements.currentMonthKey()
        if key != lookupMonthKey {
            lookupMonthKey = key
            lookupsThisMonth = 0
            persist()
        }
    }

    private static func currentMonthKey() -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(lookupsThisMonth, forKey: "giftly.lookups")
        d.set(lookupMonthKey, forKey: "giftly.lookupMonth")
    }

    private func restore() {
        let d = UserDefaults.standard
        lookupsThisMonth = d.integer(forKey: "giftly.lookups")
        if let saved = d.string(forKey: "giftly.lookupMonth") {
            lookupMonthKey = saved
        }
        rolloverIfNeeded()
    }
}
