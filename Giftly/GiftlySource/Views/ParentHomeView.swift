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

    @State private var showingAddPerson = false
    @State private var selectedPerson: Person?

    var body: some View {
        NavigationStack {
            ZStack {
                // Warm themed base + living seasonal background.
                GiftlyTheme.background.ignoresSafeArea()
                GiftlyAtmosphereView(season: atmosphereSeason, giftFullness: atmosphereFullness)
                    .ignoresSafeArea()

                if people.isEmpty {
                    HomeEmptyState { showingAddPerson = true }
                } else {
                    ScrollView {
                        VStack(spacing: 22) {
                            // Nudge card
                            if !needsAttention.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    GiftlySectionHeader(title: "Needs your attention",
                                                        systemImage: "bell.badge",
                                                        tint: .orange)
                                    GiftlyCard(padding: 6) {
                                        VStack(spacing: 0) {
                                            ForEach(Array(needsAttention.enumerated()), id: \.element.persistentModelID) { idx, occasion in
                                                NavigationLink {
                                                    OccasionDetailView(occasion: occasion)
                                                } label: {
                                                    AttentionNudge(occasion: occasion)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 12)
                                                }
                                                .buttonStyle(.plain)
                                                if idx < needsAttention.count - 1 { Divider().padding(.leading, 50) }
                                            }
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: GiftlyTheme.cardRadius, style: .continuous)
                                            .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
                                    )
                                }
                            }

                            // Coming up card
                            if !upcomingOccasions.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    GiftlySectionHeader(title: "Coming up", systemImage: "calendar")
                                    GiftlyCard(padding: 6) {
                                        VStack(spacing: 0) {
                                            ForEach(Array(upcomingOccasions.enumerated()), id: \.element.persistentModelID) { idx, occasion in
                                                NavigationLink {
                                                    OccasionDetailView(occasion: occasion)
                                                } label: {
                                                    UpcomingRow(occasion: occasion)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 12)
                                                }
                                                .buttonStyle(.plain)
                                                if idx < upcomingOccasions.count - 1 { Divider().padding(.leading, 50) }
                                            }
                                        }
                                    }
                                }
                            }

                            // People card
                            VStack(alignment: .leading, spacing: 10) {
                                GiftlySectionHeader(title: "People", systemImage: "person.2")
                                GiftlyCard(padding: 6) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(people.enumerated()), id: \.element.persistentModelID) { idx, person in
                                            NavigationLink {
                                                PersonDetailView(person: person)
                                            } label: {
                                                PersonRow(person: person)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 12)
                                            }
                                            .buttonStyle(.plain)
                                            if idx < people.count - 1 { Divider().padding(.leading, 56) }
                                        }
                                    }
                                }
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
            .navigationTitle("Giftly")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onLock() } label: {
                        Label("Kid mode", systemImage: "lock")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showingAddPerson = true } label: {
                        Label("Add person", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                PersonEditView()
            }
        }
    }

    /// Occasions within 3 weeks that have nothing picked yet.
    private var needsAttention: [Occasion] {
        people
            .flatMap { $0.occasions ?? [] }
            .filter { $0.needsAttention }
            .sorted { $0.daysUntilNext < $1.daysUntilNext }
            .prefix(3)
            .map { $0 }
    }

    /// The season for the living background: from the nearest upcoming
    /// occasion's date when there is one, else the current month.
    private var atmosphereSeason: GiftlySeason? {
        if let next = upcomingOccasions.first {
            let m = Calendar.current.component(.month, from: next.date)
            // Christmas-type occasions always read as winter regardless of date.
            if next.kind == .christmas { return .winter }
            return GiftlySeason.forMonth(m)
        }
        return nil
    }

    /// How full the gift stack looks: fraction of the nearest occasion picked.
    private var atmosphereFullness: Double {
        guard let next = upcomingOccasions.first, next.wishCount > 0 else { return 1.0 }
        return Double(next.sortedWishesPicked) / Double(next.wishCount)
    }

    private var upcomingOccasions: [Occasion] {
        people
            .flatMap { $0.occasions ?? [] }
            .filter { $0.daysUntilNext >= 0 }
            .sorted { $0.daysUntilNext < $1.daysUntilNext }
            .prefix(5)
            .map { $0 }
    }

    private func deletePeople(_ offsets: IndexSet) {
        for i in offsets { context.delete(people[i]) }
    }
}

// MARK: - Rows

struct UpcomingRow: View {
    let occasion: Occasion

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(GiftlyTheme.cranberry.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: occasion.kind.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(GiftlyTheme.cranberry)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(occasion.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(countdownText)
                    Text("·").foregroundStyle(.tertiary)
                    Text(occasion.progressLine)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if occasion.hasBudget {
                Text(budgetText)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(GiftlyTheme.evergreen)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(GiftlyTheme.evergreen.opacity(0.10)))
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var countdownText: String {
        let d = occasion.daysUntilNext
        if d == 0 { return "Today 🎉" }
        if d == 1 { return "Tomorrow" }
        return "in \(d) days"
    }

    private var budgetText: String {
        let spent = Double(occasion.committedTotalCents) / 100
        let budget = Double(occasion.budgetCents) / 100
        return String(format: "$%.0f / $%.0f", spent, budget)
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: person.colorHex))
                .frame(width: 40, height: 40)
                .overlay(Text(initials).font(.subheadline.bold()).foregroundStyle(.white))
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

    private var initials: String {
        person.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}


// MARK: - Warm empty state (first run)

struct HomeEmptyState: View {
    let onAdd: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "gift.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Let's make gifting easy")
                    .font(.title2.bold())
                Text("Add someone you love, and Giftly keeps every wish and the best price in one calm place.")
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
                Label("Add your first person", systemImage: "plus")
            }
            .buttonStyle(GiftlyPrimaryButtonStyle())
            .frame(maxWidth: 360)
            .padding(.top, 4)
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
