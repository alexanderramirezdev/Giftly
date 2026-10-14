//
//  ParentHomeView.swift
//  Giftly
//
//  The parent's main screen: people + upcoming occasions sorted by date,
//  plus the "Ideas" entry. iPad gets NavigationSplitView; iPhone gets a
//  stack — size-class driven so it adapts without a rebuild.
//

import SwiftUI
import SwiftData

struct ParentHomeView: View {
    let onLock: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]

    @State private var showingQuickAdd = false
    @State private var showingContactPicker = false
    @State private var showingScan = false
    @State private var showingTexts = false
    @State private var showingSettings = false
    @State private var showingNewPerson = false
    @State private var ideasPerson: Person?
    @State private var banner: String?

    // The body is split into small pieces on purpose: one giant expression
    // made the Swift type checker time out.
    var body: some View {
        NavigationStack {
            screen
                .navigationTitle("Pip")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingQuickAdd) { QuickAddWishView() }
                .sheet(isPresented: $showingScan) { ScanListView() }
                .sheet(isPresented: $showingTexts) { ScanListView(source: .texts) }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .sheet(isPresented: $showingNewPerson) { PersonEditView(person: nil) }
                .sheet(item: $ideasPerson) { person in GiftIdeasView(person: person) }
                .background(contactPicker)
                .overlay(alignment: .top) { bannerView }
        }
    }

    // MARK: Pieces

    private var screen: some View {
        ZStack {
            // Warm themed base + living seasonal background.
            GiftlyTheme.background.ignoresSafeArea()
            GiftlyAtmosphereView(season: nil, giftFullness: atmosphereFullness)
                .ignoresSafeArea()

            if people.isEmpty {
                HomeEmptyState(onAdd: { showingQuickAdd = true },
                               onImport: { showingContactPicker = true },
                               onScan: { showingScan = true })
            } else {
                ScrollView {
                    // One glass container so the cards render and blend as a set.
                    GlassEffectContainer(spacing: 22) {
                    VStack(spacing: 22) {
                        PipGreetingRow(next: upcomingOccasions.first,
                                       onIdeas: { person in ideasPerson = person },
                                       onScan: { showingScan = true })
                        addButtons
                        if !upcomingOccasions.isEmpty { comingUpCard }
                        peopleCard
                        if pastCount > 0 { pastEventsLink }
                    }
                    }
                    .padding(.horizontal, GiftlyTheme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// The main job, one tap away, with scanning right beside it.
    private var addButtons: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                showingQuickAdd = true
            } label: {
                Label("Add a gift idea", systemImage: "plus")
            }
            .buttonStyle(GiftlyPrimaryButtonStyle())

            Menu {
                Button { showingScan = true } label: {
                    Label("Scan a paper list", systemImage: "doc.viewfinder")
                }
                Button { showingTexts = true } label: {
                    Label("From a text message", systemImage: "message")
                }
            } label: {
                Image(systemName: "doc.viewfinder")
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 50)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Scan a list or a text")
        }
    }

    private var comingUpCard: some View {
        let items: [Occasion] = upcomingOccasions
        return VStack(alignment: .leading, spacing: 10) {
            GiftlySectionHeader(title: "Coming Up", systemImage: "calendar")
            GiftlyCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { idx in
                        comingUpRow(items[idx], showDivider: idx < items.count - 1)
                    }
                }
            }
        }
    }

    private func comingUpRow(_ occasion: Occasion, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            SwipeToDelete(itemName: occasion.title,
                          detail: "Its gift ideas are deleted too.") {
                withAnimation { context.delete(occasion) }
                try? context.save()
            } content: {
                NavigationLink {
                    OccasionDetailView(occasion: occasion)
                } label: {
                    UpcomingRow(occasion: occasion)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())   // the whole row is tappable, not just the text
                }
                .buttonStyle(.plain)
            }
            if showDivider { Divider().padding(.leading, 50) }
        }
    }

    private var peopleCard: some View {
        let everyone: [Person] = people
        return VStack(alignment: .leading, spacing: 10) {
            GiftlySectionHeader(title: "People", systemImage: "person.2")
            GiftlyCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(everyone.indices, id: \.self) { idx in
                        personRow(everyone[idx], showDivider: true)
                    }
                    addPersonRow
                }
            }
        }
    }

    private func personRow(_ person: Person, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            SwipeToDelete(itemName: person.firstName,
                          detail: "Their occasions and gift ideas are deleted too.") {
                withAnimation { context.delete(person) }
                try? context.save()
            } content: {
                NavigationLink {
                    PersonDetailView(person: person)
                } label: {
                    PersonRow(person: person)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())   // the whole row is tappable, not just the text
                }
                .buttonStyle(.plain)
            }
            if showDivider { Divider().padding(.leading, 56) }
        }
    }

    /// Adding someone new, right in the People card.
    private var addPersonRow: some View {
        Button {
            Haptics.tap()
            showingNewPerson = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.tint.opacity(0.15)))
                Text("Add Someone")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Past events live behind one row, not listed out on the home screen.
    private var pastEventsLink: some View {
        let count: Int = pastCount
        let noun: String = count == 1 ? "event" : "events"
        return NavigationLink {
            PastEventsView()
        } label: {
            GiftlyCard(padding: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Past Events").font(.body.weight(.semibold)).foregroundStyle(.primary)
                        Text("\(count) \(noun), with what you gave")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }

    private var pastCount: Int {
        var n = 0
        for person in people {
            for o in person.occasions ?? [] where o.belongsInPast { n += 1 }
        }
        return n
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        if AppSession.kidModeEnabled {
            ToolbarItem(placement: .topBarLeading) {
                Button { onLock() } label: {
                    Label("Kid mode", systemImage: "lock")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            addMenu
        }
    }

    private var addMenu: some View {
        Menu {
            Button { showingNewPerson = true } label: {
                Label("Add Someone", systemImage: "person.badge.plus")
            }
            Button { showingQuickAdd = true } label: {
                Label("Add a Gift Idea", systemImage: "gift")
            }
            Button { showingScan = true } label: {
                Label("Scan a wish list", systemImage: "doc.viewfinder")
            }
            Button { showingTexts = true } label: {
                Label("From a text message", systemImage: "message")
            }
            Button { showingContactPicker = true } label: {
                Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    private var contactPicker: some View {
        ContactPickerPresenter(isPresented: $showingContactPicker) { contacts in
            let result = ContactImporter.importContacts(contacts, into: context, existing: people)
            showBanner(for: result)
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner {
            Text(banner)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(GiftlyTheme.card))
                .overlay(Capsule().stroke(GiftlyTheme.cardStroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// How full the gift stack looks: fraction of the nearest occasion picked.
    private var atmosphereFullness: Double {
        guard let next = upcomingOccasions.first, next.wishCount > 0 else { return 1.0 }
        return Double(next.sortedWishesPicked) / Double(next.wishCount)
    }

    /// Next 5 dated occasions. Written as typed steps: as one chained
    /// expression it timed out the type checker.
    private var upcomingOccasions: [Occasion] {
        var all: [Occasion] = []
        for person in people {
            all.append(contentsOf: person.occasions ?? [])
        }
        // Undated catch all wishlists aren't "coming up".
        let dated: [Occasion] = all.filter { (o: Occasion) -> Bool in
            o.kind != .justBecause && o.daysUntilNext >= 0
        }
        let sorted: [Occasion] = dated.sorted { (a: Occasion, b: Occasion) -> Bool in
            a.daysUntilNext < b.daysUntilNext
        }
        return Array(sorted.prefix(5))
    }

    private func deletePeople(_ offsets: IndexSet) {
        for i in offsets { context.delete(people[i]) }
    }

    private func showBanner(for result: ContactImporter.Result) {
        var parts: [String] = []
        if result.added > 0 {
            let noun: String = result.added == 1 ? "person" : "people"
            parts.append("added \(result.added) \(noun)")
        }
        if result.updated > 0 {
            parts.append("updated \(result.updated)")
        }
        if result.occasions > 0 {
            let noun: String = result.occasions == 1 ? "date" : "dates"
            parts.append("found \(result.occasions) \(noun)")
        }
        guard !parts.isEmpty else { return }
        Haptics.success()
        let message: String = Workshop.elfName + " " + parts.joined(separator: ", ")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            banner = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeOut(duration: 0.3)) { banner = nil }
        }
    }
}

// MARK: - Pip's greeting

/// Pip with one short, useful line about what's next. Written from the data
/// with fixed templates: the on-device model produced fact dumps here, so it
/// stays out of this spot.
struct PipGreetingRow: View {
    let next: Occasion?
    var onIdeas: (Person) -> Void = { _ in }
    var onScan: () -> Void = {}

    @Environment(GiftIntelligence.self) private var brain
    @State private var spoken: String?
    @State private var cheering = false

    /// Pip is the star of the home screen, not a footnote.
    private let pipSize: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PipSays(text: spoken ?? template, pose: cheering ? .cheering : pose, elfSize: pipSize) {
                // Tap Pip and he cheers.
                Haptics.soft()
                cheering = true
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    cheering = false
                }
            }
            .animation(.easeInOut(duration: 0.35), value: spoken)
            actionButton
                .padding(.leading, pipSize + 10)
        }
        .task(id: template) {
            // The template is correct on its own and shows instantly. Pip's
            // on device rewrite replaces it only if it keeps every fact.
            spoken = nil
            let line: String = await brain.pipVoice(template, keep: keepTokens)
            spoken = line
        }
    }

    // MARK: What Pip says

    private var name: String { next?.person?.firstName ?? "" }

    private var what: String {
        guard let o = next else { return "" }
        if o.kind == .birthday, !name.isEmpty { return name + "'s birthday" }
        return o.title
    }

    private var when: String {
        guard let o = next else { return "" }
        let d = o.daysUntilNext
        if d == 0 { return "today" }
        if d == 1 { return "tomorrow" }
        return "in \(d) days"
    }

    private var template: String {
        guard let o = next else {
            return "Add a birthday or holiday and I'll count down for you. Got a list for Santa? I can scan it."
        }
        if o.hasBudget && o.committedTotalCents > o.budgetCents {
            let over: Int = (o.committedTotalCents - o.budgetCents) / 100
            return "\(what) is $\(over) over budget. Want to swap something cheaper?"
        }
        if o.wishCount == 0 {
            return "\(what) is \(when) and the list is empty. I can suggest some ideas."
        }
        if o.boughtCount == o.wishCount {
            return "Everything for \(what) is bought. Nice work!"
        }
        if o.sortedWishesPicked == 0 {
            return "\(what) is \(when). Nothing's picked yet, so let's choose a gift."
        }
        let left: Int = o.wishCount - o.boughtCount
        let noun: String = left == 1 ? "gift" : "gifts"
        return "\(what) is \(when). \(left) \(noun) left to buy."
    }

    /// Facts the rewrite must keep word for word (numbers are checked too).
    private var keepTokens: [String] {
        var tokens: [String] = []
        if !name.isEmpty { tokens.append(name) }
        return tokens
    }

    private var pose: ElfPose {
        guard let o = next else { return .idle }
        if o.wishCount > 0 && o.boughtCount == o.wishCount { return .cheering }
        if o.daysUntilNext == 0 { return .cheering }
        return .idle
    }

    // MARK: What Pip offers to do

    @ViewBuilder
    private var actionButton: some View {
        if let o = next {
            if o.wishCount == 0, let person = o.person {
                Button {
                    Haptics.tap()
                    onIdeas(person)
                } label: {
                    pill("Ideas for \(person.firstName)", icon: "sparkles")
                }
                .buttonStyle(.plain)
            } else if o.boughtCount < o.wishCount {
                NavigationLink {
                    OccasionDetailView(occasion: o)
                } label: {
                    pill("Open \(o.title)", icon: "arrow.right.circle")
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                Haptics.tap()
                onScan()
            } label: {
                pill("Scan a wish list", icon: "doc.viewfinder")
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(GiftlyTheme.cranberry.opacity(0.12)))
            .foregroundStyle(GiftlyTheme.cranberry)
    }
}

// MARK: - Rows

struct UpcomingRow: View {
    let occasion: Occasion
    /// Off inside a List row (the List draws its own chevron).
    var showsChevron: Bool = true

    private var boxKind: OccasionKind { occasion.kind }

    var body: some View {
        HStack(spacing: 12) {
            // A wrapped gift in their color that livens up as the date nears.
            GiftBoxMark(color: boxColor, stage: boxStage, size: 40, seed: boxSeed, kind: boxKind)

            VStack(alignment: .leading, spacing: 3) {
                Text(occasion.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if occasion.hasBudget {
                Text(budgetText)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(pillColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(pillBackground))
                    .fixedSize()
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    /// "Tomorrow · no wishes yet" / "in 3 days · 1 of 2 picked"
    private var statusLine: String {
        let d = occasion.daysUntilNext
        let when: String
        if d == 0 { when = "Today" }
        else if d == 1 { when = "Tomorrow" }
        else { when = "In \(d) days" }
        let progress: String
        if occasion.wishCount == 0 { progress = "no wishes yet" }
        else if occasion.boughtCount == occasion.wishCount { progress = "all bought" }
        else if occasion.sortedWishesPicked == 0 { progress = "nothing picked yet" }
        else { progress = "\(occasion.sortedWishesPicked) of \(occasion.wishCount) picked" }
        return "\(when) · \(progress)"
    }

    private var overBudget: Bool { occasion.committedTotalCents > occasion.budgetCents }

    // Precomputed so the view body stays cheap for the type checker.
    private var boxColor: Color {
        let hex: String = occasion.person?.colorHex ?? "#C0392B"
        return Color(hex: hex)
    }
    private var boxStage: GiftStage { GiftStage.forDays(occasion.daysUntilNext) }
    private var boxSeed: Double {
        let n: Int = occasion.title.utf8.count % 9
        return Double(n) * 0.7
    }
    private var statusColor: Color {
        if occasion.needsAttention { return Color.orange }
        return Color.secondary
    }
    private var pillColor: Color {
        if overBudget { return Color.red }
        return GiftlyTheme.evergreen
    }
    private var pillBackground: Color { pillColor.opacity(0.10) }

    private var budgetText: String {
        "$\(occasion.committedTotalCents / 100) / $\(occasion.budgetCents / 100)"
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(person: person, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if !person.relationship.isEmpty {
                    Text(person.relationship).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
    }

}


// MARK: - Warm empty state (first run)

struct HomeEmptyState: View {
    let onAdd: () -> Void
    var onImport: () -> Void = {}
    var onScan: () -> Void = {}
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ElfView(pose: .cheering, size: 110)
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Let's make gifting easy")
                    .font(.title2.bold())
                Text("Hi, I'm \(Workshop.elfName). Tell me who you shop for and I'll keep every wish and the best price in one calm place.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Button {
                Haptics.tap()
                onAdd()
            } label: {
                Label("Add a gift idea", systemImage: "plus")
            }
            .buttonStyle(GiftlyPrimaryButtonStyle())
            .frame(maxWidth: 360)
            .padding(.top, 4)
            .opacity(appeared ? 1 : 0)

            HStack(spacing: 20) {
                Button {
                    Haptics.tap()
                    onScan()
                } label: {
                    Label("Scan a wish list", systemImage: "doc.viewfinder")
                        .font(.body.weight(.semibold))
                }
                Button {
                    Haptics.tap()
                    onImport()
                } label: {
                    Label("Import contacts", systemImage: "person.crop.circle.badge.plus")
                        .font(.body.weight(.semibold))
                }
            }
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Attention nudge row

struct AttentionNudge: View {
    let occasion: Occasion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: occasion.kind.symbol)
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(occasion.title).font(.body.weight(.semibold))
                Text(nudgeLine).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private var nudgeLine: String {
        let d = occasion.daysUntilNext
        let when: String
        if d == 0 { when = "is today" }
        else if d == 1 { when = "is tomorrow" }
        else { when = "in \(d) days" }
        if occasion.wishCount == 0 {
            return "\(when) · no wishes added yet"
        }
        return "\(when) · nothing picked yet"
    }
}
