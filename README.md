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

---

## Workshop update (Oct 2026): Pip, richer profiles, imports, gate

**v1 is parent only.** `AppSession.kidModeEnabled` (false) skips the role
picker, shows `WorkshopWelcomeView` on first launch, and hides the Kid mode
button. Flip it to true for the January v2. All kid code stays in place.

**Pip, the head elf** (`Views/Workshop/`): drawn in code, four poses (idle,
reading, running, cheering), static under Reduce Motion. He greets you on home
(on device line from facts only, template fallback), peeks from behind the
winter tree, runs in a wish row while its price is found, and fills the wish
detail while searching. `GiftBoxMark` gives each upcoming occasion a gift in
the person's color that wiggles, glints, then pops open on the day.

**Richer profiles.** Person now has favorite colors, stores, sizes, already
has, doesn't like, job, contact photo. Pip's card shows how much he knows and
what to fill next. Everything feeds the gift ideas.

**Adding things** (Add menu on home):
- Add a gift idea: one screen. Pick the person (or "+ New" to add them right
  there), pick the occasion, type. Stays open for a whole list.
- Scan a wish list (`ScanListView`, `ListScanner`): document camera or a photo,
  Vision reads the text on device (handwriting too), Foundation Models turns it
  into clean wishes and finds the child's name, the parent reviews and edits,
  then every wish is added and priced one at a time.
- Contacts: the system picker, no permission prompt, multi select. Brings name,
  photo, birthday (repeating occasion, age group from the year, year not
  stored), anniversaries, job.
- Occasions take a pasted invite link (Apple Invites has no public API).

**Grown-ups gate** (`ParentalGate.swift`): birth year, then Face ID or the
device passcode. Falls back to the arithmetic challenge only if the device has
no passcode. The year is never stored. Only reachable when kid mode is on.

**Foundation Models** (`GiftIntelligence.swift`, all on device, all with plain
fallbacks, all output passed through `noDashes`): wish details (brand, color,
size, age, must haves), ranking the price results so autoPick lands on the best
match with a reason ("Pip's pick"), ideas from the whole profile plus budget
left and what's already listed, card notes in three tones, reading scanned
wish lists, and Pip's home line. Pip's line is built from the real data first,
then the model only rewrites the wording in his voice; every name, number and
day word is checked and anything that drifts falls back to the template.

**Info.plist** adds `NSCameraUsageDescription` (scanning) and
`NSFaceIDUsageDescription` (grown-ups gate).

## Seasons (FloraFang style)

The home scene changes with the calendar, or the parent pins one in **Settings** (gear, top left).

| Season | Dates | Scene | Holiday touches |
|---|---|---|---|
| Holiday Workshop | Black Friday to Jan 6 | Pine tree, elf crew, reindeer parade, snow | |
| Snow Day | Jan 7 to Feb | Snowy hills, little pines, snowman | Valentine hearts (Feb 1 to 14) |
| Spring Garden | Mar to May | Blossom tree, petals, butterflies | Easter eggs, Mother's Day tulips |
| Summer | Jun to Aug | Sun, clouds, kite | Father's Day bunting |
| Autumn Harvest | Sep to Thanksgiving | Autumn tree, pumpkins, falling leaves | Jack-o-lanterns, Thanksgiving leaf bunting |

- The elf crew and reindeer appear only in the Holiday Workshop. The rest of the year Pip is off duty in a seasonal outfit (beanie and scarf, flower crown, sun hat, beret).
- The app accent, the main button, background wash and inner screen symbols follow the season.
- Occasion pages carry their own scene: balloons, confetti and cake for birthdays, hearts for anniversaries and weddings, tossed caps for graduations, pastel balloons for baby showers, lights and snow for Christmas. A confetti burst plays on the day.
- The gift box in "Coming up" shows a hint of its event (balloon, heart, sparkle, holly).
- Settings: season (Automatic or any of the five), Holiday touches on or off, and Preview a touch.
- Code: `Support/GiftlySeasons.swift` (dates, Easter and Thanksgiving math), `Views/Atmosphere/SceneProps.swift` (drawing pieces), `SeasonScenes.swift`, `OccasionScene.swift`, `Views/SettingsView.swift`.

