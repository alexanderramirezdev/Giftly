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
    @State private var phase: Phase = .typing
    @State private var cleaned: WishInterpretation?
    @State private var results: [RemoteProduct] = []
    @State private var errorMessage: String?

    // LIVE: talks to the local price proxy (Fast SERP → real Google Shopping
    // prices). For the shipped app, change this URL to your deployed https
    // proxy. For simulator testing against localhost, see the ATS note in
    // Info.plist (NSAllowsLocalNetworking).
    private let priceService: PriceService =
        ProxyPriceService(baseURL: URL(string: "http://localhost:8787")!)

    enum Phase { case typing, thinking, searching, results, error }

    var body: some View {
        NavigationStack {
            Form {
                Section("The wish") {
                    TextField("e.g. the lego race car with lights", text: $rawText, axis: .vertical)
                        .lineLimit(1...3)
                        .disabled(phase == .thinking || phase == .searching)
                }

                if let c = cleaned, phase != .typing {
                    Section("Searching for") {
                        Text(c.query).font(.body.weight(.medium))
                        if !c.blurb.isEmpty {
                            Text(c.blurb).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                switch phase {
                case .thinking:
                    Section { Label("Figuring out what to search…", systemImage: "sparkles") }
                case .searching:
                    Section { HStack { ProgressView(); Text("Finding real prices…") } }
                case .results:
                    Section("Pick the right one") {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, product in
                            Button { choose(product) } label: {
                                ProductResultRow(product: product)
                            }
                        }
                    }
                case .error:
                    Section {
                        Label(errorMessage ?? "Something went wrong", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Button("Try again") { Task { await run() } }
                    }
                case .typing:
                    EmptyView()
                }

                if !entitlements.isPlus && phase == .typing {
                    Section {
                        Text("\(entitlements.remainingFreeLookups) price lookups left this month")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add a Wish")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if phase == .typing {
                        Button("Find it") { Task { await run() } }
                            .disabled(rawText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    // The pipeline: FM clean → (allowance check) → price search.
    private func run() async {
        guard session.networkAllowed else { return }   // belt & suspenders: never in kid mode

        phase = .thinking
        let interpretation = await brain.clean(rawText)
        cleaned = interpretation

        guard entitlements.canDoPriceLookup else {
            errorMessage = "You've used all your free price lookups this month. Upgrade to Plus for unlimited."
            phase = .error
            return
        }

        phase = .searching
        do {
            let result = try await priceService.search(query: interpretation.query, limit: 5)
            entitlements.recordLookup()
            results = result.products
            phase = results.isEmpty ? .error : .results
            if results.isEmpty { errorMessage = "No products found. Try rewording the wish." }
        } catch {
            errorMessage = (error as? PriceServiceError)?.errorDescription ?? error.localizedDescription
            phase = .error
        }
    }

    private func choose(_ product: RemoteProduct) {
        let wish = Wish(rawText: rawText, addedBy: .parent, occasion: occasion)
        wish.cleanedQuery = cleaned?.query ?? rawText
        let match = ProductMatch(title: product.title,
                                 priceCents: product.priceCents,
                                 currencyCode: product.currencyCode,
                                 retailer: product.retailer,
                                 buyURLString: product.buyURL,
                                 imageURLString: product.imageURL ?? "")
        match.isChosen = true
        match.wish = wish
        wish.matches = [match]
        wish.chosenMatch = match
        wish.status = .matched
        context.insert(wish)
        dismiss()
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

    var body: some View {
        List {
            Section("Wish") {
                Text(wish.rawText).font(.body)
                if !wish.cleanedQuery.isEmpty {
                    Text("Searched: \(wish.cleanedQuery)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let match = wish.chosenMatch {
                Section("Chosen gift") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(match.title).font(.body.weight(.medium))
                        Text("\(match.retailer) · \(match.formattedPrice)")
                            .foregroundStyle(.secondary)
                        Text("Price updated \(match.fetchedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let url = match.buyURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Open to buy", systemImage: "safari")
                        }
                    }
                }
            }

            Section {
                Toggle("Bought it", isOn: Binding(
                    get: { wish.status == .bought },
                    set: { wish.status = $0 ? .bought : (wish.chosenMatch != nil ? .matched : .idea) }
                ))
            }
        }
        .navigationTitle("Wish")
        .navigationBarTitleDisplayMode(.inline)
    }
}
