//
//  OccasionViews.swift
//  Giftly
//
//  The wishlist screen (the heart of the parent app) and the occasion form.
//  Each wish shows its status, chosen product + price, and a running total
//  against the budget. Add-wish → FM clean → price search lives here.
//

import SwiftUI
import SwiftData

// MARK: - Occasion detail = the wishlist

struct OccasionDetailView: View {
    @Bindable var occasion: Occasion

    @Environment(\.modelContext) private var context
    @State private var showingAddWish = false

    var body: some View {
        List {
            if occasion.hasBudget {
                Section {
                    BudgetBar(spentCents: occasion.committedTotalCents,
                              budgetCents: occasion.budgetCents)
                }
                .listRowBackground(GiftlyTheme.card)
            }

            Section("Wishlist") {
                let wishes = (occasion.wishes ?? []).sorted { $0.createdAt < $1.createdAt }
                if wishes.isEmpty {
                    ContentUnavailableView {
                        Label("No wishes yet", systemImage: "sparkles")
                    } description: {
                        Text("Add the first wish in plain words. Giftly finds the best price while you keep going.")
                    } actions: {
                        Button { Haptics.tap(); showingAddWish = true } label: {
                            Text("Add a wish")
                        }
                        .buttonStyle(GiftlyPrimaryButtonStyle())
                        .frame(maxWidth: 240)
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(wishes, id: \.persistentModelID) { wish in
                    NavigationLink {
                        WishDetailView(wish: wish)
                    } label: {
                        WishRow(wish: wish)
                    }
                    .listRowBackground(GiftlyTheme.card)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                .onDelete { offsets in
                    let wishes = (occasion.wishes ?? []).sorted { $0.createdAt < $1.createdAt }
                    for i in offsets { context.delete(wishes[i]) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .giftlyBackground()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: occasion.wishCount)
        .animation(.default, value: occasion.sortedWishesPicked)
        .navigationTitle(occasion.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddWish = true } label: {
                    Label("Add wish", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWish) {
            AddWishView(occasion: occasion)
        }
    }
}

struct BudgetBar: View {
    let spentCents: Int
    let budgetCents: Int

    private var fraction: Double {
        guard budgetCents > 0 else { return 0 }
        return min(1.2, Double(spentCents) / Double(budgetCents))
    }
    private var over: Bool { spentCents > budgetCents }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Budget")
                Spacer()
                Text("$\(spentCents / 100) of $\(budgetCents / 100)")
                    .monospacedDigit()
                    .foregroundStyle(over ? .red : .secondary)
            }
            .font(.subheadline)
            ProgressView(value: fraction)
                .tint(over ? .red : .green)
        }
        .padding(.vertical, 4)
    }
}

struct WishRow: View {
    let wish: Wish

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail if we have a chosen product, else a status icon.
            if let m = wish.chosenMatch {
                ProductThumbnail(urlString: m.imageURLString, size: 44)
            } else {
                statusIcon
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(wish.rawText).font(.body.weight(.medium)).lineLimit(1)
                subtitle
            }
            Spacer()
            if wish.status == .finding {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var subtitle: some View {
        switch wish.status {
        case .matched, .bought:
            if let m = wish.chosenMatch {
                Text("\(m.retailer) · \(m.formattedPrice)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(wish.status.display).font(.caption).foregroundStyle(.secondary)
            }
        case .finding:
            Text(wish.status.display)
                .font(.caption).foregroundStyle(.tint)
        case .notFound:
            Text("Tap to search again")
                .font(.caption).foregroundStyle(.secondary)
        case .idea:
            Text("Idea").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch wish.status {
        case .idea:     Image(systemName: "lightbulb").foregroundStyle(.yellow)
        case .finding:  Image(systemName: "sparkles").foregroundStyle(.tint)
        case .matched:  Image(systemName: "cart").foregroundStyle(.tint)
        case .bought:   Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .notFound: Image(systemName: "questionmark").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Occasion add/edit

struct OccasionEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let person: Person
    var occasion: Occasion?

    @State private var title = ""
    @State private var kind: OccasionKind = .birthday
    @State private var date = Date.now
    @State private var repeatsAnnually = true
    @State private var hasBudget = false
    @State private var budget = 100.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Occasion") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $kind) {
                        ForEach(OccasionKind.allCases, id: \.self) {
                            Label($0.display, systemImage: $0.symbol).tag($0)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Repeats every year", isOn: $repeatsAnnually)
                }
                Section {
                    Toggle("Set a budget", isOn: $hasBudget)
                    if hasBudget {
                        Stepper("$\(Int(budget))", value: $budget, in: 10...2000, step: 10)
                    }
                }
            }
            .navigationTitle(occasion == nil ? "New Occasion" : "Edit Occasion")
            .onChange(of: kind) { _, newKind in
                if title.isEmpty { title = "\(person.name)'s \(newKind.display)" }
                repeatsAnnually = newKind.defaultRepeats
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(title.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if title.isEmpty { title = "\(person.name)'s \(kind.display)" }
        guard let o = occasion else { return }
        title = o.title; kind = o.kind; date = o.date
        repeatsAnnually = o.repeatsAnnually
        hasBudget = o.hasBudget; budget = Double(o.budgetCents) / 100
    }

    private func save() {
        let cents = hasBudget ? Int(budget * 100) : 0
        if let o = occasion {
            o.title = title; o.kind = kind; o.date = date
            o.repeatsAnnually = repeatsAnnually; o.budgetCents = cents
        } else {
            let o = Occasion(title: title, kind: kind, date: date,
                             repeatsAnnually: repeatsAnnually,
                             budgetCents: cents, person: person)
            context.insert(o)
        }
        dismiss()
    }
}
