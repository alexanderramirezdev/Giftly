//
//  Models.swift
//  Giftly
//
//  SwiftData models. Designed for CloudKit sync, which imposes rules:
//   • every stored property must have a default value (or be optional)
//   • no @Attribute(.unique) constraints (CloudKit can't enforce them)
//   • relationships must be optional and have inverses
//  Keep those rules in mind when editing — they're easy to break and the
//  failure mode is a silent "container failed to initialize" at launch.
//

import Foundation
import SwiftData

// MARK: - Person
//
// Someone you give gifts to: a kid, a spouse, Grandma. A Person owns many
// Occasions (their birthday every year, Christmas, etc.).

@Model
final class Person {
    var name: String = ""
    var relationship: String = ""          // "Son", "Wife", "Mom" — free text, FM can use it for ideas
    var ageBand: String = ""               // "child" / "teen" / "adult" — used to tailor gift ideas, NOT a birthdate
    var interestsRaw: String = ""          // comma-ish free text: "dinosaurs, drawing, soccer" — feeds FM idea generation
    var colorHex: String = "#4C8BF5"       // avatar accent color
    var createdAt: Date = Date.now

    // One Person → many Occasions
    @Relationship(deleteRule: .cascade, inverse: \Occasion.person)
    var occasions: [Occasion]? = []

    init(name: String = "",
         relationship: String = "",
         ageBand: String = "",
         interestsRaw: String = "",
         colorHex: String = "#4C8BF5") {
        self.name = name
        self.relationship = relationship
        self.ageBand = ageBand
        self.interestsRaw = interestsRaw
        self.colorHex = colorHex
        self.createdAt = .now
    }

    var interests: [String] {
        interestsRaw
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Occasion
//
// A gift event with a date and (optionally) a budget. Owns the wishlist.

@Model
final class Occasion {
    var title: String = ""                 // "Leo's 7th Birthday"
    var kindRaw: String = OccasionKind.birthday.rawValue
    var date: Date = Date.now
    var repeatsAnnually: Bool = false       // birthdays/anniversaries recur; "just because" doesn't
    var budgetCents: Int = 0                // 0 = no budget set
    var createdAt: Date = Date.now

    // Occasion → Person (the recipient)
    var person: Person?

    // Occasion → many Wishes
    @Relationship(deleteRule: .cascade, inverse: \Wish.occasion)
    var wishes: [Wish]? = []

    init(title: String = "",
         kind: OccasionKind = .birthday,
         date: Date = .now,
         repeatsAnnually: Bool = false,
         budgetCents: Int = 0,
         person: Person? = nil) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.date = date
        self.repeatsAnnually = repeatsAnnually
        self.budgetCents = budgetCents
        self.person = person
        self.createdAt = .now
    }

    var kind: OccasionKind {
        get { OccasionKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var hasBudget: Bool { budgetCents > 0 }

    /// Days until the next occurrence of this occasion (handles annual repeats).
    var daysUntilNext: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var target = cal.startOfDay(for: date)
        if repeatsAnnually {
            // roll the month/day forward to this year (or next if already past)
            let comps = cal.dateComponents([.month, .day], from: date)
            if let thisYear = cal.nextDate(after: today.addingTimeInterval(-1),
                                           matching: comps,
                                           matchingPolicy: .nextTimePreservingSmallerComponents) {
                target = cal.startOfDay(for: thisYear)
            }
        }
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    /// Running total of chosen product prices on this occasion, in cents.
    var committedTotalCents: Int {
        (wishes ?? []).compactMap { $0.chosenMatch?.priceCents }.reduce(0, +)
    }
}

enum OccasionKind: String, CaseIterable, Codable {
    case birthday, christmas, anniversary, holiday, graduation, wedding, babyShower, justBecause, other

    var display: String {
        switch self {
        case .birthday:    return "Birthday"
        case .christmas:   return "Christmas"
        case .anniversary: return "Anniversary"
        case .holiday:     return "Holiday"
        case .graduation:  return "Graduation"
        case .wedding:     return "Wedding"
        case .babyShower:  return "Baby Shower"
        case .justBecause: return "Just Because"
        case .other:       return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .birthday:    return "birthday.cake"
        case .christmas:   return "gift"
        case .anniversary: return "heart"
        case .holiday:     return "sparkles"
        case .graduation:  return "graduationcap"
        case .wedding:     return "heart.circle"
        case .babyShower:  return "figure.and.child.holdinghands"
        case .justBecause: return "star"
        case .other:       return "calendar"
        }
    }

    /// Does this kind recur every year by default?
    var defaultRepeats: Bool {
        switch self {
        case .birthday, .anniversary, .christmas, .holiday: return true
        default: return false
        }
    }
}

// MARK: - Wish
//
// One item someone wants, in the words it was added in. The FM cleans
// `rawText` into a searchable query; the price layer turns that into
// ProductMatches; the parent picks one, which becomes `chosenMatch`.

@Model
final class Wish {
    var rawText: String = ""               // "the lego race car with lights" — as typed
    var cleanedQuery: String = ""          // FM output: "LEGO Technic light-up race car"
    var statusRaw: String = WishStatus.idea.rawValue
    var addedByRaw: String = Role.parent.rawValue
    var note: String = ""                  // free note the parent can add
    var createdAt: Date = Date.now

    // Wish → Occasion
    var occasion: Occasion?

    // Wish → many candidate ProductMatches (parent picks one)
    @Relationship(deleteRule: .cascade, inverse: \ProductMatch.wish)
    var matches: [ProductMatch]? = []

    // the parent's committed choice (also present in `matches`)
    var chosenMatch: ProductMatch?

    init(rawText: String = "",
         addedBy: Role = .parent,
         occasion: Occasion? = nil) {
        self.rawText = rawText
        self.addedByRaw = addedBy.rawValue
        self.occasion = occasion
        self.createdAt = .now
    }

    var status: WishStatus {
        get { WishStatus(rawValue: statusRaw) ?? .idea }
        set { statusRaw = newValue.rawValue }
    }

    var addedBy: Role {
        get { Role(rawValue: addedByRaw) ?? .parent }
        set { addedByRaw = newValue.rawValue }
    }
}

enum WishStatus: String, CaseIterable, Codable {
    case idea       // just added, not yet searched
    case matched    // a product has been chosen
    case bought     // purchased — hide price pressure, mark done

    var display: String {
        switch self {
        case .idea:    return "Idea"
        case .matched: return "Found it"
        case .bought:  return "Bought"
        }
    }
}

// MARK: - ProductMatch
//
// A concrete, buyable product returned by the price layer. Cached: `fetchedAt`
// drives the "updated 2 days ago" label and the refresh/staleness logic. We
// store price as Int cents to avoid floating-point money bugs.

@Model
final class ProductMatch {
    var title: String = ""
    var priceCents: Int = 0
    var currencyCode: String = "USD"
    var retailer: String = ""              // "Amazon", "Walmart", "eBay"…
    var buyURLString: String = ""
    var imageURLString: String = ""
    var fetchedAt: Date = Date.now         // for cache staleness
    var isChosen: Bool = false

    // ProductMatch → Wish
    var wish: Wish?

    init(title: String = "",
         priceCents: Int = 0,
         currencyCode: String = "USD",
         retailer: String = "",
         buyURLString: String = "",
         imageURLString: String = "") {
        self.title = title
        self.priceCents = priceCents
        self.currencyCode = currencyCode
        self.retailer = retailer
        self.buyURLString = buyURLString
        self.imageURLString = imageURLString
        self.fetchedAt = .now
    }

    var buyURL: URL? { URL(string: buyURLString) }
    var imageURL: URL? { URL(string: imageURLString) }

    var formattedPrice: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSNumber(value: Double(priceCents) / 100.0)) ?? "—"
    }

    /// Prices older than this are considered stale and eligible for refresh.
    var isStale: Bool {
        Date.now.timeIntervalSince(fetchedAt) > 60 * 60 * 24 * 2   // 2 days
    }
}
