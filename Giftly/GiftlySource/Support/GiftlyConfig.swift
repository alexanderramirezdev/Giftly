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

    /// Shared price service instance used across the app.
    static let priceService: PriceService = ProxyPriceService(baseURL: proxyBaseURL)
}
