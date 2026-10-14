//
//  SettingsView.swift
//  Giftly
//
//  Season picker, FloraFang style: Automatic follows the calendar, or pin any
//  season by hand. Holiday touches (hearts, eggs, jack-o-lanterns...) can be
//  turned off, and any of them can be previewed right now.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @AppStorage(GiftlySeason.settingKey) private var seasonSetting = "auto"
    @AppStorage(GiftlySeason.touchesKey) private var touchesSetting = "auto"
    @AppStorage(GiftlySeason.previewTouchKey) private var previewTouch = "none"
    @State private var showingIntro = false
    @State private var confirmingErase = false
    @AppStorage(AppLock.settingKey) private var lockEnabled = false

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
                    Text("From Black Friday through January 6, Pip wears a Santa hat and the elf crew helps out in the workshop. The rest of the year, Pip gets new wrapping for each season.")
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
                    Text("Holiday Touches")
                } footer: {
                    Text("Little extras during their window: Valentine hearts, Easter eggs, Mother's Day tulips, Father's Day bunting, jack-o-lanterns and Thanksgiving leaves. A preview stays on until you set it back to None.")
                }

                Section {
                    Button {
                        showingIntro = true
                    } label: {
                        Label("How Pip Works", systemImage: "questionmark.circle")
                    }
                }

                Section {
                    Toggle(isOn: lockBinding) {
                        Label("Lock with \(AppLock.biometryName)", systemImage: "lock.fill")
                    }
                    .disabled(!AppLock.isAvailable)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(AppLock.isAvailable
                         ? "Keeps the surprises safe: Pip asks for \(AppLock.biometryName) every time you open it, and hides your lists in the app switcher."
                         : "Set a passcode on this iPhone to lock Pip.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmingErase = true
                    } label: {
                        Label("Erase all my data", systemImage: "trash")
                    }
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("Deletes every person, occasion and gift idea from this iPhone and from your iCloud, on all your devices. This can't be undone.")
                }
            }
            .confirmationDialog("Erase all your data?", isPresented: $confirmingErase, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive, action: eraseAll)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everyone you've added, their occasions and gift ideas will be deleted here and from iCloud.")
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
                ElfView(pose: .waving, size: 36, season: shownSeason)
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

    /// Turning the lock on asks for Face ID first, so nobody locks themselves out.
    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lockEnabled },
            set: { wantOn in
                guard wantOn else {
                    lockEnabled = false
                    return
                }
                Task {
                    if await AppLock.authenticate(reason: "Turn on the lock for Pip") {
                        lockEnabled = true
                        Haptics.success()
                    }
                }
            }
        )
    }

    /// Deletes record by record (not a batch delete) so every deletion is
    /// mirrored to iCloud and the data is gone on all devices.
    private func eraseAll() {
        do {
            for match in try context.fetch(FetchDescriptor<ProductMatch>()) { context.delete(match) }
            for wish in try context.fetch(FetchDescriptor<Wish>()) { context.delete(wish) }
            for occasion in try context.fetch(FetchDescriptor<Occasion>()) { context.delete(occasion) }
            for person in try context.fetch(FetchDescriptor<Person>()) { context.delete(person) }
            try context.save()
            Haptics.success()
        } catch {
            print("Erase failed: \(error)")
        }
        dismiss()
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
