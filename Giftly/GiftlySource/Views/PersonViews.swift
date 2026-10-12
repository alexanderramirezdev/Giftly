//
//  PersonViews.swift
//  Giftly
//
//  Person detail (their occasions + an Ideas button), the add/edit form,
//  and the FM-powered gift ideas screen.
//

import SwiftUI
import SwiftData

// MARK: - Person detail

struct PersonDetailView: View {
    @Bindable var person: Person

    @Environment(\.modelContext) private var context
    @State private var showingAddOccasion = false
    @State private var showingIdeas = false
    @State private var showingEdit = false

    var body: some View {
        List {
            if !person.interests.isEmpty {
                Section {
                    Button {
                        showingIdeas = true
                    } label: {
                        Label("Gift ideas for \(person.name)", systemImage: "sparkles")
                    }
                }
            }

            Section("Occasions") {
                let occasions = (person.occasions ?? []).sorted { $0.daysUntilNext < $1.daysUntilNext }
                if occasions.isEmpty {
                    ContentUnavailableView("No occasions",
                                           systemImage: "calendar",
                                           description: Text("Add a birthday, holiday, or any gift occasion."))
                }
                ForEach(occasions, id: \.persistentModelID) { occasion in
                    NavigationLink {
                        OccasionDetailView(occasion: occasion)
                    } label: {
                        UpcomingRow(occasion: occasion)
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingAddOccasion = true } label: {
                        Label("Add occasion", systemImage: "calendar.badge.plus")
                    }
                    Button { showingEdit = true } label: {
                        Label("Edit \(person.name)", systemImage: "pencil")
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
    }
}

// MARK: - Person add/edit

struct PersonEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var person: Person?

    @State private var name = ""
    @State private var relationship = ""
    @State private var ageBand = "child"
    @State private var interests = ""

    private let ageBands = ["child", "teen", "adult"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    TextField("Name", text: $name)
                    TextField("Relationship (e.g. Son, Mom)", text: $relationship)
                    Picker("Age", selection: $ageBand) {
                        ForEach(ageBands, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section {
                    TextField("dinosaurs, drawing, soccer…", text: $interests, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Interests")
                } footer: {
                    Text("Used on-device to suggest gift ideas. Never leaves your phone.")
                }
            }
            .navigationTitle(person == nil ? "New Person" : "Edit Person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let p = person else { return }
        name = p.name; relationship = p.relationship
        ageBand = p.ageBand.isEmpty ? "child" : p.ageBand
        interests = p.interestsRaw
    }

    private func save() {
        if let p = person {
            p.name = name; p.relationship = relationship
            p.ageBand = ageBand; p.interestsRaw = interests
        } else {
            let p = Person(name: name, relationship: relationship,
                           ageBand: ageBand, interestsRaw: interests)
            context.insert(p)
        }
        dismiss()
    }
}

// MARK: - Gift ideas (Foundation Models)

struct GiftIdeasView: View {
    let person: Person
    @Environment(GiftIntelligence.self) private var brain
    @Environment(\.dismiss) private var dismiss

    @State private var ideas: [String] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Thinking of gifts \(person.name) would love…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if ideas.isEmpty {
                    ContentUnavailableView("No ideas yet",
                                           systemImage: "sparkles",
                                           description: Text("Add a few interests for \(person.name) first."))
                } else {
                    List(ideas, id: \.self) { idea in
                        Label(idea, systemImage: "gift")
                    }
                }
            }
            .navigationTitle("Gift Ideas")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                ideas = await brain.ideas(for: person)
                loading = false
            }
        }
        .presentationDetents([.medium, .large])
    }
}
