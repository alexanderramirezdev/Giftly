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

    // Richer profile. Every field is optional to fill, and every filled one
    // sharpens the on-device gift ideas. It syncs only through the user's
    // own iCloud.
    var favoriteColors: String = ""
    var favoriteStores: String = ""
    var shirtSize: String = ""
    var shoeSize: String = ""
    var alreadyHas: String = ""            // things they own, so we don't double up
    var dislikes: String = ""
    var jobTitle: String = ""              // grade (child), school or activities (teen), job (adult)
    var favoriteCharacters: String = ""    // characters, shows, games, books, artists
    var devices: String = ""               // game systems and devices they have, so gifts fit
    var contactIdentifier: String = ""     // CNContact.identifier when imported from Contacts
    @Attribute(.externalStorage) var photoData: Data? = nil

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

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// The things Pip can know about someone, and whether each is filled in.
    var profileFacts: [ProfileFact] {
        [
            ProfileFact(label: "Relationship", filled: !relationship.isEmpty),
            ProfileFact(label: "Age", filled: !ageBand.isEmpty),
            ProfileFact(label: "Interests", filled: !interestsRaw.isEmpty),
            ProfileFact(label: "Favorite colors", filled: !favoriteColors.isEmpty),
            ProfileFact(label: profile.storesFact, filled: !favoriteStores.isEmpty),
            ProfileFact(label: "Favorite characters", filled: !favoriteCharacters.isEmpty),
            ProfileFact(label: "Devices", filled: !devices.isEmpty),
            ProfileFact(label: "Sizes", filled: !shirtSize.isEmpty || !shoeSize.isEmpty),
            ProfileFact(label: "Already has", filled: !alreadyHas.isEmpty),
            ProfileFact(label: "Doesn't like", filled: !dislikes.isEmpty)
        ]
    }

    var profileFilledCount: Int { profileFacts.filter { $0.filled }.count }

    /// Plain text profile handed to the on-device model. Only filled fields.
    var profileSummary: String {
        var lines: [String] = []
        if !relationship.isEmpty { lines.append("Relationship to the gift giver: \(relationship)") }
        if !ageBand.isEmpty { lines.append("Age group: \(ageBand)") }
        if !jobTitle.isEmpty { lines.append("\(profile.roleSummaryLabel): \(jobTitle)") }
        if !interestsRaw.isEmpty { lines.append("Interests: \(interestsRaw)") }
        if !favoriteColors.isEmpty { lines.append("Favorite colors: \(favoriteColors)") }
        if !favoriteStores.isEmpty { lines.append("Favorite stores or brands: \(favoriteStores)") }
        if !favoriteCharacters.isEmpty { lines.append("Favorite characters, shows, games or artists: \(favoriteCharacters)") }
        if !devices.isEmpty { lines.append("Has these devices or game systems (gifts should work with them): \(devices)") }
        if !shirtSize.isEmpty { lines.append("\(profile.clothingLabel): \(shirtSize)") }
        if !shoeSize.isEmpty { lines.append("Shoe size: \(shoeSize)") }
        if !alreadyHas.isEmpty { lines.append("Already owns (do not suggest): \(alreadyHas)") }
        if !dislikes.isEmpty { lines.append("Dislikes (avoid): \(dislikes)") }
        return lines.joined(separator: "\n")
    }
}

extension Person {
    var profile: AgeProfile { AgeProfile(band: ageBand) }
}

// MARK: - Past events

extension Occasion {
    /// The most recent time this occasion already happened, if any. One time
    /// events: their date once it's gone by. Yearly ones: last year's date.
    var lastOccurrence: Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let day = cal.startOfDay(for: date)
        if !repeatsAnnually { return day < today ? day : nil }
        let days = daysUntilNext
        guard days > 0, let next = cal.date(byAdding: .day, value: days, to: today) else { return nil }
        let last = cal.date(byAdding: .year, value: -1, to: next)
        // Only count it if the occasion existed back then.
        if let last, last >= cal.startOfDay(for: createdAt) { return last }
        return nil
    }

    /// Shows up under Past events: a one time event that's over, or a yearly
    /// one that happened in the last 90 days and had gift ideas.
    var belongsInPast: Bool {
        guard kind != .justBecause, let last = lastOccurrence else { return false }
        if !repeatsAnnually { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 999
        return days <= 90 && wishCount > 0
    }
}

/// Labels and examples for the profile form, by age group, so a child's
/// profile asks about grade, characters and kids sizes while an adult's asks
/// about work and stores.
struct AgeProfile {
    let band: String

    var isChild: Bool { band == "child" }
    var isTeen: Bool { band == "teen" }
    var isAdult: Bool { band == "adult" }

    var rolePlaceholder: String {
        switch band {
        case "child": return "Grade (e.g. 2nd grade)"
        case "teen":  return "School, team or club (optional)"
        case "adult": return "Works as (optional)"
        default:      return "School or work (optional)"
        }
    }
    var roleSummaryLabel: String {
        switch band {
        case "child": return "Grade"
        case "teen":  return "School, team or club"
        case "adult": return "Works as"
        default:      return "School or work"
        }
    }
    var interestsPlaceholder: String {
        switch band {
        case "child": return "dinosaurs, drawing, soccer, slime…"
        case "teen":  return "gaming, basketball, makeup, music…"
        case "adult": return "cooking, golf, coffee, hiking…"
        default:      return "what they're into…"
        }
    }
    var showsCharacters: Bool { !isAdult }
    var charactersPlaceholder: String {
        isChild ? "Favorite characters or shows (Bluey, Mario…)"
                : "Favorite shows, games or artists"
    }
    var storesPlaceholder: String {
        isChild ? "Favorite toy brands (LEGO, Barbie, Hot Wheels…)" : "Favorite stores or brands"
    }
    var storesFact: String { isChild ? "Favorite brands" : "Favorite stores" }
    var devicesPlaceholder: String {
        switch band {
        case "child": return "Game systems or tablets (Switch, iPad…)"
        case "teen":  return "Consoles and devices (PS5, iPhone, gaming PC…)"
        default:      return "Devices they use (iPhone, Kindle, Xbox…)"
        }
    }
    var clothingLabel: String { isChild ? "Clothing size" : "Shirt size" }
    var clothingPlaceholder: String {
        switch band {
        case "child": return "Clothing size (e.g. 7/8 or kids M)"
        case "teen":  return "Shirt size (S, M, L)"
        default:      return "Shirt size"
        }
    }
    var shoePlaceholder: String {
        isChild ? "Shoe size (e.g. 13 kids or 2Y)" : "Shoe size"
    }
}

struct ProfileFact: Hashable {
    let label: String
    let filled: Bool
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
    var inviteURLString: String = ""        // Apple Invites / Evite / any party link
    var calendarEventID: String = ""        // EKEvent identifier when imported from Calendar

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

    /// The party or event link, only if it's a real web link.
    var inviteURL: URL? {
        let trimmed = inviteURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        return url
    }

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

    // MARK: Gift progress (drives the home-screen nudges)

    var wishCount: Int { (wishes ?? []).count }

    /// Wishes that have a chosen gift or are bought.
    var sortedWishesPicked: Int {
        (wishes ?? []).filter { $0.status == .matched || $0.status == .bought }.count
    }

    var boughtCount: Int {
        (wishes ?? []).filter { $0.status == .bought }.count
    }

    /// True when the occasion is soon and nothing has been picked yet —
    /// the signal the home screen nudges on.
    var needsAttention: Bool {
        let d = daysUntilNext
        return d >= 0 && d <= 21 && sortedWishesPicked == 0
    }

    /// A short, warm status line for the home screen.
    var progressLine: String {
        if wishCount == 0 { return "No wishes yet" }
        if boughtCount == wishCount { return "All set 🎁" }
        if sortedWishesPicked == 0 { return "\(wishCount) wish\(wishCount == 1 ? "" : "es"), nothing picked yet" }
        return "\(sortedWishesPicked) of \(wishCount) picked"
    }
}

enum OccasionKind: String, CaseIterable, Codable {
    // Stored as a raw string, so adding kinds never changes the database.
    case birthday, anniversary, justBecause
    case christmas, hanukkah, valentines, mothersDay, fathersDay, easter, eid, diwali, lunarNewYear, holiday
    case graduation, engagement, wedding, bridalShower, babyShower, baptism, quinceanera, housewarming, newJob, retirement
    case teacherAppreciation, secretSanta, thankYou, getWell
    case other

    var display: String {
        switch self {
        case .birthday:            return "Birthday"
        case .anniversary:         return "Anniversary"
        case .justBecause:         return "Just Because"
        case .christmas:           return "Christmas"
        case .hanukkah:            return "Hanukkah"
        case .valentines:          return "Valentine's Day"
        case .mothersDay:          return "Mother's Day"
        case .fathersDay:          return "Father's Day"
        case .easter:              return "Easter"
        case .eid:                 return "Eid"
        case .diwali:              return "Diwali"
        case .lunarNewYear:        return "Lunar New Year"
        case .holiday:             return "Other Holiday"
        case .graduation:          return "Graduation"
        case .engagement:          return "Engagement"
        case .wedding:             return "Wedding"
        case .bridalShower:        return "Bridal Shower"
        case .babyShower:          return "Baby Shower"
        case .baptism:             return "Baptism or Christening"
        case .quinceanera:         return "Quinceañera"
        case .housewarming:        return "Housewarming"
        case .newJob:              return "New Job"
        case .retirement:          return "Retirement"
        case .teacherAppreciation: return "Teacher Gift"
        case .secretSanta:         return "Secret Santa"
        case .thankYou:            return "Thank You"
        case .getWell:             return "Get Well"
        case .other:               return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .birthday:            return "birthday.cake"
        case .anniversary:         return "heart"
        case .justBecause:         return "star"
        case .christmas:           return "gift"
        case .hanukkah:            return "flame"
        case .valentines:          return "heart.fill"
        case .mothersDay:          return "camera.macro"
        case .fathersDay:          return "mustache"
        case .easter:              return "hare"
        case .eid:                 return "moon.stars"
        case .diwali:              return "sparkle"
        case .lunarNewYear:        return "fireworks"
        case .holiday:             return "sparkles"
        case .graduation:          return "graduationcap"
        case .engagement:          return "suit.diamond"
        case .wedding:             return "heart.circle"
        case .bridalShower:        return "party.popper"
        case .babyShower:          return "figure.and.child.holdinghands"
        case .baptism:             return "drop"
        case .quinceanera:         return "crown"
        case .housewarming:        return "house"
        case .newJob:              return "briefcase"
        case .retirement:          return "beach.umbrella"
        case .teacherAppreciation: return "book.closed"
        case .secretSanta:         return "gift.circle"
        case .thankYou:            return "hand.thumbsup"
        case .getWell:             return "cross.case"
        case .other:               return "calendar"
        }
    }

    /// Groups for the type picker.
    enum KindGroup: String, CaseIterable {
        case everyday = "Everyday", holidays = "Holidays", milestones = "Milestones", thanks = "Thanks and care", more = "More"
    }

    var group: KindGroup {
        switch self {
        case .birthday, .anniversary, .justBecause: return .everyday
        case .christmas, .hanukkah, .valentines, .mothersDay, .fathersDay, .easter, .eid, .diwali, .lunarNewYear, .holiday:
            return .holidays
        case .graduation, .engagement, .wedding, .bridalShower, .babyShower, .baptism, .quinceanera, .housewarming, .newJob, .retirement:
            return .milestones
        case .teacherAppreciation, .secretSanta, .thankYou, .getWell: return .thanks
        case .other: return .more
        }
    }

    static func kinds(in group: KindGroup) -> [OccasionKind] {
        allCases.filter { $0.group == group }
    }

    /// Does this kind recur every year by default?
    var defaultRepeats: Bool {
        switch self {
        case .birthday, .anniversary: return true
        default: return group == .holidays
        }
    }

    /// The next date for holidays with a known date, so picking one fills it in.
    /// Holidays that follow other calendars (Hanukkah, Eid, Diwali, Lunar New
    /// Year) are left for the parent to set.
    var nextKnownDate: Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let year = cal.component(.year, from: today)
        func upcoming(_ make: (Int) -> Date?) -> Date? {
            if let d = make(year), d >= today { return d }
            return make(year + 1)
        }
        func fixed(_ month: Int, _ day: Int) -> (Int) -> Date? {
            { y in cal.date(from: DateComponents(year: y, month: month, day: day)) }
        }
        switch self {
        case .christmas:  return upcoming(fixed(12, 25))
        case .valentines: return upcoming(fixed(2, 14))
        case .mothersDay: return upcoming { SeasonalDates.nthWeekday(n: 2, weekday: 1, month: 5, year: $0) }
        case .fathersDay: return upcoming { SeasonalDates.nthWeekday(n: 3, weekday: 1, month: 6, year: $0) }
        case .easter:     return upcoming { SeasonalDates.easter(year: $0) }
        default:          return nil
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
    var detailsRaw: String = ""            // details read from the wish: "LEGO · red · ages 6 to 8"
    var matchReason: String = ""           // why Pip put the chosen product first
    var giftNote: String = ""              // card message drafted with Pip
    var statusNote: String = ""            // why there's no result (limit hit, offline, no match)
    var suggestionsRaw: String = ""        // Pip's alternative searches, "a|b|c"

    // Wish → Occasion
    var occasion: Occasion?

    // Wish → many candidate ProductMatches (parent picks one)
    @Relationship(deleteRule: .cascade, inverse: \ProductMatch.wish)
    var matches: [ProductMatch]? = []

    /// The parent's committed choice: the match flagged isChosen. Computed
    /// (not a second relationship) because CloudKit requires every
    /// relationship to have an inverse.
    var chosenMatch: ProductMatch? {
        get { (matches ?? []).first { $0.isChosen } }
        set {
            var all = matches ?? []
            if let pick = newValue, !all.contains(where: { $0 === pick }) {
                all.append(pick)
                matches = all
            }
            for m in all { m.isChosen = (newValue != nil && m === newValue) }
        }
    }

    init(rawText: String = "",
         addedBy: Role = .parent,
         occasion: Occasion? = nil) {
        self.rawText = rawText
        self.addedByRaw = addedBy.rawValue
        self.occasion = occasion
        self.createdAt = .now
    }

    /// Pip's alternative searches when nothing matched.
    var suggestions: [String] {
        suggestionsRaw.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
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
    case finding    // background price fetch in flight
    case matched    // a product has been chosen
    case bought     // purchased — hide price pressure, mark done
    case notFound   // searched, nothing came back

    var display: String {
        switch self {
        case .idea:     return "Idea"
        case .finding:  return "Finding the best price"
        case .matched:  return "Found it"
        case .bought:   return "Bought"
        case .notFound: return "No match yet"
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
    var resolvedURLString: String = ""     // the store's own product page, once found
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
