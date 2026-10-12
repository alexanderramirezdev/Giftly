//
//  SettingsView.swift
//  Giftly
//
//  Season picker, FloraFang style: Automatic follows the calendar, or pin any
//  season by hand. Holiday touches (hearts, eggs, jack-o-lanterns...) can be
//  turned off, and any of them can be previewed right now.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(GiftlySeason.settingKey) private var seasonSetting = "auto"
    @AppStorage(GiftlySeason.touchesKey) private var touchesSetting = "auto"
    @AppStorage(GiftlySeason.previewTouchKey) private var previewTouch = "none"
    @State private var showingIntro = false

    private var shownSeason: GiftlySeason {
        return GiftlySeason.shown(setting: seasonSetting, preview: previewTouch)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    previewCard
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    seasonRow(title: "Automatic",
                              detail: "Follows the calendar. Today: \(GiftlySeason.byDate().title)",
                              symbol: "calendar",
                              color: GiftlySeason.byDate().accent,
                              tag: "auto")
                    ForEach(GiftlySeason.allCases) { season in
                        seasonRow(title: season.title,
                                  detail: seasonDates(season),
                                  symbol: season.symbol,
                                  color: season.accent,
                                  tag: season.rawValue)
                    }
                } header: {
                    Text("Season")
                } footer: {
                    Text("Pip and the elf crew run the workshop from Black Friday through January 6. The rest of the year Pip is off duty in a seasonal outfit.")
                }

                Section {
                    Toggle("Holiday touches", isOn: touchesBinding)
                    Picker("Preview a touch", selection: $previewTouch) {
                        Text("None").tag("none")
                        ForEach(SeasonalTouch.allCases) { touch in
                            Text(touch.title).tag(touch.rawValue)
                        }
                    }
                } header: {
                    Text("Holiday touches")
                } footer: {
                    Text("Little extras during their window: Valentine hearts, Easter eggs, Mother's Day tulips, Father's Day bunting, jack-o-lanterns and Thanksgiving leaves. A preview stays on until you set it back to None.")
                }

                Section {
                    Button {
                        showingIntro = true
                    } label: {
                        Label("How Giftly works", systemImage: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingIntro) {
                IntroView(isReplay: true) { showingIntro = false }
            }
            .scrollContentBackground(.hidden)
            .giftlyBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Pieces

    private var previewCard: some View {
        ZStack(alignment: .topLeading) {
            GiftlyTheme.background
            GiftlyAtmosphereView(season: shownSeason, giftFullness: 0.7)
            HStack(spacing: 8) {
                ElfView(pose: .waving, size: 36, style: ElfStyle.pip(for: shownSeason))
                Text(shownSeason.title)
                    .font(.headline)
                    .foregroundStyle(shownSeason.accent)
            }
            .padding(12)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.4), value: shownSeason)
    }

    private func seasonRow(title: String, detail: String, symbol: String, color: Color, tag: String) -> some View {
        let selected: Bool = seasonSetting == tag
        let traits: AccessibilityTraits = selected ? .isSelected : []
        return Button {
            Haptics.tap()
            seasonSetting = tag
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
        }
        .accessibilityAddTraits(traits)
    }

    private var touchesBinding: Binding<Bool> {
        Binding(
            get: { touchesSetting != "off" },
            set: { touchesSetting = $0 ? "auto" : "off" }
        )
    }

    private func seasonDates(_ season: GiftlySeason) -> String {
        switch season {
        case .holiday: return "Black Friday to Jan 6"
        case .snowDay: return "Jan 7 through February"
        case .spring:  return "March to May"
        case .summer:  return "June to August"
        case .autumn:  return "September to Thanksgiving"
        }
    }
}
