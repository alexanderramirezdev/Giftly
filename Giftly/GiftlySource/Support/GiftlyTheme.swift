//
//  GiftlyTheme.swift
//  Giftly
//
//  The app's visual identity in one place: palette, spacing, corner radii, and
//  a reusable soft-card surface. Everything else references these so the look
//  stays consistent and is easy to retune. Warm, gift-forward, a little cozy —
//  the opposite of stock-gray SwiftUI.
//

import SwiftUI

enum GiftlyTheme {

    // MARK: Palette
    // Warm cranberry primary, evergreen secondary, cozy cream surfaces.

    static let cranberry   = Color(red: 0.80, green: 0.18, blue: 0.26)
    static let cranberryDeep = Color(red: 0.62, green: 0.12, blue: 0.20)
    static let evergreen   = Color(red: 0.14, green: 0.44, blue: 0.30)
    static let gold        = Color(red: 0.93, green: 0.72, blue: 0.26)

    /// Adaptive surfaces so dark mode works. Cards sit slightly above the
    /// background with a warm tint.
    static let background = Color(light: Color(red: 0.98, green: 0.96, blue: 0.94),
                                  dark:  Color(red: 0.10, green: 0.09, blue: 0.10))
    static let card = Color(light: .white,
                            dark:  Color(red: 0.17, green: 0.16, blue: 0.17))
    static let cardStroke = Color(light: Color.black.opacity(0.05),
                                  dark:  Color.white.opacity(0.08))

    // MARK: Metrics
    static let cardRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let gutter: CGFloat = 16
}

// MARK: - Light/Dark color helper

extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light
        #endif
    }
}

// MARK: - Soft card surface

struct GiftlyCard<Content: View>: View {
    var padding: CGFloat = GiftlyTheme.cardPadding
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: GiftlyTheme.cardRadius, style: .continuous)
                    .fill(GiftlyTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GiftlyTheme.cardRadius, style: .continuous)
                    .stroke(GiftlyTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Section header styled for Giftly

struct GiftlySectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .textCase(nil)
    }
}

// MARK: - Primary button style

struct GiftlyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GiftlyPrimaryButtonBody(configuration: configuration)
    }
}

/// Reads the season so the main button wears the seasonal accent.
private struct GiftlyPrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @AppStorage(GiftlySeason.settingKey) private var seasonSetting = "auto"

    var body: some View {
        let fillColor: Color = GiftlySeason.resolve(setting: seasonSetting).accent
        return configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fillColor)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
