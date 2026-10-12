//
//  GiftlySeasons.swift
//  Giftly
//
//  The calendar behind Giftly's look, FloraFang style: the season changes on
//  its own by date, the parent can pin one in Settings, and small holiday
//  touches (Valentine's hearts, Easter eggs, pumpkins...) appear in their
//  window. Each season also brings its own accent color and Pip outfit.
//
//    Holiday Workshop  day after Thanksgiving (Black Friday) to Jan 6
//    Snow Day          Jan 7 to the end of February
//    Spring Garden     March to May
//    Summer            June to August
//    Autumn Harvest    September 1 to Thanksgiving
//

import SwiftUI

enum GiftlySeason: String, CaseIterable, Identifiable {
    case holiday, snowDay, spring, summer, autumn

    var id: String { rawValue }

    /// UserDefaults keys (read with @AppStorage so views update live).
    static let settingKey = "giftly_season_setting"          // "auto" or a rawValue
    static let touchesKey = "giftly_holiday_touches"         // "auto" or "off"
    static let previewTouchKey = "giftly_preview_touch"      // "none" or a SeasonalTouch rawValue

    var title: String {
        switch self {
        case .holiday: return "Holiday Workshop"
        case .snowDay: return "Snow Day"
        case .spring:  return "Spring Garden"
        case .summer:  return "Summer"
        case .autumn:  return "Autumn Harvest"
        }
    }

    var symbol: String {
        switch self {
        case .holiday: return "gift"
        case .snowDay: return "snowflake"
        case .spring:  return "camera.macro"
        case .summer:  return "sun.max"
        case .autumn:  return "leaf"
        }
    }

    /// The accent the whole app picks up this season.
    var accent: Color {
        switch self {
        case .holiday: return Color(hex: "CC2E42")
        case .snowDay: return Color(hex: "3A6EA5")
        case .spring:  return Color(hex: "D9567A")
        case .summer:  return Color(hex: "1F8A84")
        case .autumn:  return Color(hex: "C25B1A")
        }
    }

    /// A soft wash for backgrounds.
    var wash: Color { accent.opacity(0.05) }

    // MARK: Which season is it

    /// The season by date alone.
    static func byDate(_ date: Date = .now) -> GiftlySeason {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let year = cal.component(.year, from: date)

        if month == 12 { return .holiday }
        if month == 1 { return day <= 6 ? .holiday : .snowDay }
        if month == 2 { return .snowDay }
        if month >= 3 && month <= 5 { return .spring }
        if month >= 6 && month <= 8 { return .summer }
        if month == 11, let thanksgiving = SeasonalDates.thanksgiving(year: year) {
            let today = cal.startOfDay(for: date)
            return today > thanksgiving ? .holiday : .autumn
        }
        return .autumn
    }

    /// The season to show, honoring the parent's pick in Settings.
    static func resolve(setting: String, date: Date = .now) -> GiftlySeason {
        if let pinned = GiftlySeason(rawValue: setting) { return pinned }
        return byDate(date)
    }

    /// The season on screen: like resolve, but previewing a holiday touch
    /// while on Automatic jumps to that touch's season.
    static func shown(setting: String, preview: String, date: Date = .now) -> GiftlySeason {
        if setting == "auto", let touch = SeasonalTouch(rawValue: preview) { return touch.season }
        return resolve(setting: setting, date: date)
    }

    /// Convenience for non view code.
    static var current: GiftlySeason {
        resolve(setting: UserDefaults.standard.string(forKey: settingKey) ?? "auto")
    }
}

// MARK: - Holiday touches

/// Small extras layered on a season's scene during their window.
enum SeasonalTouch: String, CaseIterable, Identifiable {
    case valentine, easter, mothersDay, fathersDay, halloween, thanksgiving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .valentine:    return "Valentine's Day"
        case .easter:       return "Easter"
        case .mothersDay:   return "Mother's Day"
        case .fathersDay:   return "Father's Day"
        case .halloween:    return "Halloween"
        case .thanksgiving: return "Thanksgiving"
        }
    }

    /// The season each touch belongs to.
    var season: GiftlySeason {
        switch self {
        case .valentine:                return .snowDay
        case .easter, .mothersDay:      return .spring
        case .fathersDay:               return .summer
        case .halloween, .thanksgiving: return .autumn
        }
    }

    /// Touches active on a date (usually zero or one).
    static func active(on date: Date = .now) -> [SeasonalTouch] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        var out: [SeasonalTouch] = []

        if month == 2 && day <= 14 { out.append(.valentine) }
        if let easter = SeasonalDates.easter(year: year),
           SeasonalDates.isWithin(today, start: easter, daysBefore: 10, daysAfter: 1) {
            out.append(.easter)
        }
        if let mom = SeasonalDates.nthWeekday(n: 2, weekday: 1, month: 5, year: year),
           SeasonalDates.isWithin(today, start: mom, daysBefore: 7, daysAfter: 0) {
            out.append(.mothersDay)
        }
        if let dad = SeasonalDates.nthWeekday(n: 3, weekday: 1, month: 6, year: year),
           SeasonalDates.isWithin(today, start: dad, daysBefore: 7, daysAfter: 0) {
            out.append(.fathersDay)
        }
        if month == 10 && day >= 15 { out.append(.halloween) }
        if month == 11, let thanksgiving = SeasonalDates.thanksgiving(year: year), today <= thanksgiving {
            out.append(.thanksgiving)
        }
        return out
    }

    /// Touches to draw for a season, honoring Settings (auto / off / preview).
    static func resolve(for season: GiftlySeason, touches: String, preview: String, date: Date = .now) -> [SeasonalTouch] {
        if let forced = SeasonalTouch(rawValue: preview) { return [forced] }
        guard touches != "off" else { return [] }
        return active(on: date).filter { $0.season == season }
    }
}

// MARK: - Date math

enum SeasonalDates {

    /// Easter Sunday (Gregorian, anonymous algorithm).
    static func easter(year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// e.g. the 2nd Sunday (weekday 1) of May.
    static func nthWeekday(n: Int, weekday: Int, month: Int, year: Int) -> Date? {
        var comps = DateComponents(year: year, month: month)
        comps.weekday = weekday
        comps.weekdayOrdinal = n
        return Calendar.current.date(from: comps)
    }

    /// US Thanksgiving: 4th Thursday (weekday 5) of November.
    static func thanksgiving(year: Int) -> Date? {
        guard let date = nthWeekday(n: 4, weekday: 5, month: 11, year: year) else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

    static func isWithin(_ day: Date, start: Date, daysBefore: Int, daysAfter: Int) -> Bool {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: start)
        guard let from = cal.date(byAdding: .day, value: -daysBefore, to: anchor),
              let to = cal.date(byAdding: .day, value: daysAfter, to: anchor) else { return false }
        return day >= from && day <= to
    }
}
