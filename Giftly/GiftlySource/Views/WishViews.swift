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

// MARK: - Add a wish

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
            .navigationTitle("Add a Wish")
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

    var body: some View {
        List {
            Section("Wish") {
                Text(wish.rawText).font(.body)
                if !wish.cleanedQuery.isEmpty {
                    Text("Searched for: \(wish.cleanedQuery)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if wish.status == .finding {
                Section {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Finding the best price…").foregroundStyle(.secondary)
                    }
                }
            }

            if let match = wish.chosenMatch {
                Section("Chosen gift") {
                    HStack(spacing: 12) {
                        ProductThumbnail(urlString: match.imageURLString, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.title).font(.body.weight(.medium)).lineLimit(3)
                            Text("\(match.retailer) · \(match.formattedPrice)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Updated \(match.fetchedAt.formatted(.relative(presentation: .named)))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if let url = match.buyURL {
                        Button {
                            Haptics.tap()
                            openURL(url)
                        } label: {
                            Label("Open to buy", systemImage: "safari")
                        }
                    }
                }
            }

            // Other candidates the parent can switch to.
            let others = (wish.matches ?? []).filter { $0 !== wish.chosenMatch }
            if !others.isEmpty {
                Section("Other options") {
                    ForEach(others, id: \.persistentModelID) { m in
                        Button {
                            Haptics.tap()
                            wish.chosenMatch?.isChosen = false
                            m.isChosen = true
                            wish.chosenMatch = m
                            if wish.status != .bought { wish.status = .matched }
                        } label: {
                            HStack(spacing: 12) {
                                ProductThumbnail(urlString: m.imageURLString, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.title).font(.subheadline).lineLimit(2).foregroundStyle(.primary)
                                    Text(m.retailer).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(m.formattedPrice).font(.subheadline.monospacedDigit()).foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }

            if wish.status == .notFound {
                Section {
                    Label("Couldn't find a match yet.", systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                    Button {
                        retry()
                    } label: {
                        Label("Search again", systemImage: "arrow.clockwise")
                    }
                    .disabled(!session.networkAllowed)
                }
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
        .navigationTitle("Wish")
        .navigationBarTitleDisplayMode(.inline)
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
