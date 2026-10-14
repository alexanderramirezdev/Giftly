//
//  ScanListView.swift
//  Giftly
//
//  Scan a kid's wish list (or letter to Santa), or a list someone texted
//  (screenshots or pasted message), into the app:
//    1. scan with the document camera, or pick a photo
//    2. Vision reads the text on device (handwriting included)
//    3. Foundation Models cleans it into wishes and finds the child's name
//    4. the parent reviews: fix, untick, add, choose whose list and which
//       occasion (Christmas by default)
//    5. every wish is added and priced in the background, one at a time
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ScanItem: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var include: Bool = true
}

struct ScanListView: View {
    /// Paper list (camera or photo) or a texted list (screenshots or pasted text).
    enum Source { case paper, texts }
    var source: Source = .paper

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(GiftIntelligence.self) private var brain
    @Environment(Entitlements.self) private var entitlements
    @Environment(AppSession.self) private var session
    @Query(sort: \Person.name) private var people: [Person]

    private enum Step { case start, reading, review, nothingFound }
    private enum Target: Hashable { case christmas, birthday, wishlist }

    @State private var step: Step = .start
    @State private var showingCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var screenshotItems: [PhotosPickerItem] = []
    @State private var items: [ScanItem] = []
    @State private var person: Person?
    @State private var creatingPerson = false
    @State private var newName = ""
    @State private var target: Target = .christmas
    @State private var newItem = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(source == .texts ? "From a Text" : "Scan a Wish List")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .fullScreenCover(isPresented: $showingCamera) {
                    DocumentCameraView(onScan: { images in
                        showingCamera = false
                        Task { await read(images) }
                    }, onCancel: {
                        showingCamera = false
                    })
                    .ignoresSafeArea()
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task { await loadPhoto(item) }
                }
                .onChange(of: screenshotItems) { _, picked in
                    guard !picked.isEmpty else { return }
                    Task { await loadScreenshots(picked) }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .start:        startView
        case .reading:      readingView
        case .review:       reviewView
        case .nothingFound: nothingFoundView
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var startView: some View {
        if source == .texts { textsStartView } else { paperStartView }
    }

    /// Someone texted what they want: pick the screenshots, or paste the message.
    private var textsStartView: some View {
        VStack(spacing: 18) {
            Spacer()
            ElfView(pose: .reading, size: 110)
            Text("Got Their Wish List by Text?")
                .font(.workshop(24, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Screenshot the conversation, or copy the message. \(Workshop.elfName) picks out what they asked for and skips the chit chat. It all stays on your iPhone.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            PhotosPicker(selection: $screenshotItems, maxSelectionCount: 6, matching: .screenshots) {
                Label("Choose screenshots", systemImage: "photo.stack")
            }
            .buttonStyle(GiftlyPrimaryButtonStyle())
            PasteButton(payloadType: String.self) { strings in
                let text = strings.joined(separator: "\n")
                Task { await readPasted(text) }
            }
            .buttonBorderShape(.capsule)
            .labelStyle(.titleAndIcon)
            Text("Tip: in Messages, touch and hold a message, tap Copy, then come back and Paste.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground()
    }

    private var paperStartView: some View {
        VStack(spacing: 18) {
            Spacer()
            ElfView(pose: .reading, size: 110)
            Text("Got a list for Santa?")
                .font(.workshop(24, weight: .bold))
                .multilineTextAlignment(.center)
            Text(startBlurb)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if DocumentCameraView.isSupported {
                Button {
                    Haptics.tap()
                    showingCamera = true
                } label: {
                    Label("Scan with camera", systemImage: "doc.viewfinder")
                }
                .buttonStyle(GiftlyPrimaryButtonStyle())
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground()
    }

    private var startBlurb: String {
        "Snap a photo of your kid's wish list. \(Workshop.elfName) reads it, even messy handwriting, and turns it into gift ideas with prices. It all stays on your iPhone."
    }

    private var readingView: some View {
        VStack(spacing: 16) {
            ElfView(pose: .reading, size: 100)
            Text("\(Workshop.elfName) is reading the list…")
                .font(.workshop(17, weight: .medium))
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground()
    }

    private var nothingFoundView: some View {
        VStack(spacing: 16) {
            ElfView(pose: .idle, size: 90)
            Text("\(Workshop.elfName) couldn't find any wishes in that photo.")
                .font(.workshop(17, weight: .medium))
                .multilineTextAlignment(.center)
            Text(source == .texts
                 ? "Make sure the messages with the wishes are in the screenshot and the keyboard is closed, or copy and paste the message instead."
                 : "Try again in brighter light, with the whole page in view.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                screenshotItems = []
                step = .start
            }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .giftlyBackground()
    }

    private var reviewView: some View {
        Form {
            Section {
                personPicker
                if creatingPerson {
                    TextField("Their name", text: $newName)
                        .textInputAutocapitalization(.words)
                }
            } header: {
                Text("Whose List Is It?")
            }

            Section {
                targetPicker
            } header: {
                Text("Add It To")
            }

            Section {
                ForEach($items) { $item in
                    HStack(spacing: 10) {
                        Button {
                            item.include.toggle()
                        } label: {
                            Image(systemName: item.include ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(item.include ? GiftlyTheme.evergreen : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        TextField("Wish", text: $item.text)
                    }
                }
                .onDelete { offsets in items.remove(atOffsets: offsets) }

                HStack {
                    TextField("Add something \(Workshop.elfName) missed", text: $newItem)
                        .onSubmit(addManual)
                    Button("Add", action: addManual)
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text(foundTitle)
            } footer: {
                Text("Fix anything that was misread, and untick what you don't want.")
            }
        }
        .scrollContentBackground(.hidden)
        .giftlyBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) { addBar }
    }

    private var addBar: some View {
        Button(action: addAll) {
            Text(addButtonTitle)
                .lineLimit(1)
                .padding(.horizontal, 20)
        }
        .buttonStyle(GiftlyPrimaryButtonStyle())
        .disabled(!canAdd)
        .opacity(canAdd ? 1 : 0.5)
        .padding(.horizontal, GiftlyTheme.gutter)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // MARK: Pickers

    private var personPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(people, id: \.persistentModelID) { p in
                    ChoiceChip(selected: !creatingPerson && person?.persistentModelID == p.persistentModelID) {
                        person = p
                        creatingPerson = false
                    } content: {
                        HStack(spacing: 6) {
                            PersonAvatar(person: p, size: 24)
                            Text(p.firstName)
                        }
                    }
                }
                ChoiceChip(selected: creatingPerson) {
                    creatingPerson = true
                    person = nil
                } content: {
                    Label("New", systemImage: "plus")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var targetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ChoiceChip(selected: target == .christmas) { target = .christmas } content: {
                    Label("Christmas", systemImage: "gift")
                }
                if hasBirthday {
                    ChoiceChip(selected: target == .birthday) { target = .birthday } content: {
                        Label("Birthday", systemImage: "birthday.cake")
                    }
                }
                ChoiceChip(selected: target == .wishlist) { target = .wishlist } content: {
                    Label("Just a wishlist", systemImage: "star")
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Derived

    private var includedCount: Int {
        items.filter { $0.include && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var foundTitle: String {
        let noun: String = items.count == 1 ? "Wish" : "Wishes"
        return "\(Workshop.elfName) Found \(items.count) \(noun)"
    }

    private var ownerName: String {
        if creatingPerson { return newName.trimmingCharacters(in: .whitespaces) }
        return person?.firstName ?? ""
    }

    private var addButtonTitle: String {
        let noun: String = includedCount == 1 ? "wish" : "wishes"
        let name = ownerName
        if name.isEmpty { return "Add \(includedCount) \(noun)" }
        return "Add \(includedCount) \(noun) for \(name)"
    }

    private var canAdd: Bool {
        let hasOwner: Bool = creatingPerson ? !newName.trimmingCharacters(in: .whitespaces).isEmpty : person != nil
        return hasOwner && includedCount > 0
    }

    private var hasBirthday: Bool {
        guard !creatingPerson, let person else { return false }
        return (person.occasions ?? []).contains { $0.kind == .birthday }
    }

    // MARK: Actions

    private func loadPhoto(_ item: PhotosPickerItem) async {
        step = .reading
        var image: UIImage?
        if let data = try? await item.loadTransferable(type: Data.self) {
            image = UIImage(data: data)
        }
        photoItem = nil
        if let image {
            await read([image])
        } else {
            step = .nothingFound
        }
    }

    private func loadScreenshots(_ picked: [PhotosPickerItem]) async {
        step = .reading
        var images: [UIImage] = []
        for item in picked {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        screenshotItems = []
        guard !images.isEmpty else {
            step = .nothingFound
            return
        }
        let conversation = await ListScanner.readConversation(in: images)
        let parsed = await brain.parseConversation(conversation.transcript, contactName: conversation.contactName)
        finish(items: parsed.items, name: parsed.forName)
    }

    private func readPasted(_ text: String) async {
        step = .reading
        let parsed = await brain.parseConversation(text)
        finish(items: parsed.items, name: parsed.forName)
    }

    private func finish(items found: [String], name: String) {
        items = found.map { ScanItem(text: $0) }
        preselectPerson(named: name)
        // A texted list is usually for that person's next occasion, not
        // necessarily Christmas, but Christmas stays the default this time of year.
        step = items.isEmpty ? .nothingFound : .review
    }

    private func read(_ images: [UIImage]) async {
        step = .reading
        let text = await ListScanner.recognizeText(in: images)
        let parsed = await brain.parseWishList(text)
        items = parsed.items.map { ScanItem(text: $0) }
        preselectPerson(named: parsed.childName)
        step = items.isEmpty ? .nothingFound : .review
    }

    /// Match the signed name to someone already in the app, or offer to add them.
    private func preselectPerson(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstToken = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        if !trimmed.isEmpty,
           let match = people.first(where: {
               $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
                   || $0.firstName.caseInsensitiveCompare(firstToken) == .orderedSame
           }) {
            person = match
            creatingPerson = false
        } else if !trimmed.isEmpty {
            creatingPerson = true
            newName = trimmed
            person = nil
        } else if person == nil {
            if let first = people.first {
                person = first
            } else {
                creatingPerson = true
            }
        }
    }

    private func addManual() {
        let text = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        items.append(ScanItem(text: text))
        newItem = ""
    }

    private func resolvePerson() -> Person? {
        guard creatingPerson else { return person }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = people.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let colors = ["#4C8BF5", "#E4572E", "#2F7D4F", "#B565C9", "#E3B04B", "#17BEBB"]
        let p = Person(name: name, colorHex: colors.randomElement() ?? "#4C8BF5")
        context.insert(p)
        return p
    }

    private func resolveOccasion(for p: Person) -> Occasion {
        let existing = p.occasions ?? []
        switch target {
        case .christmas:
            if let x = existing.first(where: { $0.kind == .christmas }) { return x }
            let date = ContactImporter.nextDate(month: 12, day: 25) ?? .now
            let o = Occasion(title: "\(p.firstName)'s Christmas", kind: .christmas,
                             date: date, repeatsAnnually: true, person: p)
            context.insert(o)
            return o
        case .birthday:
            if let b = existing.first(where: { $0.kind == .birthday }) { return b }
            fallthrough
        case .wishlist:
            if let w = existing.first(where: { $0.kind == .justBecause }) { return w }
            let o = Occasion(title: "\(p.firstName)'s Wishlist", kind: .justBecause,
                             date: .now, repeatsAnnually: false, person: p)
            context.insert(o)
            return o
        }
    }

    private func addAll() {
        guard let owner = resolvePerson() else { return }
        let occasion = resolveOccasion(for: owner)
        var created: [Wish] = []
        for item in items where item.include {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let wish = Wish(rawText: text, addedBy: .parent, occasion: occasion)
            wish.status = session.networkAllowed ? .finding : .idea
            context.insert(wish)
            created.append(wish)
        }
        Haptics.success()
        dismiss()

        guard session.networkAllowed else { return }
        let brain = self.brain
        let entitlements = self.entitlements
        Task {
            // One at a time: gentle on the price service, and each wish fills
            // in visibly as Pip works down the list.
            for wish in created {
                await WishFetcher.fetchPrice(for: wish, using: brain,
                                             priceService: GiftlyConfig.priceService,
                                             entitlements: entitlements, autoPick: true)
            }
        }
    }
}

// MARK: - Choice chip

/// A selectable capsule used for quick pickers (person, occasion).
struct ChoiceChip<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            content()
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(fill))
                .overlay(Capsule().stroke(stroke, lineWidth: 1.5))
                .foregroundStyle(textColor)
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        if selected { return GiftlyTheme.cranberry.opacity(0.15) }
        return Color.secondary.opacity(0.08)
    }
    private var stroke: Color {
        if selected { return GiftlyTheme.cranberry }
        return Color.clear
    }
    private var textColor: Color {
        if selected { return GiftlyTheme.cranberry }
        return Color.primary
    }
}
