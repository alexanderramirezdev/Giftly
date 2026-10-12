//
//  PersonViews.swift
//  Giftly
//
//  Person detail (Pip's profile card, gift ideas, occasions), the add/edit
//  form with the richer profile, and the Foundation Models ideas screen.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Person detail

struct PersonDetailView: View {
    @Bindable var person: Person

    @Environment(\.modelContext) private var context
    @State private var showingAddOccasion = false
    @State private var showingIdeas = false
    @State private var showingEdit = false
    @State private var showingQuickAdd = false

    var body: some View {
        List {
            Section {
                PipProfileCard(person: person) { showingEdit = true }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

            Section {
                Button {
                    showingIdeas = true
                } label: {
                    Label("Gift ideas for \(person.firstName)", systemImage: "sparkles")
                }
                .listRowBackground(GiftlyTheme.card)

                Button {
                    showingQuickAdd = true
                } label: {
                    Label("Add a gift idea for \(person.firstName)", systemImage: "plus.circle")
                }
                .listRowBackground(GiftlyTheme.card)
            }

            Section {
                let occasions = (person.occasions ?? []).sorted { $0.daysUntilNext < $1.daysUntilNext }
                if occasions.isEmpty {
                    ContentUnavailableView("No occasions",
                                           systemImage: "calendar",
                                           description: Text("Add a birthday, holiday, or any gift occasion."))
                        .listRowBackground(Color.clear)
                }
                ForEach(occasions, id: \.persistentModelID) { occasion in
                    NavigationLink {
                        OccasionDetailView(occasion: occasion)
                    } label: {
                        UpcomingRow(occasion: occasion, showsChevron: false)
                    }
                    .listRowBackground(GiftlyTheme.card)
                }
                Button {
                    showingAddOccasion = true
                } label: {
                    Label("Add an occasion", systemImage: "calendar.badge.plus")
                }
                .listRowBackground(GiftlyTheme.card)
            } header: {
                GiftlySectionHeader(title: "Occasions", systemImage: "calendar")
            }
        }
        .scrollContentBackground(.hidden)
        .giftlyBackground()
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingAddOccasion = true } label: {
                        Label("Add occasion", systemImage: "calendar.badge.plus")
                    }
                    Button { showingEdit = true } label: {
                        Label("Edit \(person.firstName)", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddOccasion) {
            OccasionEditView(person: person)
        }
        .sheet(isPresented: $showingEdit) {
            PersonEditView(person: person)
        }
        .sheet(isPresented: $showingIdeas) {
            GiftIdeasView(person: person)
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddWishView(preselectedPerson: person)
        }
    }
}

// MARK: - Pip's profile card

/// "I know 3 of 8 things about Mom." The more filled in, the better the ideas.
struct PipProfileCard: View {
    let person: Person
    let onTellMore: () -> Void

    var body: some View {
        let facts = person.profileFacts
        let filled = person.profileFilledCount
        let missing = facts.filter { !$0.filled }.map(\.label)

        GiftlyCard(padding: 14) {
        HStack(alignment: .top, spacing: 12) {
            PersonAvatar(person: person, size: 52)

            VStack(alignment: .leading, spacing: 8) {
                Text(filled == facts.count
                     ? "\(Workshop.elfName) knows \(person.firstName) well. Ideas will be sharp."
                     : "\(Workshop.elfName) knows \(filled) of \(facts.count) things about \(person.firstName).")
                    .font(.workshop(15, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressView(value: Double(filled), total: Double(facts.count))
                    .tint(GiftlyTheme.evergreen)

                if !missing.isEmpty {
                    Text("Next: " + missing.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Tell \(Workshop.elfName) more", action: onTellMore)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.bordered)
                }
            }
            Spacer(minLength: 0)
            ElfView(pose: filled == facts.count ? .cheering : .idle, size: 40)
        }
        }
    }
}

/// Contact photo if there is one, otherwise initials on their color.
struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let data = person.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(hex: person.colorHex)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.36, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(GiftlyTheme.cardStroke, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var initials: String {
        person.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Person add/edit

struct PersonEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var person: Person?
    /// Called with the saved person (used by the add flow to select them).
    var onSaved: ((Person) -> Void)? = nil

    @State private var name = ""
    @State private var relationship = ""
    @State private var ageBand = ""
    @State private var jobTitle = ""
    @State private var interests = ""
    @State private var favoriteColors = ""
    @State private var favoriteStores = ""
    @State private var shirtSize = ""
    @State private var shoeSize = ""
    @State private var alreadyHas = ""
    @State private var dislikes = ""
    @State private var birthdayOn = false
    @State private var birthday = Date.now
    @State private var christmasOn = false
    @FocusState private var nameFocused: Bool

    private let ageBands = ["", "child", "teen", "adult"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                    TextField("Relationship (e.g. Son, Mom)", text: $relationship)
                    Picker("Age", selection: $ageBand) {
                        ForEach(ageBands, id: \.self) { band in
                            Text(band.isEmpty ? "Not set" : band.capitalized).tag(band)
                        }
                    }
                    TextField("Works as (optional)", text: $jobTitle)
                } header: {
                    Text("Who")
                }

                Section {
                    Toggle("Birthday", isOn: $birthdayOn.animation())
                    if birthdayOn {
                        DatePicker("Date", selection: $birthday, displayedComponents: .date)
                    }
                    Toggle("On the Christmas list", isOn: $christmasOn)
                } header: {
                    Text("Dates")
                } footer: {
                    Text("\(Workshop.elfName) sets these occasions up for you. A birth year only sets the age group; the year isn't saved.")
                }

                Section {
                    TextField("dinosaurs, drawing, soccer…", text: $interests, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Favorite colors", text: $favoriteColors)
                    TextField("Favorite stores or brands", text: $favoriteStores)
                } header: {
                    Text("What they love")
                }

                Section {
                    TextField("Shirt size", text: $shirtSize)
                    TextField("Shoe size", text: $shoeSize)
                } header: {
                    Text("Sizes")
                }

                Section {
                    TextField("Already has (so we don't double up)", text: $alreadyHas, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Doesn't like", text: $dislikes, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Skip these")
                } footer: {
                    Text("\(Workshop.elfName) uses this on your iPhone to suggest gifts. It syncs only to your own iCloud.")
                }
            }
            .scrollContentBackground(.hidden)
            .giftlyBackground()
            .navigationTitle(person == nil ? "Add someone" : "Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let p = person else {
            // New people start on the Christmas list; one tap to turn it off.
            christmasOn = true
            nameFocused = true
            return
        }
        name = p.name
        relationship = p.relationship
        ageBand = ageBands.contains(p.ageBand) ? p.ageBand : ""
        jobTitle = p.jobTitle
        interests = p.interestsRaw
        favoriteColors = p.favoriteColors
        favoriteStores = p.favoriteStores
        shirtSize = p.shirtSize
        shoeSize = p.shoeSize
        alreadyHas = p.alreadyHas
        dislikes = p.dislikes
        if let b = (p.occasions ?? []).first(where: { $0.kind == .birthday }) {
            birthdayOn = true
            birthday = b.date
        }
        christmasOn = (p.occasions ?? []).contains { $0.kind == .christmas }
    }

    private func save() {
        let target: Person
        if let p = person {
            target = p
        } else {
            let colors = ["#4C8BF5", "#E4572E", "#2F7D4F", "#B565C9", "#E3B04B", "#17BEBB"]
            target = Person(colorHex: colors.randomElement() ?? "#4C8BF5")
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.relationship = relationship
        target.ageBand = ageBand
        target.jobTitle = jobTitle
        target.interestsRaw = interests
        target.favoriteColors = favoriteColors
        target.favoriteStores = favoriteStores
        target.shirtSize = shirtSize
        target.shoeSize = shoeSize
        target.alreadyHas = alreadyHas
        target.dislikes = dislikes
        syncOccasions(for: target)
        Haptics.success()
        onSaved?(target)
        dismiss()
    }

    /// Birthday and Christmas toggles create (or tidy up) the occasions, so
    /// nobody has to visit a second screen for the two most common ones.
    /// Turning one off only removes it if it has no wishes yet.
    private func syncOccasions(for p: Person) {
        let cal = Calendar.current
        let existing = p.occasions ?? []

        let birthdayOccasion = existing.first { $0.kind == .birthday }
        if birthdayOn {
            let comps = cal.dateComponents([.year, .month, .day], from: birthday)
            let next = ContactImporter.nextDate(month: comps.month, day: comps.day) ?? birthday
            if let year = comps.year, year < cal.component(.year, from: .now), p.ageBand.isEmpty {
                p.ageBand = ContactImporter.ageBand(birthYear: year)
            }
            if let b = birthdayOccasion {
                b.date = next
            } else {
                context.insert(Occasion(title: "\(p.firstName)'s Birthday", kind: .birthday,
                                        date: next, repeatsAnnually: true, person: p))
            }
        } else if let b = birthdayOccasion, b.wishCount == 0 {
            context.delete(b)
        }

        let christmas = existing.first { $0.kind == .christmas }
        if christmasOn, christmas == nil {
            let date = ContactImporter.nextDate(month: 12, day: 25) ?? .now
            context.insert(Occasion(title: "\(p.firstName)'s Christmas", kind: .christmas,
                                    date: date, repeatsAnnually: true, person: p))
        } else if !christmasOn, let x = christmas, x.wishCount == 0 {
            context.delete(x)
        }
    }
}

// MARK: - Gift ideas (Foundation Models)

struct GiftIdeasView: View {
    let person: Person
    @Environment(GiftIntelligence.self) private var brain
    @Environment(\.dismiss) private var dismiss

    @State private var ideas: [GiftSuggestion] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    VStack(spacing: 12) {
                        ElfView(pose: .reading, size: 80)
                        Text("\(Workshop.elfName) is thinking of gifts \(person.firstName) would love…")
                            .font(.workshop(15, weight: .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if ideas.isEmpty {
                    ContentUnavailableView("No ideas yet",
                                           systemImage: "sparkles",
                                           description: Text("Tell \(Workshop.elfName) a little about \(person.firstName) first: interests, favorite colors, or stores."))
                } else {
                    List(ideas) { suggestion in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(suggestion.idea, systemImage: "gift")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            if !suggestion.why.isEmpty {
                                Text(suggestion.why)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 30)
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(GiftlyTheme.card)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .giftlyBackground()
            .navigationTitle("Gift Ideas")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                let next = (person.occasions ?? [])
                    .filter { $0.daysUntilNext >= 0 }
                    .min { $0.daysUntilNext < $1.daysUntilNext }
                var budgetLeft: Int? = nil
                if let next, next.hasBudget {
                    budgetLeft = max(0, next.budgetCents - next.committedTotalCents)
                }
                ideas = await brain.ideas(for: person, occasionTitle: next?.title, budgetLeftCents: budgetLeft)
                loading = false
            }
        }
        .presentationDetents([.medium, .large])
    }
}
