//
//  SeasonTests.swift
//  GiftlyTests
//
//  The calendar behind Giftly's look. Dates are the easiest thing to get
//  subtly wrong (Easter, floating holidays, the Thanksgiving/Holiday-Workshop
//  handoff), so these pin the boundaries with known-answer dates.
//

import Testing
import Foundation
@testable import Giftly

struct SeasonTests {

    // MARK: - Helpers

    /// A date at local noon, so startOfDay math never slips across a boundary.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    // MARK: - SeasonalDates: known-answer dates

    @Test("Easter Sundays match the published calendar")
    func easterKnownDates() {
        let cal = Calendar.current
        func easter(_ y: Int) -> (Int, Int)? {
            guard let d = SeasonalDates.easter(year: y) else { return nil }
            return (cal.component(.month, from: d), cal.component(.day, from: d))
        }
        #expect(easter(2024).map { $0 == (3, 31) } == true)   // Mar 31, 2024
        #expect(easter(2025).map { $0 == (4, 20) } == true)   // Apr 20, 2025
        #expect(easter(2026).map { $0 == (4, 5)  } == true)   // Apr 5, 2026
        #expect(easter(2027).map { $0 == (3, 28) } == true)   // Mar 28, 2027
    }

    @Test("Thanksgiving is the 4th Thursday of November")
    func thanksgivingKnownDates() {
        let cal = Calendar.current
        func day(_ y: Int) -> Int? {
            SeasonalDates.thanksgiving(year: y).map { cal.component(.day, from: $0) }
        }
        #expect(day(2025) == 27)   // Nov 27, 2025
        #expect(day(2026) == 26)   // Nov 26, 2026
        #expect(day(2027) == 25)   // Nov 25, 2027
    }

    @Test("Mother's Day = 2nd Sunday of May, Father's Day = 3rd Sunday of June")
    func floatingHolidayWeekdays() {
        let cal = Calendar.current
        let mom = SeasonalDates.nthWeekday(n: 2, weekday: 1, month: 5, year: 2026)
        let dad = SeasonalDates.nthWeekday(n: 3, weekday: 1, month: 6, year: 2026)
        #expect(mom != nil)
        #expect(dad != nil)
        if let mom { #expect(cal.component(.weekday, from: mom) == 1) }   // Sunday
        if let dad { #expect(cal.component(.weekday, from: dad) == 1) }
    }

    @Test("isWithin respects the before/after window")
    func isWithinWindow() {
        // isWithin builds its window from startOfDay(start), so the "day" being
        // checked is also compared at start-of-day in production (see
        // SeasonalTouch.active). Mirror that here: a date at any time on day N
        // is inside the window iff its start-of-day is.
        let cal = Calendar.current
        func startOfDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.startOfDay(for: date(y, m, d))
        }
        let anchor = date(2026, 4, 5)   // some reference day
        #expect(SeasonalDates.isWithin(startOfDay(2026, 4, 5), start: anchor, daysBefore: 10, daysAfter: 1))
        #expect(SeasonalDates.isWithin(startOfDay(2026, 3, 26), start: anchor, daysBefore: 10, daysAfter: 1)) // 10 before
        #expect(SeasonalDates.isWithin(startOfDay(2026, 4, 6),  start: anchor, daysBefore: 10, daysAfter: 1)) // 1 after (inclusive)
        #expect(!SeasonalDates.isWithin(startOfDay(2026, 3, 25), start: anchor, daysBefore: 10, daysAfter: 1)) // 11 before
        #expect(!SeasonalDates.isWithin(startOfDay(2026, 4, 7),  start: anchor, daysBefore: 10, daysAfter: 1)) // 2 after
    }

    // MARK: - GiftlySeason.byDate: boundaries

    @Test("Season by date hits each window")
    func seasonByDateWindows() {
        #expect(GiftlySeason.byDate(date(2026, 12, 25)) == .holiday)   // December
        #expect(GiftlySeason.byDate(date(2026, 1, 6))   == .holiday)   // Jan 1-6 is still holiday
        #expect(GiftlySeason.byDate(date(2026, 1, 7))   == .snowDay)   // Jan 7 flips to snow
        #expect(GiftlySeason.byDate(date(2026, 2, 14))  == .snowDay)   // February
        #expect(GiftlySeason.byDate(date(2026, 4, 1))   == .spring)
        #expect(GiftlySeason.byDate(date(2026, 7, 4))   == .summer)
        #expect(GiftlySeason.byDate(date(2026, 9, 1))   == .autumn)
    }

    @Test("November flips to Holiday Workshop the day after Thanksgiving")
    func novemberThanksgivingHandoff() {
        // Thanksgiving 2026 is Nov 26.
        #expect(GiftlySeason.byDate(date(2026, 11, 20)) == .autumn)    // before
        #expect(GiftlySeason.byDate(date(2026, 11, 26)) == .autumn)    // on the day: not past yet
        #expect(GiftlySeason.byDate(date(2026, 11, 27)) == .holiday)   // Black Friday onward
    }

    // MARK: - resolve / pinned season

    @Test("A pinned season setting overrides the date")
    func pinnedSeasonOverridesDate() {
        // July date, but the parent pinned Holiday Workshop.
        let shown = GiftlySeason.resolve(setting: "holiday", date: date(2026, 7, 4))
        #expect(shown == .holiday)
    }

    @Test("Automatic falls back to the date")
    func autoFallsBackToDate() {
        #expect(GiftlySeason.resolve(setting: "auto", date: date(2026, 7, 4)) == .summer)
        #expect(GiftlySeason.resolve(setting: "nonsense", date: date(2026, 7, 4)) == .summer)
    }

    // MARK: - SeasonalTouch

    @Test("Each touch maps to its season")
    func touchSeasonMapping() {
        #expect(SeasonalTouch.valentine.season == .snowDay)
        #expect(SeasonalTouch.easter.season == .spring)
        #expect(SeasonalTouch.mothersDay.season == .spring)
        #expect(SeasonalTouch.fathersDay.season == .summer)
        #expect(SeasonalTouch.halloween.season == .autumn)
        #expect(SeasonalTouch.thanksgiving.season == .autumn)
    }

    @Test("Valentine touch is active in early February only")
    func valentineActiveWindow() {
        #expect(SeasonalTouch.active(on: date(2026, 2, 10)).contains(.valentine))
        #expect(!SeasonalTouch.active(on: date(2026, 2, 20)).contains(.valentine))   // after the 14th
    }

    @Test("Halloween touch is active mid-to-late October")
    func halloweenActiveWindow() {
        #expect(SeasonalTouch.active(on: date(2026, 10, 20)).contains(.halloween))
        #expect(!SeasonalTouch.active(on: date(2026, 10, 10)).contains(.halloween))  // before the 15th
    }

    @Test("Touches off in Settings yields no touches")
    func touchesOffYieldsNone() {
        let out = SeasonalTouch.resolve(for: .autumn, touches: "off", preview: "none", date: date(2026, 10, 20))
        #expect(out.isEmpty)
    }

    @Test("A preview touch is forced regardless of date")
    func previewTouchForced() {
        let out = SeasonalTouch.resolve(for: .spring, touches: "auto", preview: "easter", date: date(2026, 7, 4))
        #expect(out == [.easter])
    }

    @Test("Resolve only draws touches that belong to the shown season")
    func resolveFiltersBySeason() {
        // Early Feb: valentine is active, but it belongs to snowDay, not spring.
        let spring = SeasonalTouch.resolve(for: .spring, touches: "auto", preview: "none", date: date(2026, 2, 10))
        #expect(spring.isEmpty)
        let snow = SeasonalTouch.resolve(for: .snowDay, touches: "auto", preview: "none", date: date(2026, 2, 10))
        #expect(snow.contains(.valentine))
    }
}
