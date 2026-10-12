# Giftly

**Every wishlist, every occasion — with real prices.** Giftly keeps one calm,
organized place for what the people you love actually want (birthdays,
Christmas, anniversaries, year-round), and turns each plain-words wish into a
real, buyable product with a live price and a buy link. On-device intelligence
cleans the wish and suggests gift ideas; a small cloud proxy fetches real
prices. A living, seasonal background makes it feel warm instead of clinical.

> © 2026 Alexander Ramirez (Ramirez Labs). All rights reserved. See `LICENSE`.

---

## What it does

- **People & occasions** — add the people you give gifts to, each with their
  own occasions (birthday, Christmas, anniversary, …), dates, and budgets.
- **Plain-words wishes** — type "the lego race car with lights"; Giftly cleans
  it on-device and finds matching products.
- **Real prices, in the background** — add a wish and it appears instantly with
  a "finding the best price" state, then fills in with a real product, price,
  retailer, image, and buy link. No waiting on a spinner.
- **Budget tracking** — a running total per occasion against an optional budget.
- **Bought tracking** — mark gifts bought so nobody double-gifts.
- **Gift ideas** — on-device suggestions from a person's interests.
- **Kid mode** — a playful, offline "add my wishes" screen for children. No
  prices, no network, no buying. Guarded by a parental gate.
- **A living seasonal world** — a warm, animated background (snowy pine,
  wrapped gifts, peeking elves, a strolling reindeer, drifting snow) that keys
  to the nearest occasion's season.

---

## Architecture

```
Role (parent | kid)  — the spine; decides whether the network is reachable.
│
├── Data        SwiftData models (+ CloudKit-ready): Person, Occasion, Wish, ProductMatch
├── Brain       GiftIntelligence — on-device Foundation Models (clean text, gift ideas). NO network.
├── Prices      PriceService → the Giftly price proxy (the ONLY networked layer; parent-only)
├── Design      GiftlyTheme (palette/cards/buttons) + GiftlyBackground (warm, seasonal)
└── Atmosphere  Clock-driven ambient engine (snow, elves, reindeer) — Reduce-Motion safe
```

### The three layers and what each may do

| Layer | Files | Network? | Job |
|---|---|---|---|
| Data | `Models/Models.swift` | No | People/occasions/wishes/products (SwiftData) |
| Brain | `Services/GiftIntelligence.swift` | **No** | Clean messy text, generate gift ideas (on-device FM) |
| Prices | `Services/PriceService.swift`, `WishFetcher.swift` | **Yes (parent only)** | Fetch real products + prices via the proxy |

The split is the privacy promise: nothing about your kids leaves the phone
**except an anonymous product-search string** when a parent asks for a price.

---

## The price proxy (`price-proxy/`)

Apple's Foundation Models framework is an on-device LLM with **no internet** —
it can't know a live price. So the FM cleans the query; a shopping data provider
returns real products. The app talks **only** to a small Node proxy, never to
the provider directly, so the provider API key never ships inside the app.

- **Provider:** Bright Data **SERP API** (real-time Google Shopping results,
  ~1–2s), chosen after the async "Web Scraper" dataset proved too slow (2–5 min
  per keyword — wrong tool for a live request).
- **Endpoint used:** `POST https://api.brightdata.com/request` with
  `{ zone, url: "google.com/search?q=…&udm=28&gl=us&hl=en", format: json,
  data_format: parsed }`. `gl=us` is required or Google returns a "specify
  shopping country" notice instead of products.
- **Normalizes** each result to `{ title, priceCents, currencyCode, retailer,
  buyURL, imageURL }`.
- **Trusted-retailer ranking** — recognizable stores (Amazon, Walmart, Target,
  LEGO, …) rank first; marketplace third-party sellers rank below.
- **Caching** — each query is cached 2 days, so a repeat/refresh costs $0 and
  stays fast. This is the cost-control heart of the free tier.
- **Graceful notices** — rate-limit / country / block notices are detected and
  returned as a clear "try again in a moment" instead of an empty list.

### Running the proxy

Local (for development):
```bash
cd price-proxy
npm install
BRIGHTDATA_TOKEN="your-token" SERP_ZONE="your-zone" npm start
curl "http://localhost:8787/search?q=lego+race+car&limit=5"
```

Deployed (production): the proxy runs on **Render** as a free web service
(`render.yaml` included). Set `BRIGHTDATA_TOKEN` as a secret env var in the
Render dashboard; `SERP_ZONE` is set in `render.yaml`. The app points at the
deployed `https://` URL in `GiftlySource/Support/GiftlyConfig.swift`.

---

## Design system

- **`GiftlyTheme`** — warm palette (cranberry primary, evergreen secondary,
  gold accent), cozy cream surfaces, dark-mode aware. Reusable `GiftlyCard`,
  `GiftlySectionHeader`, and `GiftlyPrimaryButtonStyle`.
- **`GiftlyBackground`** — one warm, inviting background on every screen so the
  app feels like a single space. Two intensities: `.full` (home/onboarding —
  the living seasonal scene) and `.subtle` (inner screens — warm wash + a few
  faint, slow snowflakes). Applied via `.giftlyBackground()`.
- **Atmosphere engine** (`Views/Atmosphere/`) — Giftly's own clock-driven motion
  (not animation-chained), so motion is smooth and impossible to desync, and it
  fully respects Reduce Motion. The winter scene (pine, gifts, elves, reindeer,
  snow, sparkles) is unique to Giftly.

---

## Safety & kids (COPPA)

- **Parental gate** — a **press-and-hold** challenge (hold a filling ring for
  ~1.5s) before entering grown-up mode. Warm, no arithmetic, and the standard
  "a young child won't do this" friction Apple expects for kid-adjacent apps.
- **Gate required by default** — entering grown-up mode always requires the gate
  **unless** the device's Declared Age Range (iOS 18.4+) affirmatively says
  adult. Unknown age or child → gate required.
- **Kid side is offline** — the kid screen never calls the price service and
  shows no price, enforced in the UI and in the services (`networkAllowed`).

---

## Project layout

```
Giftly/
├── LICENSE
├── README.md
├── Giftly.xcodeproj
├── Giftly/
│   ├── GiftlySource/
│   │   ├── App/            GiftlyApp (SwiftData + CloudKit container, app-wide tint)
│   │   ├── Models/         Models, AppSession
│   │   ├── Services/       GiftIntelligence, PriceService, WishFetcher, ParentalGate, Entitlements
│   │   ├── Views/          Root, ParentHome, Person, Occasion, Wish, ProductThumbnail
│   │   │   ├── Atmosphere/  AtmosphereEngine, GiftlyAtmosphereView, WinterScene, GiftlyBackground
│   │   │   └── Kid/         KidHomeView
│   │   └── Support/        GiftlyTheme, GiftlyConfig, Color+Hex
│   ├── Assets.xcassets
│   └── Info.plist
└── price-proxy/            Node proxy: server.js, package.json, render.yaml, README
```

---

## Status

**Working end to end:** full parent flow (people → occasions → wishlists →
background price fetch → pick → budget → bought), kid mode, press-and-hold
parental gate, on-device wish cleanup + gift ideas, live Google Shopping prices
via the deployed proxy with trusted-retailer ranking and caching, a cohesive
warm design system across every screen, and a living winter atmosphere on the
home screen.

**Next (toward App Store, holiday 2026):** lock a parent-only free v1 (defer kid
mode + paid subscription to a January v1.1 to minimize review risk), app icon +
screenshots + listing, upgrade the proxy off Render's free (sleeping) tier,
and — post-launch — richer illustrator-grade seasonal art and the remaining
seasons (spring/summer/autumn) on the existing engine.

**Build note:** full builds happen in Xcode (SwiftData/#Preview macro plugins
don't run from the CLI). Every source file is syntax-validated.
