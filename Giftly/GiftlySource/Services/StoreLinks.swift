//
//  StoreLinks.swift
//  Giftly
//
//  Google Shopping results only carry Google's own product page, not the
//  store's link, which is why "Open to buy" used to land on a Google search.
//  This picks the best place to send the parent, in order:
//
//    1. the store's own product page, if we've found it before (cached)
//    2. the original link, if it already points at a store
//    3. the proxy's /resolve route, which digs the store link out of Google's
//       product page (cached on the ProductMatch once found)
//    4. a search on that store's own site for the exact product title, so
//       they land at LEGO.com / Target / Amazon with the product on top
//    5. Google's product page as the last resort (it has "Visit site" buttons)
//

import Foundation

@MainActor
enum StoreLinks {

    /// Best URL to open for a product. Fast when cached; otherwise one quick
    /// proxy call (8 second cap), then offline fallbacks.
    static func buyURL(for match: ProductMatch) async -> URL? {
        if let cached = URL(string: match.resolvedURLString), !match.resolvedURLString.isEmpty {
            return cached
        }
        let original = URL(string: match.buyURLString)
        if let original, !isGoogle(original) {
            return original
        }
        if let proxy = GiftlyConfig.priceService as? ProxyPriceService,
           !match.buyURLString.isEmpty,
           let direct = await proxy.resolveStoreURL(googleURL: match.buyURLString, store: match.retailer),
           !isGoogle(direct) {
            match.resolvedURLString = direct.absoluteString
            return direct
        }
        if let storeSearch = storeSearchURL(retailer: match.retailer, title: match.title) {
            return storeSearch
        }
        return original
    }

    // MARK: Trusted stores

    /// Big, reputable retailers only. Marketplaces and random resellers
    /// (Mercari, eBay, Poshmark, unknown shops) are dropped. Matched as whole
    /// words so "rei" doesn't match "Reiss".
    static let trustedStores: [String] = [
        "amazon", "walmart", "target", "best buy", "bestbuy", "lego", "costco",
        "sam's club", "sams club", "kohl's", "kohls", "macy's", "macys",
        "home depot", "the home depot", "lowe's", "lowes", "nordstrom",
        "gamestop", "barnes & noble", "barnes and noble", "nike", "adidas",
        "apple", "wayfair", "newegg", "staples", "michaels", "dick's sporting goods",
        "dicks sporting goods", "ulta", "ulta beauty", "sephora", "chewy",
        "disney", "shopdisney", "disney store", "mattel", "crocs", "rei", "petco",
        "petsmart", "jcpenney", "old navy", "gap", "academy sports", "hobby lobby",
        "pottery barn", "crate & barrel", "williams sonoma", "ikea", "toys r us",
        "toysrus", "dell", "samsung", "microsoft", "nintendo", "playstation",
        "bass pro shops", "cabela's", "foot locker", "under armour", "the north face",
        "lululemon", "kroger", "meijer", "h-e-b", "bj's", "office depot", "belk",
        "dillard's", "bloomingdale's", "saks fifth avenue", "neiman marcus",
        "build-a-bear", "american girl", "fao schwarz", "scholastic"
    ]

    static func isTrusted(_ retailer: String) -> Bool {
        let name = " " + retailer.lowercased()
            .replacingOccurrences(of: ".com", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespaces) + " "
        return trustedStores.contains { store in
            name.contains(" \(store) ")
        }
    }

    static func isGoogle(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("google.")
    }

    /// A search on the store's own site for the product title. nil when we
    /// don't know the store's search URL.
    static func storeSearchURL(retailer: String, title: String) -> URL? {
        let store = retailer.lowercased()
        let query = String(title.prefix(90))
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let pathEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? encoded

        let patterns: [(match: String, url: String)] = [
            ("amazon",      "https://www.amazon.com/s?k=\(encoded)"),
            ("walmart",     "https://www.walmart.com/search?q=\(encoded)"),
            ("target",      "https://www.target.com/s?searchTerm=\(encoded)"),
            ("best buy",    "https://www.bestbuy.com/site/searchpage.jsp?st=\(encoded)"),
            ("bestbuy",     "https://www.bestbuy.com/site/searchpage.jsp?st=\(encoded)"),
            ("lego",        "https://www.lego.com/en-us/search?q=\(encoded)"),
            ("ebay",        "https://www.ebay.com/sch/i.html?_nkw=\(encoded)"),
            ("etsy",        "https://www.etsy.com/search?q=\(encoded)"),
            ("kohl",        "https://www.kohls.com/search.jsp?search=\(encoded)"),
            ("costco",      "https://www.costco.com/CatalogSearch?keyword=\(encoded)"),
            ("gamestop",    "https://www.gamestop.com/search/?q=\(encoded)"),
            ("nike",        "https://www.nike.com/w?q=\(encoded)"),
            ("wayfair",     "https://www.wayfair.com/keyword.php?keyword=\(encoded)"),
            ("newegg",      "https://www.newegg.com/p/pl?d=\(encoded)"),
            ("chewy",       "https://www.chewy.com/s?query=\(encoded)"),
            ("nordstrom",   "https://www.nordstrom.com/sr?keyword=\(encoded)"),
            ("home depot",  "https://www.homedepot.com/s/\(pathEncoded)"),
            ("barnes",      "https://www.barnesandnoble.com/s/\(pathEncoded)"),
            ("apple",       "https://www.apple.com/us/search/\(pathEncoded)"),
            ("sephora",     "https://www.sephora.com/search?keyword=\(encoded)"),
            ("ulta",        "https://www.ulta.com/search?search=\(encoded)"),
            ("michaels",    "https://www.michaels.com/search?q=\(encoded)"),
            ("dick",        "https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=\(encoded)")
        ]
        for pattern in patterns where store.contains(pattern.match) {
            return URL(string: pattern.url)
        }
        return nil
    }

    /// Last resort for a wish with no match: Google Shopping for the words.
    static func webSearchURL(for text: String) -> URL? {
        guard let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.google.com/search?udm=28&q=\(q)")
    }
}
