//
//  GiftlyConfig.swift
//  Giftly
//
//  One place for app-wide config so values aren't duplicated across views.
//

import Foundation

enum GiftlyConfig {
    /// The deployed price proxy (Render). Change here if the proxy host moves.
    static let proxyBaseURL = URL(string: "https://giftly-wto4.onrender.com")!

    /// Sent as X-Giftly-Key. Must match GIFTLY_APP_KEY on Render. Keeps casual
    /// callers out; the proxy's per device limits and daily cap bound spend.
    /// Lives in GiftlySecrets.swift, which git ignores.
    static let appKey = GiftlySecrets.appKey

    /// A random ID for this install (not tied to the person), so the proxy can
    /// rate limit per device instead of per network.
    static let deviceID: String = {
        let storeKey = "giftly_device_id"
        if let saved = UserDefaults.standard.string(forKey: storeKey) { return saved }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: storeKey)
        return fresh
    }()

    /// Shared price service instance used across the app.
    static let priceService: PriceService = ProxyPriceService(baseURL: proxyBaseURL)
}
