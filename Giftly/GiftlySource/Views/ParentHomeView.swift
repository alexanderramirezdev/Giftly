//
//  ParentHomeView.swift
//  Giftly
//
//  The workshop floor: Pip the elf greets you, the deadline board lists
//  what's coming up, and everyone you shop for has a gift that gets
//  livelier as their date nears. A conveyor belt of gifts runs along the
//  bottom. Data and navigation are unchanged from before.
//

import SwiftUI
import SwiftData

struct ParentHomeView: View {
    let onLock: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]

    @State private var showingAddPerson = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ElfGreetingRow(hasPeople: !people.isEmpty, next: upcomingOccasions.first)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

                if !upcomingOccasions.isEmpty {
                    Section {
                        ForEach(upcomingOccasions, id: \.persistentModelID) { occasion in
                            NavigationLink {
                                OccasionDetailView(occasion: occasion)
                            } label: {
                                UpcomingRow(occasion: occasion)
                            }
                            .workshopRow()
                        }
                    } header: {
                        WorkshopHeader("On the deadline board")
                    }
                }

                Section {
                    if people.isEmpty {
                        ContentUnavailableView(
                            "No one here yet",
                            systemImage: "gift",
                            description: Text("Add someone you give gifts to, then start their wishlist.")
                        )
                        .listRowBackground(Color.clear)
                    }
                    ForEach(people, id: \.persistentModelID) { person in
                        NavigationLink {
                            PersonDetailView(person: person)
                        } label: {
                            PersonRow(person: person)
                        }
                        .workshopRow()
                    }
                    .onDelete(perform: deletePeople)
                } header: {
                    WorkshopHeader("Your people")
                }
            }
            .workshopScene()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                GiftConveyor()
            }
            .navigationTitle("Giftly")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if AppSession.kidModeEnabled {
                        Button { onLock() } label: {
                            Label("Kid mode", systemImage: "lock")
                        }
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

// MARK: - Elf greeting

struct ElfGreetingRow: View {
    let hasPeople: Bool
    let next: Occasion?

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ElfView(pose: .idle, size: 72)

            Text(message)
                .font(.workshop(15, weight: .medium))
                .foregroundStyle(Workshop.cream)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(Workshop.woodLight, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Workshop.grain, lineWidth: 1)
                )
                .padding(.bottom, 14)
        }
    }

    private var message: String {
        if !hasPeople {
            return "Hi, I'm \(Workshop.elfName). Tell me who you shop for and I'll get a workbench ready."
        }
        guard let o = next else {
            return "The workbench is quiet. Add an occasion and I'll start the countdown."
        }
        let d = o.daysUntilNext
        switch d {
        case 0:      return "It's today! \(o.title) is ready to unwrap."
        case 1:      return "\(o.title) is tomorrow. Last call for wrapping!"
        case 2...7:  return "\(o.title) is \(d) days out. The elves are hustling."
        default:     return "\(o.title) is \(d) days away. Want me to check the shelves?"
        }
    }
}

// MARK: - Rows

struct UpcomingRow: View {
    let occasion: Occasion

    var body: some View {
        HStack(spacing: 12) {
            GiftBoxMark(color: Color(hex: occasion.person?.colorHex ?? "#4C8BF5"),
                        stage: GiftStage.forDays(occasion.daysUntilNext),
                        size: 46,
                        seed: Double(occasion.title.utf8.count % 9) * 0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(occasion.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Workshop.cream)
                Text(countdownText)
                    .font(.caption)
                    .foregroundStyle(Workshop.dimCream)
            }
            Spacer()
            if occasion.hasBudget {
                Text(budgetText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Workshop.dimCream)
            }
        }
    }

    private var countdownText: String {
        let d = occasion.daysUntilNext
        if d == 0 { return "Today! Time to unwrap" }
        if d == 1 { return "Tomorrow, last call for wrapping" }
        if d <= 7 { return "\(d) days, the elves are hustling" }
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
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Workshop.brass.opacity(0.7), lineWidth: 1.5))
                .overlay(Text(initials).font(.caption.bold()).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Workshop.cream)
                if !person.relationship.isEmpty {
                    Text(person.relationship)
                        .font(.caption)
                        .foregroundStyle(Workshop.dimCream)
                }
            }
        }
    }

    private var initials: String {
        person.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}
