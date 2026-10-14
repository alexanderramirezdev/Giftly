//
//  ProductIntentTests.swift
//  GiftlyTests
//
//  "PS5" means the console, not a controller or a game. These tests lock in
//  that behavior: bare device names are detected, specific wishes pass
//  through, and the filter keeps the real device out of a pile of accessories.
//

import Testing
import Foundation
@testable import Giftly

struct ProductIntentTests {

    // MARK: - Helpers

    private func product(_ title: String, cents: Int = 49999) -> RemoteProduct {
        RemoteProduct(
            title: title,
            priceCents: cents,
            currencyCode: "USD",
            retailer: "Target",
            buyURL: "https://example.com",
            imageURL: nil
        )
    }

    // MARK: - Detection

    @Test("Bare device names are detected as the device")
    func detectsBareDeviceNames() {
        #expect(ProductIntent.detect("PS5") != nil)
        #expect(ProductIntent.detect("a new PS5!") != nil)       // filler + punctuation stripped
        #expect(ProductIntent.detect("playstation 5") != nil)
        #expect(ProductIntent.detect("Xbox") != nil)
        #expect(ProductIntent.detect("nintendo switch") != nil)
        #expect(ProductIntent.detect("iPad") != nil)
        #expect(ProductIntent.detect("steam deck") != nil)
    }

    @Test("Specific wishes are not treated as a bare device")
    func specificWishesPassThrough() {
        #expect(ProductIntent.detect("PS5 controller") == nil)
        #expect(ProductIntent.detect("Mario Kart for Switch") == nil)
        #expect(ProductIntent.detect("iPad case") == nil)
        #expect(ProductIntent.detect("lego race car") == nil)
    }

    @Test("Empty or whitespace input detects nothing")
    func emptyInputDetectsNothing() {
        #expect(ProductIntent.detect("") == nil)
        #expect(ProductIntent.detect("   ") == nil)
        #expect(ProductIntent.detect("!!!") == nil)
    }

    // MARK: - Normalization

    @Test("Normalize strips filler, punctuation and case")
    func normalizeStripsFiller() {
        #expect(ProductIntent.normalized("a new PS5!") == "ps5")
        #expect(ProductIntent.normalized("I really want an iPad") == "ipad")
        #expect(ProductIntent.normalized("the Xbox") == "xbox")
    }

    // MARK: - matches()

    @Test("A console title matches; an accessory does not")
    func matchesDeviceNotAccessory() throws {
        let ps5 = try #require(ProductIntent.detect("PS5"))
        #expect(ps5.matches("PlayStation 5 Console"))
        #expect(ps5.matches("Sony PlayStation 5 Slim Console Bundle"))
        #expect(!ps5.matches("PlayStation 5 DualSense Wireless Controller"))
        #expect(!ps5.matches("PS5 Charging Station"))
    }

    @Test("Older models are excluded via titleMustNotHave")
    func excludesOlderModels() throws {
        let ps5 = try #require(ProductIntent.detect("PS5"))
        #expect(!ps5.matches("PlayStation 4 Console"))     // ps4 excluded
    }

    @Test("A controller bundle on a console is still the console")
    func consoleBundleWithControllerIsConsole() throws {
        let xbox = try #require(ProductIntent.detect("Xbox"))
        // "console" present overrides the accessory word "controller"
        #expect(xbox.matches("Xbox Series X Console with Extra Controller"))
    }

    // MARK: - filter()

    @Test("Filter keeps only the console when results contain one")
    func filterKeepsConsole() throws {
        let ps5 = try #require(ProductIntent.detect("PS5"))
        let results = [
            product("PlayStation 5 DualSense Controller"),
            product("PlayStation 5 Console"),
            product("PS5 Charging Station"),
            product("PlayStation 5 Slim Console")
        ]
        let kept = ps5.filter(results)
        #expect(kept.count == 2)
        #expect(kept.allSatisfy { $0.title.lowercased().contains("console") })
    }

    @Test("Filter leaves the list untouched when nothing matches the device")
    func filterNoOpWhenNoDevice() throws {
        let ps5 = try #require(ProductIntent.detect("PS5"))
        let results = [
            product("Generic Controller"),
            product("Phone Case")
        ]
        let kept = ps5.filter(results)
        #expect(kept.count == results.count)   // untouched, never silently empty
    }
}
