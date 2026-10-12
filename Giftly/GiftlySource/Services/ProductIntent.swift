//
//  ProductIntent.swift
//  Giftly
//
//  What people mean by a bare device name. "PS5" on a wish list means the
//  console, not a controller kit or a game; "iPad" means an iPad, not a case.
//  When a wish is just the device name, we search for the device itself and
//  keep accessories and games out of the pick. Anything more specific
//  ("PS5 controller", "Mario Kart for Switch") goes through untouched.
//

import Foundation

struct ProductIntent {
    /// What to search for.
    let query: String
    /// A product title must contain one of these to count as the device itself.
    let titleMustHaveAny: [String]
    /// Titles mentioning any of these are another product (an older model...).
    let titleMustNotHave: [String]
    /// For the "why this pick" line.
    let label: String
    /// Game consoles: store listings for the machine say "console", games and
    /// add ons usually don't, so prefer those titles when there are any.
    var prefersConsoleWord: Bool = false

    // MARK: Lookup

    /// The intent for a wish that is only a device name, else nil.
    static func detect(_ rawText: String) -> ProductIntent? {
        let key = normalized(rawText)
        guard !key.isEmpty else { return nil }
        for entry in catalog where entry.aliases.contains(key) {
            return entry.intent
        }
        return nil
    }

    /// Does this product look like the device itself (not an accessory or game)?
    func matches(_ title: String) -> Bool {
        let t = " " + ProductIntent.words(title).joined(separator: " ") + " "
        let hasDevice = titleMustHaveAny.contains { t.contains(" \($0) ") }
        guard hasDevice else { return false }
        if titleMustNotHave.contains(where: { t.contains(" \($0) ") }) { return false }
        let accessory = ProductIntent.accessoryWords.contains { t.contains(" \($0) ") }
        // "Console bundle with controller" is still the console.
        let saysConsole = t.contains(" console ") || t.contains(" system ")
        return !accessory || saysConsole
    }

    /// Keeps only the device itself when any result is; otherwise leaves the list alone.
    func filter(_ products: [RemoteProduct]) -> [RemoteProduct] {
        let kept = products.filter { matches($0.title) }
        guard !kept.isEmpty else { return products }
        guard prefersConsoleWord else { return kept }
        let consoles = kept.filter { ProductIntent.saysConsole($0.title) }
        return consoles.isEmpty ? kept : consoles
    }

    static func saysConsole(_ title: String) -> Bool {
        let w = Set(words(title))
        return w.contains("console") || w.contains("system") || w.contains("handheld")
    }

    // MARK: Text helpers

    private static let filler: Set<String> = [
        "a", "an", "the", "new", "brand", "please", "pls", "one", "1", "for", "him", "her",
        "them", "me", "my", "want", "wants", "i", "he", "she", "would", "like", "really",
        "of", "own", "their", "his", "get"
    ]

    static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// Lowercased words without filler, joined by spaces: "a new PS5!" -> "ps5".
    static func normalized(_ text: String) -> String {
        words(text).filter { !filler.contains($0) }.joined(separator: " ")
    }

    private static let accessoryWords: [String] = [
        "controller", "controllers", "case", "cover", "skin", "skins", "decal", "charger", "charging",
        "station", "stand", "mount", "headset", "headphones", "earbuds", "kit", "cable", "cord",
        "adapter", "dock", "grip", "grips", "protector", "accessory", "accessories", "faceplate",
        "remote", "portal", "stylus", "pencil", "keyboard", "band", "strap", "sleeve", "bag",
        "pouch", "battery", "replacement", "compatible", "edition game", "game", "games",
        "gift card", "subscription", "membership", "card", "mouse", "wheel", "pedal", "camera"
    ]

    // MARK: Catalog

    private struct Entry {
        let aliases: Set<String>
        let intent: ProductIntent
    }

    private static let catalog: [Entry] = [
        Entry(aliases: ["ps5", "ps 5", "playstation 5", "playstation", "play station", "play station 5", "playstation five", "ps5 console", "playstation 5 console"],
              intent: ProductIntent(query: "PlayStation 5 console",
                                    titleMustHaveAny: ["ps5", "playstation 5", "playstation5"],
                                    titleMustNotHave: ["ps4", "playstation 4", "ps3"],
                                    label: "PlayStation 5 console",
                                    prefersConsoleWord: true)),
        Entry(aliases: ["ps5 pro", "playstation 5 pro", "ps pro"],
              intent: ProductIntent(query: "PlayStation 5 Pro console",
                                    titleMustHaveAny: ["pro"],
                                    titleMustNotHave: ["ps4", "controller"],
                                    label: "PlayStation 5 Pro",
                                    prefersConsoleWord: true)),
        Entry(aliases: ["xbox", "x box", "xbox series x", "series x", "xbox series", "xbox console", "new xbox"],
              intent: ProductIntent(query: "Xbox Series X console",
                                    titleMustHaveAny: ["series x", "series s", "xbox series"],
                                    titleMustNotHave: ["xbox one", "xbox 360"],
                                    label: "Xbox console",
                                    prefersConsoleWord: true)),
        Entry(aliases: ["xbox series s", "series s"],
              intent: ProductIntent(query: "Xbox Series S console",
                                    titleMustHaveAny: ["series s"],
                                    titleMustNotHave: ["xbox one", "xbox 360"],
                                    label: "Xbox Series S",
                                    prefersConsoleWord: true)),
        Entry(aliases: ["switch", "nintendo switch", "nintendo", "switch 2", "nintendo switch 2", "switch2", "switch console"],
              intent: ProductIntent(query: "Nintendo Switch 2 console",
                                    titleMustHaveAny: ["switch 2", "switch"],
                                    titleMustNotHave: ["light switch"],
                                    label: "Nintendo Switch console",
                                    prefersConsoleWord: true)),
        Entry(aliases: ["switch oled", "nintendo switch oled", "switch lite", "nintendo switch lite"],
              intent: ProductIntent(query: "Nintendo Switch OLED console",
                                    titleMustHaveAny: ["oled", "lite"],
                                    titleMustNotHave: [],
                                    label: "Nintendo Switch",
                                    prefersConsoleWord: true)),
        Entry(aliases: ["steam deck", "steamdeck"],
              intent: ProductIntent(query: "Valve Steam Deck OLED",
                                    titleMustHaveAny: ["steam deck"],
                                    titleMustNotHave: [],
                                    label: "Steam Deck",
                                    prefersConsoleWord: true)),
        Entry(aliases: ["vr", "vr headset", "meta quest", "quest", "quest 3", "meta quest 3", "oculus", "oculus quest"],
              intent: ProductIntent(query: "Meta Quest 3 VR headset",
                                    titleMustHaveAny: ["quest"],
                                    titleMustNotHave: [],
                                    label: "Meta Quest headset")),
        Entry(aliases: ["ipad", "an ipad", "apple ipad", "ipad tablet"],
              intent: ProductIntent(query: "Apple iPad",
                                    titleMustHaveAny: ["ipad"],
                                    titleMustNotHave: [],
                                    label: "iPad")),
        Entry(aliases: ["iphone", "apple iphone"],
              intent: ProductIntent(query: "Apple iPhone",
                                    titleMustHaveAny: ["iphone"],
                                    titleMustNotHave: [],
                                    label: "iPhone")),
        Entry(aliases: ["apple watch", "iwatch", "smart watch apple"],
              intent: ProductIntent(query: "Apple Watch",
                                    titleMustHaveAny: ["apple watch"],
                                    titleMustNotHave: [],
                                    label: "Apple Watch")),
        Entry(aliases: ["kindle", "amazon kindle", "kindle paperwhite"],
              intent: ProductIntent(query: "Amazon Kindle Paperwhite",
                                    titleMustHaveAny: ["kindle"],
                                    titleMustNotHave: [],
                                    label: "Kindle")),
        Entry(aliases: ["macbook", "mac book", "apple laptop", "macbook air"],
              intent: ProductIntent(query: "Apple MacBook Air",
                                    titleMustHaveAny: ["macbook"],
                                    titleMustNotHave: [],
                                    label: "MacBook"))
    ]
}
