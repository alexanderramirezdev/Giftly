//
//  ProxyWarmup.swift
//  Giftly
//
//  The price proxy runs on Render, which puts the service to sleep after a
//  quiet stretch and takes up to a minute to wake it. Before this, the first
//  searches after a nap failed in a few seconds and every wish said
//  "No exact match". Now:
//    • opening Pip pings /health so the proxy is usually awake by the time
//      someone adds a wish
//    • every search waits for that wake up (one shared ping, not one per wish)
//    • wishes that failed only because the service was unreachable are
//      retried on their own the next time Pip comes to the front
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
enum ProxyWarmup {
    private static var lastAwake: Date?
    private static var inFlight: Task<Bool, Never>?

    /// True once the proxy answers /health. Shares one request between
    /// callers, and skips the ping if it answered in the last few minutes.
    static func wake(force: Bool = false) async -> Bool {
        if !force, let lastAwake, Date.now.timeIntervalSince(lastAwake) < 240 { return true }
        if let inFlight { return await inFlight.value }
        let task = Task<Bool, Never> { await ping() }
        inFlight = task
        let ok = await task.value
        inFlight = nil
        if ok { lastAwake = .now }
        return ok
    }

    /// Up to about 75 seconds: Render answers once the instance is up. While
    /// it starts, it may hold the request or answer with a loading page, so
    /// keep asking until /health returns JSON.
    private static func ping() async -> Bool {
        let url = GiftlyConfig.proxyBaseURL.appendingPathComponent("health")
        let deadline = Date.now.addingTimeInterval(75)
        while Date.now < deadline {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let result: (Data, URLResponse)? = try? await URLSession.shared.data(for: request)
            if let result,
               let http = result.1 as? HTTPURLResponse, http.statusCode == 200,
               let body = String(data: result.0, encoding: .utf8), body.contains("\"ok\"") {
                return true
            }
            try? await Task.sleep(for: .seconds(3))
        }
        return false
    }

    /// Re-run wishes that came back empty only because the service couldn't
    /// be reached. Doesn't touch real "no match" results.
    static func retryStranded(in context: ModelContext) {
        let notes: Set<String> = [WishFetcher.unreachableNote, WishFetcher.keyRejectedNote]
        let all: [Wish] = (try? context.fetch(FetchDescriptor<Wish>())) ?? []
        let stranded: [Wish] = all.filter { $0.status == .notFound && notes.contains($0.statusNote) }
        guard !stranded.isEmpty else { return }
        for wish in stranded.prefix(12) {
            wish.status = .finding
            Task {
                await WishFetcher.fetchPrice(for: wish,
                                             using: GiftIntelligence.shared,
                                             priceService: GiftlyConfig.priceService,
                                             entitlements: Entitlements.shared,
                                             autoPick: true)
            }
        }
    }
}

/// Wakes the price proxy whenever Pip comes to the front, then retries any
/// stranded wishes.
private struct KeepPriceServiceAwake: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(AppSession.self) private var session

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active, session.networkAllowed else { return }
                Task {
                    if await ProxyWarmup.wake() {
                        ProxyWarmup.retryStranded(in: context)
                    }
                }
            }
    }
}

extension View {
    func keepsPriceServiceAwake() -> some View {
        modifier(KeepPriceServiceAwake())
    }
}
