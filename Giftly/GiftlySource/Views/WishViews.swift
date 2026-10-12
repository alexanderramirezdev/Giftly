//
//  WishViews.swift
//  Giftly
//
//  The two screens where the whole concept comes together:
//
//  AddWishView  — type a wish → FM cleans it on-device → price search returns
//                 real products → parent picks one. This is where a lookup is
//                 spent, so it respects the free-tier allowance.
//
//  WishDetailView — shows the chosen product + alternatives, buy link, and
//                 the "mark bought" toggle.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Add a gift idea (single occasion)

struct AddWishView: View {
    let occasion: Occasion

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(GiftIntelligence.self) private var brain
    @Environment(Entitlements.self) private var entitlements
    @Environment(AppSession.self) private var session

    @State private var rawText = ""

    private let priceService = GiftlyConfig.priceService

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. the lego race car with lights", text: $rawText, axis: .vertical)
                        .lineLimit(1...3)
                        .submitLabel(.done)
                } header: {
                    Text("What do they want?")
                } footer: {
                    Text("Add it in plain words. Giftly finds the best price in the background while you keep going.")
                }

                if !entitlements.isPlus {
                    Section {
                        Label("\(entitlements.remainingFreeLookups) price lookups left this month",
                              systemImage: "sparkles")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add a gift idea")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addAndFetch() }
                        .disabled(rawText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// Add the wish INSTANTLY, then fetch its price in the background. The user
    /// doesn't wait — the wish appears in the list with a "finding price" state
    /// and quietly fills in. This is the core "alive" behavior.
    private func addAndFetch() {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let wish = Wish(rawText: text, addedBy: .parent, occasion: occasion)
        wish.status = session.networkAllowed ? .finding : .idea
        context.insert(wish)
        Haptics.tap()
        dismiss()   // back to the list immediately

        guard session.networkAllowed else { return }
        Task {
            await WishFetcher.fetchPrice(
                for: wish,
                using: brain,
                priceService: priceService,
                entitlements: entitlements,
                autoPick: true
            )
        }
    }
}

// MARK: - Quick add (one screen: who, which occasion, what)

/// Add a gift idea from anywhere: pick (or create) the person, pick the
/// occasion, type. One screen, and it stays open so a whole list can go in.
/// This replaces the old separate "Add someone" step.
struct QuickAddWishView: View {
    var preselectedPerson: Person? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(GiftIntelligence.self) private var brain
    @Environment(Entitlements.self) private var entitlements
    @Environment(AppSession.self) private var session
    @Query(sort: \Person.name) private var people: [Person]

    @State private var person: Person?
    @State private var occasion: Occasion?
    @State private var showingNewPerson = false
    @State private var rawText = ""
    @State private var lastAdded: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    personChips
                } header: {
                    Text("For")
                }

                if person != nil {
                    Section {
                        occasionChips
                    } header: {
                        Text("Occasion")
                    }
                }

                Section {
                    TextField("e.g. the lego race car with lights", text: $rawText, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    if let lastAdded {
                        Label(addedLine(lastAdded), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(GiftlyTheme.evergreen)
                    }
                } header: {
                    Text("What do they want?")
                } footer: {
                    Text("Add as many as you like. Prices fill in while you keep going.")
                }
            }
            .scrollContentBackground(.hidden)
            .giftlyBackground()
            .navigationTitle("Add a gift idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .fontWeight(.semibold)
                        .disabled(!canAdd)
                }
            }
            .onAppear(perform: setUp)
            .sheet(isPresented: $showingNewPerson) {
                PersonEditView(person: nil) { newPerson in
                    select(person: newPerson)
                    fieldFocused = true
                }
            }
        }
    }

    // MARK: Pickers

    private var personChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(people, id: \.persistentModelID) { p in
                    ChoiceChip(selected: isSelected(p)) {
                        select(person: p)
                    } content: {
                        HStack(spacing: 6) {
                            PersonAvatar(person: p, size: 24)
                            Text(p.firstName)
                        }
                    }
                }
                ChoiceChip(selected: false) {
                    Haptics.tap()
                    fieldFocused = false
                    showingNewPerson = true
                } content: {
                    Label("New", systemImage: "plus")
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var occasionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let person {
                    ForEach(occasions(for: person), id: \.persistentModelID) { o in
                        ChoiceChip(selected: occasion?.persistentModelID == o.persistentModelID) {
                            occasion = o
                        } content: {
                            Label(o.kind.display, systemImage: o.kind.symbol)
                        }
                    }
                    ChoiceChip(selected: occasion == nil) { occasion = nil } content: {
                        Label("Just a wishlist", systemImage: "star")
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Logic

    private var canAdd: Bool {
        let hasText = !rawText.trimmingCharacters(in: .whitespaces).isEmpty
        return hasText && person != nil
    }

    private func isSelected(_ p: Person) -> Bool {
        guard let person else { return false }
        return person.persistentModelID == p.persistentModelID
    }

    private func addedLine(_ text: String) -> String {
        "\(Workshop.elfName) is finding \"\(text)\""
    }

    private func setUp() {
        if let preselectedPerson {
            select(person: preselectedPerson)
        } else if person == nil, let first = people.first {
            select(person: first)
        }
        if people.isEmpty {
            // Nobody yet: start by adding someone.
            showingNewPerson = true
        } else {
            fieldFocused = true
        }
    }

    private func occasions(for person: Person) -> [Occasion] {
        let all: [Occasion] = person.occasions ?? []
        let dated: [Occasion] = all.filter { (o: Occasion) -> Bool in o.kind != .justBecause }
        return dated.sorted { (a: Occasion, b: Occasion) -> Bool in
            let da: Int = a.daysUntilNext < 0 ? Int.max : a.daysUntilNext
            let db: Int = b.daysUntilNext < 0 ? Int.max : b.daysUntilNext
            return da < db
        }
    }

    private func select(person p: Person) {
        person = p
        occasion = occasions(for: p).first { $0.daysUntilNext >= 0 }
    }

    /// The chosen occasion, or the person's catch all wishlist.
    private func targetOccasion(for p: Person) -> Occasion {
        if let occasion { return occasion }
        if let existing = (p.occasions ?? []).first(where: { $0.kind == .justBecause }) { return existing }
        let o = Occasion(title: "\(p.firstName)'s Wishlist", kind: .justBecause,
                         date: .now, repeatsAnnually: false, person: p)
        context.insert(o)
        return o
    }

    private func add() {
        guard canAdd, let owner = person else { return }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        let wish = Wish(rawText: text, addedBy: .parent, occasion: targetOccasion(for: owner))
        wish.status = session.networkAllowed ? .finding : .idea
        context.insert(wish)
        Haptics.tap()
        withAnimation { lastAdded = text }
        rawText = ""
        fieldFocused = true

        guard session.networkAllowed else { return }
        Task {
            await WishFetcher.fetchPrice(for: wish, using: brain,
                                         priceService: GiftlyConfig.priceService,
                                         entitlements: entitlements, autoPick: true)
        }
    }
}

struct ProductResultRow: View {
    let product: RemoteProduct

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(urlString: product.imageURL ?? "", size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.title).font(.subheadline).lineLimit(2).foregroundStyle(.primary)
                Text(product.retailer).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(formattedPrice).font(.headline.monospacedDigit()).foregroundStyle(.primary)
        }
    }

    private var formattedPrice: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = product.currencyCode
        return f.string(from: NSNumber(value: Double(product.priceCents) / 100)) ?? "—"
    }
}

// MARK: - Wish detail

struct WishDetailView: View {
    @Bindable var wish: Wish
    @Environment(\.openURL) private var openURL
    @Environment(GiftIntelligence.self) private var brain
    @Environment(Entitlements.self) private var entitlements
    @Environment(AppSession.self) private var session

    @State private var noteTone: NoteTone = .warm
    @State private var writingNote = false
    @State private var openingStore = false

    var body: some View {
        List {
            Section("Wish") {
                Text(wish.rawText).font(.body)
                // Only show what Pip searched / read if it adds something.
                if !wish.cleanedQuery.isEmpty,
                   wish.cleanedQuery.caseInsensitiveCompare(wish.rawText) != .orderedSame {
                    Text("Searched for: \(wish.cleanedQuery)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !wish.detailsRaw.isEmpty,
                   !wish.rawText.lowercased().contains(wish.detailsRaw.lowercased()) {
                    Label(wish.detailsRaw, systemImage: "tag")
                        .font(.caption).foregroundStyle(GiftlyTheme.evergreen)
                }
            }

            if wish.status == .finding {
                Section {
                    ElfHandoffView(stage: .searching, wish: wish.rawText)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            // Every product row opens that store; "Pick" swaps the choice.
            if let match = wish.chosenMatch {
                Section {
                    Button {
                        Task { await openStore(for: match) }
                    } label: {
                        ProductOptionRow(match: match, budgetLeftCents: budgetLeftCents, imageSize: 56)
                    }
                    .buttonStyle(.plain)

                    if !wish.matchReason.isEmpty {
                        Label(wish.matchReason, systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(GiftlyTheme.evergreen)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("\(Workshop.elfName)'s pick")
                }
            }

            let others = (wish.matches ?? []).filter { $0 !== wish.chosenMatch }
            if !others.isEmpty {
                Section {
                    ForEach(others, id: \.persistentModelID) { m in
                        HStack(spacing: 10) {
                            Button {
                                Task { await openStore(for: m) }
                            } label: {
                                ProductOptionRow(match: m, budgetLeftCents: budgetLeftCents, imageSize: 44)
                            }
                            .buttonStyle(.plain)

                            Button("Pick") { choose(m) }
                                .font(.subheadline.weight(.semibold))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                } header: {
                    Text("More options")
                } footer: {
                    Text("Tap a gift to see it at the store. Tap Pick to make it the one.")
                }
            }

            if wish.status == .notFound || (wish.status == .idea && !wish.statusNote.isEmpty) {
                Section {
                    if !wish.statusNote.isEmpty {
                        Text(wish.statusNote)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(wish.suggestions, id: \.self) { idea in
                        Button {
                            Haptics.tap()
                            wish.rawText = idea
                            retry()
                        } label: {
                            Label(idea, systemImage: "sparkle.magnifyingglass")
                        }
                    }
                    Button {
                        retry()
                    } label: {
                        Label("Search again", systemImage: "arrow.clockwise")
                    }
                    .disabled(!session.networkAllowed)
                    if let web = StoreLinks.webSearchURL(for: wish.rawText) {
                        Link(destination: web) {
                            Label("Look on Google Shopping", systemImage: "safari")
                        }
                    }
                } header: {
                    Text(wish.suggestions.isEmpty ? "No match yet" : "\(Workshop.elfName)'s ideas")
                }
            }

            Section {
                Picker("Tone", selection: $noteTone) {
                    ForEach(NoteTone.allCases) { tone in
                        Text(tone.display).tag(tone)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Card message", text: $wish.giftNote, axis: .vertical)
                    .lineLimit(2...6)

                HStack {
                    Button {
                        Task { await writeNote() }
                    } label: {
                        if writingNote {
                            ProgressView()
                        } else {
                            Label(wish.giftNote.isEmpty ? "Ask \(Workshop.elfName) to write it" : "Rewrite",
                                  systemImage: "wand.and.stars")
                        }
                    }
                    .disabled(writingNote)

                    Spacer()

                    if !wish.giftNote.isEmpty {
                        Button {
                            UIPasteboard.general.string = wish.giftNote
                            Haptics.tap()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Card note")
            }

            Section {
                Toggle("Bought it", isOn: Binding(
                    get: { wish.status == .bought },
                    set: {
                        Haptics.success()
                        wish.status = $0 ? .bought : (wish.chosenMatch != nil ? .matched : .idea)
                    }
                ))
            }
        }
        .scrollContentBackground(.hidden)
        .giftlyBackground()
        // Buy lives in a bar pinned to the bottom: always in reach, and out of
        // the List so the row clipping can't cut the pill's rounded ends.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let match = wish.chosenMatch {
                buyBar(for: match)
            }
        }
        .navigationTitle("Wish")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buyBar(for match: ProductMatch) -> some View {
        Button {
            Task { await openStore(for: match) }
        } label: {
            HStack(spacing: 10) {
                if openingStore {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "bag.fill")
                }
                Text("Buy at \(match.retailer)")
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(match.formattedPrice)
                    .monospacedDigit()
                    .fixedSize()
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(GiftlyPrimaryButtonStyle())
        .disabled(openingStore)
        .padding(.horizontal, GiftlyTheme.gutter)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    /// Budget left for this wish (occasion budget minus the other wishes).
    private var budgetLeftCents: Int? {
        guard let occasion = wish.occasion, occasion.hasBudget else { return nil }
        let others = (occasion.wishes ?? [])
            .filter { $0 !== wish }
            .compactMap { $0.chosenMatch?.priceCents }
            .reduce(0, +)
        return max(0, occasion.budgetCents - others)
    }

    private func choose(_ m: ProductMatch) {
        Haptics.tap()
        wish.chosenMatch?.isChosen = false
        m.isChosen = true
        wish.chosenMatch = m
        wish.matchReason = ""
        if wish.status != .bought { wish.status = .matched }
    }

    private func openStore(for match: ProductMatch) async {
        openingStore = true
        Haptics.tap()
        if let url = await StoreLinks.buyURL(for: match) {
            openURL(url)
        }
        openingStore = false
    }

    private func writeNote() async {
        writingNote = true
        let person = wish.occasion?.person
        let gift = String((wish.chosenMatch?.title ?? wish.rawText).prefix(80))
        let note = await brain.giftNote(recipient: person?.firstName ?? "you",
                                        relationship: person?.relationship ?? "",
                                        occasion: wish.occasion?.kind.display ?? "special day",
                                        gift: gift,
                                        tone: noteTone)
        wish.giftNote = note
        writingNote = false
    }

    private func retry() {
        Task {
            await WishFetcher.fetchPrice(
                for: wish, using: brain,
                priceService: GiftlyConfig.priceService,
                entitlements: entitlements, autoPick: true
            )
        }
    }
}

// MARK: - Product row (tap opens the store)

struct ProductOptionRow: View {
    let match: ProductMatch
    var budgetLeftCents: Int? = nil
    var imageSize: CGFloat = 44

    private var overBudget: Bool {
        guard let budgetLeftCents else { return false }
        return match.priceCents > budgetLeftCents
    }

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(urlString: match.imageURLString, size: imageSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(match.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(match.retailer)
                    Text("·").foregroundStyle(.tertiary)
                    Text(match.formattedPrice).monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if overBudget {
                    Text("Over budget")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
