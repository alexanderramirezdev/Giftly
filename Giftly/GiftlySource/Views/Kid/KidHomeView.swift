//
//  KidHomeView.swift
//  Giftly
//
//  The kid experience. Deliberately tiny: pick who it's for (from the people
//  the parent already added), type or say a wish, done. NO prices, NO buy
//  links, NO network beyond the shared SwiftData store. Big friendly targets.
//  The only way out is the parental gate.
//
//  COPPA posture: this screen never calls the price service and never shows a
//  price. If you adopt the stricter "kid data stays on device" option from the
//  README, the kid's wishes write to the local-only store instead of the
//  CloudKit one — this view's code doesn't change, only the model container.
//

import SwiftUI
import SwiftData

struct KidHomeView: View {
    let onRequestParent: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]

    @State private var selectedPerson: Person?
    @State private var wishText = ""
    @State private var justAdded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("What do you wish for? 🎁")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                if people.count > 1 {
                    Picker("For", selection: $selectedPerson) {
                        ForEach(people, id: \.persistentModelID) { person in
                            Text(person.name).tag(Optional(person))
                        }
                    }
                    .pickerStyle(.menu)
                }

                TextField("I wish for…", text: $wishText, axis: .vertical)
                    .font(.title3)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    .lineLimit(1...3)
                    .frame(maxWidth: 480)

                Button {
                    addWish()
                } label: {
                    Label("Add to my list", systemImage: "plus.circle.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: 480)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(wishText.trimmingCharacters(in: .whitespaces).isEmpty)

                if justAdded {
                    Label("Added! 🌟", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }

                // The kid's own list (read-only, no prices)
                if let person = effectivePerson, !kidWishes(for: person).isEmpty {
                    List(kidWishes(for: person), id: \.persistentModelID) { wish in
                        Label(wish.rawText, systemImage: "star.fill")
                            .foregroundStyle(.primary)
                    }
                    .frame(maxHeight: 240)
                    .scrollContentBackground(.hidden)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("My Wishes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onRequestParent() } label: {
                        Label("Grown-up", systemImage: "person.badge.key")
                    }
                }
            }
            .onAppear { if selectedPerson == nil { selectedPerson = people.first } }
        }
    }

    private var effectivePerson: Person? { selectedPerson ?? people.first }

    private func kidWishes(for person: Person) -> [Wish] {
        (person.occasions ?? [])
            .flatMap { $0.wishes ?? [] }
            .filter { $0.addedBy == .kid }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func addWish() {
        guard let person = effectivePerson else { return }
        // Attach to the person's nearest upcoming occasion, or a catch-all one.
        let occasion = (person.occasions ?? [])
            .filter { $0.daysUntilNext >= 0 }
            .min { $0.daysUntilNext < $1.daysUntilNext }
            ?? ensureCatchAllOccasion(for: person)

        let wish = Wish(rawText: wishText.trimmingCharacters(in: .whitespacesAndNewlines),
                        addedBy: .kid, occasion: occasion)
        context.insert(wish)

        wishText = ""
        withAnimation { justAdded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { justAdded = false }
        }
    }

    private func ensureCatchAllOccasion(for person: Person) -> Occasion {
        if let existing = (person.occasions ?? []).first(where: { $0.kind == .justBecause }) {
            return existing
        }
        let o = Occasion(title: "\(person.name)'s Wishlist", kind: .justBecause,
                         date: .now, repeatsAnnually: false, person: person)
        context.insert(o)
        return o
    }
}
