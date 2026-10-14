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
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddWish = false
    @State private var showingEdit = false
    @State private var confirmingDelete = false

    var body: some View {
        List {
            if occasion.hasBudget {
                Section {
                    BudgetBar(spentCents: occasion.committedTotalCents,
                              budgetCents: occasion.budgetCents)
                }
                .listRowBackground(GiftlyTheme.glassRow)
            }

            if let url = occasion.inviteURL {
                Section {
                    Link(destination: url) {
                        Label("Open the invite", systemImage: "envelope.open")
                    }
                }
                .listRowBackground(GiftlyTheme.glassRow)
            }

            Section("Wishlist") {
                let wishes = (occasion.wishes ?? []).sorted { $0.createdAt < $1.createdAt }
                if wishes.isEmpty {
                    ContentUnavailableView {
                        Label("No wishes yet", systemImage: "sparkles")
                    } description: {
                        Text("Add the first wish in plain words. Pip finds the best price while you keep going.")
                    } actions: {
                        Button { Haptics.tap(); showingAddWish = true } label: {
                            Text("Add a gift idea")
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
                    .listRowBackground(GiftlyTheme.glassRow)
                    // Swipe right: mark bought, or jump straight to the store.
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Haptics.success()
                            wish.status = wish.status == .bought
                                ? (wish.chosenMatch != nil ? .matched : .idea)
                                : .bought
                        } label: {
                            Label(wish.status == .bought ? "Not bought" : "Bought",
                                  systemImage: "checkmark.circle")
                        }
                        .tint(GiftlyTheme.evergreen)

                        if let match = wish.chosenMatch {
                            Button {
                                Task {
                                    if let url = await StoreLinks.buyURL(for: match) { openURL(url) }
                                }
                            } label: {
                                Label("Buy", systemImage: "bag")
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                .onDelete { offsets in
                    let wishes = (occasion.wishes ?? []).sorted { $0.createdAt < $1.createdAt }
                    for i in offsets { context.delete(wishes[i]) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        // The event's own scene (balloons, hearts, caps, lights), with
        // confetti on the day itself.
        .background(OccasionScene(kind: occasion.kind, isToday: occasion.daysUntilNext == 0))
        .giftlyBackground()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: occasion.wishCount)
        .animation(.default, value: occasion.sortedWishesPicked)
        .navigationTitle(occasion.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if occasion.person != nil {
                        Button { showingEdit = true } label: {
                            Label("Edit Occasion", systemImage: "pencil")
                        }
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete Occasion", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddWish = true } label: {
                    Label("Add a gift idea", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWish) {
            AddWishView(occasion: occasion)
        }
        .sheet(isPresented: $showingEdit) {
            if let person = occasion.person {
                OccasionEditView(person: person, occasion: occasion)
            }
        }
        .confirmationDialog("Delete \(occasion.title)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteOccasion)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its gift ideas are deleted too.")
        }
    }
}

extension OccasionDetailView {
    /// Leave the screen first, then delete, so the view never shows a
    /// deleted occasion.
    fileprivate func deleteOccasion() {
        let doomed = occasion
        Haptics.success()
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            context.delete(doomed)
            try? context.save()
        }
    }
}

struct BudgetBar: View {
    let spentCents: Int
    let budgetCents: Int

    private var fraction: Double {
        guard budgetCents > 0 else { return 0 }
        let ratio: Double = Double(spentCents) / Double(budgetCents)
        return max(0.0, min(1.0, ratio))   // ProgressView only accepts 0...1; red color shows "over"
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
            // Pip runs the shelves while the price is found, then the
            // product thumbnail, else a status icon.
            if wish.status == .finding {
                ElfView(pose: .running, size: 30)
                    .frame(width: 44, height: 44)
            } else if let m = wish.chosenMatch {
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
            Text("\(Workshop.elfName) is checking the shelves…")
                .font(.caption).foregroundStyle(.tint)
        case .notFound:
            Text(notFoundLine)
                .font(.caption).foregroundStyle(.orange)
        case .idea:
            Text(wish.statusNote.isEmpty ? "Idea" : wish.statusNote)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var notFoundLine: String {
        if wish.statusNote == WishFetcher.unreachableNote {
            return "Couldn't reach the stores, tap to try again"
        }
        if wish.suggestions.isEmpty { return "No match yet, tap to try again" }
        return "No exact match, tap for \(Workshop.elfName)'s ideas"
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
    @State private var inviteLink = ""
    /// True until the parent types their own title, so changing the type
    /// updates "Alex's Birthday" to "Alex's Graduation".
    @State private var titleIsAuto = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Occasion") {
                    Picker("Type", selection: $kind) {
                        ForEach(OccasionKind.KindGroup.allCases, id: \.self) { group in
                            Section(group.rawValue) {
                                ForEach(OccasionKind.kinds(in: group), id: \.self) {
                                    Label($0.display, systemImage: $0.symbol).tag($0)
                                }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Title", text: titleBinding)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Repeats every year", isOn: $repeatsAnnually)
                }
                Section {
                    Toggle("Set a budget", isOn: $hasBudget)
                    if hasBudget {
                        Stepper("$\(Int(budget))", value: $budget, in: 10...2000, step: 10)
                    }
                }
                Section {
                    TextField("Invite link (Apple Invites, Evite…)", text: $inviteLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Paste the party link to keep it one tap away.")
                }
            }
            .navigationTitle(occasion == nil ? "New Occasion" : "Edit Occasion")
            .onChange(of: kind) { _, newKind in
                if titleIsAuto || title.isEmpty { title = autoTitle(for: newKind) }
                repeatsAnnually = newKind.defaultRepeats
                if let known = newKind.nextKnownDate { date = known }
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

    private var titleBinding: Binding<String> {
        Binding(
            get: { title },
            set: { title = $0; titleIsAuto = false }
        )
    }

    private func autoTitle(for kind: OccasionKind) -> String {
        "\(person.firstName)'s \(kind.display)"
    }

    private func load() {
        if title.isEmpty { title = autoTitle(for: kind) }
        guard let o = occasion else { return }
        title = o.title; kind = o.kind; date = o.date
        titleIsAuto = (o.title == autoTitle(for: o.kind))
        repeatsAnnually = o.repeatsAnnually
        hasBudget = o.hasBudget; budget = Double(o.budgetCents) / 100
        inviteLink = o.inviteURLString
    }

    private func save() {
        let cents = hasBudget ? Int(budget * 100) : 0
        if let o = occasion {
            o.title = title; o.kind = kind; o.date = date
            o.repeatsAnnually = repeatsAnnually; o.budgetCents = cents
            o.inviteURLString = inviteLink
        } else {
            let o = Occasion(title: title, kind: kind, date: date,
                             repeatsAnnually: repeatsAnnually,
                             budgetCents: cents, person: person)
            o.inviteURLString = inviteLink
            context.insert(o)
        }
        dismiss()
    }
}
