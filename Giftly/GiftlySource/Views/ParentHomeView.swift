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
            List {
                if !upcomingOccasions.isEmpty {
                    Section("Coming up") {
                        ForEach(upcomingOccasions, id: \.persistentModelID) { occasion in
                            NavigationLink {
                                OccasionDetailView(occasion: occasion)
                            } label: {
                                UpcomingRow(occasion: occasion)
                            }
                        }
                    }
                }

                Section("People") {
                    if people.isEmpty {
                        ContentUnavailableView(
                            "No one yet",
                            systemImage: "person.2",
                            description: Text("Add someone you give gifts to, then start their wishlist.")
                        )
                    }
                    ForEach(people, id: \.persistentModelID) { person in
                        NavigationLink {
                            PersonDetailView(person: person)
                        } label: {
                            PersonRow(person: person)
                        }
                    }
                    .onDelete(perform: deletePeople)
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
                    Button { showingAddPerson = true } label: {
                        Label("Add person", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                PersonEditView()
            }
        }
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
            Image(systemName: occasion.kind.symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(occasion.title).font(.body.weight(.medium))
                Text(countdownText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if occasion.hasBudget {
                Text(budgetText).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
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
                .frame(width: 32, height: 32)
                .overlay(Text(initials).font(.caption.bold()).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.body.weight(.medium))
                if !person.relationship.isEmpty {
                    Text(person.relationship).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var initials: String {
        person.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}
