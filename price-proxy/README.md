# Giftly price proxy

The Giftly app talks only to this little server. This server holds your Bright
Data token and does the caching. **The token never ships inside the app.**

## What you need from Bright Data (just 1 value now)

The dataset is already wired: **`gd_ltppk50q18kdw67omz`** (Google Shopping
search, US). You only need to supply:

1. **API token** — Bright Data dashboard → Account settings → API tokens.
   (It's also the `Bearer ___` in any scraper's cURL sample.)

> How it works: this scraper takes a Google Shopping **search URL**, not a raw
> keyword. The proxy builds that URL for you from the user's query
> (`https://www.google.com/search?ibp=oshop&q=<query>`) and sends
> `{ input: [{ url, country: "US" }], limit_per_input: <limit> }`. It returns a
> LIST of products. Confirmed output fields: `title`, `merchant`, `price`
> (string), `currency`, `rating`, `product_url` — the proxy normalizes these to
> the app's shape.

## Run it locally (test real prices on the simulator today)

```bash
cd price-proxy
npm install
BRIGHTDATA_TOKEN="your-token" npm start
```

You should see `Configured: true`. Test it:

```bash
curl "http://localhost:8787/search?q=lego+race+car&limit=5"
```

That returns the exact JSON the app decodes:
```json
[{ "title": "...", "priceCents": 2999, "currencyCode": "USD",
   "retailer": "...", "buyURL": "...", "imageURL": "..." }]
```

## Point the app at it

In `GiftlySource/Views/WishViews.swift`, the `AddWishView` has:
```swift
private let priceService: PriceService = MockPriceService()
```
Switch it to:
```swift
private let priceService: PriceService =
    ProxyPriceService(baseURL: URL(string: "http://localhost:8787")!)
```

> **Simulator + localhost + ATS:** the iOS simulator can reach your Mac's
> `localhost`, but Apple's App Transport Security blocks plain `http://` by
> default. For local testing only, add an ATS exception for `localhost` in
> Info.plist (see the main project notes). Once you deploy the proxy to a real
> `https://` host, remove the exception — production is clean HTTPS.

## Deploy later (for the shipped app)

This file runs unchanged on Render / Railway / Fly.io / a small VM. Set
`BRIGHTDATA_TOKEN` and `DATASET_ID` as secret env vars in the host's dashboard
(never commit them). Then point `ProxyPriceService(baseURL:)` at the public
`https://` URL. Swap the in-memory cache for the host's KV/Redis if you want the
cache to survive restarts.
