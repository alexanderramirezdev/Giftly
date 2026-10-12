//
//  PriceService.swift
//  Giftly
//
//  The ONLY part of the app that touches the open network. Everything is
//  behind a protocol so the UI never knows which provider is live, and so
//  we can develop against a mock with zero API spend.
//
//  Cost discipline (this is the whole business model, see README):
//   • We pay per search; users don't. So we CACHE: a ProductMatch carries
//     fetchedAt, and we only re-fetch when a result is stale (>2 days) or the
//     parent explicitly pulls to refresh.
//   • The provider key lives server-side in production, NOT in the app
//     bundle. The `endpoint` here points at YOUR thin proxy (a tiny Lambda /
//     Cloudflare Worker) that holds the real key and does the caching +
//     rate-limiting. Shipping the aggregator key in the app would let anyone
//     drain your account. The proxy is ~40 lines; see README "Price proxy".
//   • KID role can never call this — guarded by AppSession.networkAllowed.
//

import Foundation

struct PriceQueryResult {
    let products: [RemoteProduct]
}

/// What the proxy returns per product — provider-agnostic shape.
struct RemoteProduct: Decodable {
    let title: String
    let priceCents: Int
    let currencyCode: String
    let retailer: String
    let buyURL: String
    let imageURL: String?
}

protocol PriceService {
    /// Search for real, buyable products matching a cleaned query.
    /// Throws on network/decoding failure so the caller can show a retry.
    func search(query: String, limit: Int) async throws -> PriceQueryResult
}

enum PriceServiceError: LocalizedError {
    case notAllowedInKidMode
    case emptyQuery
    case badResponse(Int)
    case decoding
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notAllowedInKidMode: return "Price lookup isn't available in kid mode."
        case .emptyQuery:          return "Nothing to search for yet."
        case .badResponse(let c):  return "The price service returned an error (\(c))."
        case .decoding:            return "Couldn't read the price results."
        case .transport(let m):    return m
        }
    }
}

// MARK: - Live implementation (talks to YOUR proxy, not the aggregator directly)

/// Production price service. `baseURL` is your own proxy endpoint; it holds
/// the Bright Data (or other aggregator) key and does caching + abuse limits.
final class ProxyPriceService: PriceService {

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func search(query: String, limit: Int = 5) async throws -> PriceQueryResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PriceServiceError.emptyQuery }

        var comps = URLComponents(url: baseURL.appendingPathComponent("search"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = comps.url else { throw PriceServiceError.emptyQuery }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw PriceServiceError.badResponse(-1)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw PriceServiceError.badResponse(http.statusCode)
            }
            do {
                let decoded = try JSONDecoder().decode([RemoteProduct].self, from: data)
                return PriceQueryResult(products: decoded)
            } catch {
                throw PriceServiceError.decoding
            }
        } catch let e as PriceServiceError {
            throw e
        } catch {
            throw PriceServiceError.transport(error.localizedDescription)
        }
    }
}

// MARK: - Mock (development, previews, and the free-tier offline experience)

/// Returns believable fake products with no network. Use this as the default
/// until your proxy is live — the whole app is fully clickable against it.
final class MockPriceService: PriceService {

    func search(query: String, limit: Int = 5) async throws -> PriceQueryResult {
        try await Task.sleep(nanoseconds: 500_000_000)   // fake latency
        let retailers = ["Amazon", "Walmart", "Target", "eBay"]
        let base = max(999, abs(query.hashValue) % 9000 + 500)   // deterministic-ish price
        let products = (0..<min(limit, 4)).map { i in
            RemoteProduct(
                title: "\(query.capitalized) — option \(i + 1)",
                priceCents: base + i * 450,
                currencyCode: "USD",
                retailer: retailers[i % retailers.count],
                buyURL: "https://example.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                imageURL: nil
            )
        }
        return PriceQueryResult(products: products)
    }
}
