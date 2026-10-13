# Pip: Gift Lists

**Every wish, every occasion, with real prices.** Pip keeps one calm place for what the people you shop for actually want: birthdays, Christmas, anniversaries and everything in between. Type a wish in plain words and Pip finds the real product, at a trusted store, with a live price and a link that opens the store. Pip, a little gift box buddy (an elf at Christmas), and a living seasonal background make it feel warm and fun instead of like a spreadsheet.

| | |
|---|---|
| App Store name | **Pip: Gift Lists** |
| Home screen name | **Pip** (`CFBundleDisplayName`) |
| Bundle ID | `com.aramirez.Giftly` (original project name; users never see it) |
| iCloud container | `iCloud.com.aramirez.Giftly` |
| Minimum iOS | 27 |
| Target launch | Black Friday 2026 (v1), January 2027 (v2) |

> © 2026 Alexander Ramirez (Ramirez Labs). All rights reserved. See `LICENSE`.

---

## Status at a glance

| Area | State |
|---|---|
| Parent app (people, occasions, wishes, prices, budgets, bought) | ✅ Done |
| Live prices through the locked proxy | ✅ Done, deployed on Render |
| Foundation Models features (all on device) | ✅ Done |
| Seasons, scenes, Pip (gift box buddy + Christmas elf) | ✅ Done |
| Scan a paper list, read a texted list | ✅ Done |
| iCloud sync (CloudKit, private database) | ✅ Done, schema deployed to Production |
| App icon (Pip), intro screens, Settings | ✅ Done |
| TestFlight | 🔜 Archive and upload build 2 |
| Plus purchase (StoreKit 2), reminders, App Store listing | ⏳ Before App Store launch |
| Kid mode, family sharing, price alerts, widget | 🗓️ v2 (January) |

---

## What's built (v1)

### People and profiles
- People with a photo, relationship and an age group (child, teen, adult).
- **The profile form changes with age.** Child: grade, favorite characters or shows, toy brands, game systems, kids sizes. Teen: school or team, shows, games and artists, consoles and devices. Adult: work, favorite stores, devices. A real birth year fills in the age group automatically (the year isn't stored).
- Interests, favorite colors, stores or brands, characters, devices, sizes, what they already have, what they don't like. Everything feeds Pip's gift ideas.
- **Pip's ideas while you type:** after a pause in "What they love", Pip suggests gift ideas on device (free, no search limit). Tap the ones you like and they're added and priced on Save.
- Birthday and Christmas switches create those occasions for you.
- **Import from Contacts** (system picker, no permission prompt): name, photo, birthday, anniversaries, job.
- **Swipe left to delete** a person (with confirmation; also on long press).

### Occasions
- 28 occasion types in groups: Everyday, Holidays (Christmas, Hanukkah, Valentine's, Mother's Day, Father's Day, Easter, Eid, Diwali, Lunar New Year), Milestones (graduation, engagement, wedding, showers, baptism, quinceañera, housewarming, new job, retirement), Thanks and care (teacher gift, Secret Santa, thank you, get well).
- Holidays with a known date fill it in; the title follows the type until you type your own.
- Budgets with a running total, bought tracking, pasted invite links (Apple Invites has no public API).
- **Coming up** on home, sorted by date, each with a live gift box that wiggles as the day nears and pops open on the day, plus a hint of the event (balloon, heart, sparkle, holly).
- **Past events** sit behind one row on home: grouped by year with what was bought and spent.

### Adding gifts
- **Add a gift idea:** one screen. "+ New" (first chip) opens a full Add someone sheet; then pick the occasion and type. Stays open for a whole list.
- **Scan a paper list:** document camera or a photo. Vision reads it on device (handwriting too), Foundation Models turns it into clean wishes and finds the child's name, the parent reviews, then each wish is priced in turn.
- **From a text message:** pick screenshots of the conversation (left bubbles are them, right are you; times, receipts, status bar and keyboard are dropped) or paste a copied message. Pip keeps what they asked for and skips the chit chat. The thread's contact name picks the person.

### Prices and results
- Search ladder (exact, broader, the parent's own words) with a retry; never a silent empty result. Clear notes for no match, offline, limits, plus Pip's alternative searches.
- **Trusted stores only** (Target, Walmart, Amazon, Best Buy and about 70 more). Marketplaces and resellers are dropped in the app and the proxy.
- **Budget aware pick:** the best match that fits what's left, then up to six varied options across prices and stores.
- **Bare device names mean the device:** "PS5", "Xbox", "Switch", "iPad" search for the console or device and skip accessories and games (`ProductIntent.swift`).
- Tap any result to open it; **Buy opens the store's own product page** (resolved through the proxy, with fallbacks).

### Pip and the seasons
- **Pip** is a gift box buddy most of the year and the head elf from Black Friday to January 6. He breathes, blinks, wiggles his bow, hops while searching, reads lists, and cheers (tap him on home). Drawn entirely in code.

| Season | Dates | Home scene | Pip | Holiday touches |
|---|---|---|---|---|
| Holiday Workshop | Black Friday to Jan 6 | Pine tree, elf crew, reindeer parade, snow | Elf | |
| Snow Day | Jan 7 to Feb | Snowy hills, pines, snowman | Blue box, beanie, scarf | Valentine hearts (Feb 1 to 14) |
| Spring Garden | Mar to May | Blossom tree, petals, butterflies | Pink box, flower crown | Easter eggs, Mother's Day tulips |
| Summer | Jun to Aug | Sun, clouds, kite | Teal striped box, sunglasses | Father's Day bunting |
| Autumn Harvest | Sep to Thanksgiving | Autumn tree, pumpkins, leaves | Orange plaid box, leaf, scarf | Jack-o-lanterns, Thanksgiving leaves |

- Occasion pages have their own scene (balloons and cake, hearts, tossed caps, petals, lights and snow) and a confetti burst on the day.
- Text and buttons keep one readable brand color all year; the season lives in the backgrounds.
- Cards are Liquid Glass (tinted for readability) so the scene shows through.
- **Settings:** season (Automatic or any of five), holiday touches on or off, preview a touch, and "How Pip works" (replays the intro).

### Intro
Five swipeable pages with live illustrations: welcome, say it like they said it, every date in one list, scan their list, private by design.

### On device intelligence (Foundation Models)
All on device, all with plain fallbacks for phones without Apple Intelligence, all output scrubbed of dashes:
- wish details (brand, color, size, age, must haves) and the search query
- ranking results so the pick lands on the best match, with a reason
- gift ideas from the whole profile, budget left and what's already listed
- card notes in three tones
- reading scanned lists and texted lists
- Pip's home line: built from the real data first, then reworded in his voice and checked so no name, number or day word drifts

---

## Architecture

```
Data        SwiftData models, synced with CloudKit (private database)
Brain       GiftIntelligence: on device Foundation Models. No network.
Prices      PriceService + WishFetcher -> the price proxy (the ONLY networked layer)
Design      GiftlyTheme (palette, glass cards, buttons) + GiftlyBackground
Atmosphere  Clock driven scenes (SceneProps, SeasonScenes, OccasionScene, WinterScene)
Pip         BoxBuddy (most of the year) and ElfView (Holiday Workshop)
```

**Privacy promise:** profiles stay on the phone and in the parent's own iCloud. No accounts, no ads. The only thing that leaves the phone is an anonymous product search like "lego race car", plus a random install ID used for rate limiting.

### iCloud sync
- `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.aramirez.Giftly"))`. If CloudKit can't start, the app falls back to a local store instead of crashing.
- Models follow the CloudKit rules: defaults on every property, optional relationships, every relationship has an inverse (`Wish.chosenMatch` is computed from `ProductMatch.isChosen` for that reason).
- **After changing a model:** run a Debug build (add the launch argument `-initCloudKitSchema` and bump `CloudSchema.version`, or just save a record that uses the new field), confirm in the CloudKit Console Development environment, then **Deploy Schema Changes** to Production before the next TestFlight build. CloudKit only allows adding fields, never renaming or removing.

---

## The price proxy (`price-proxy/`)

Foundation Models has no internet, so live prices come from Bright Data's SERP API (Google Shopping, about 1 to 2 seconds) through a small Node proxy on Render. The Bright Data token never ships in the app.

| Route | What it does |
|---|---|
| `GET /search?q=&limit=` | Google Shopping results, trusted stores only, normalized to `{title, priceCents, currencyCode, retailer, buyURL, imageURL}`, cached 2 days |
| `GET /resolve?u=&store=` | Turns a Google product link into the store's own product page, cached |
| `GET /health` | Public: ok, configured, locked. With the admin key: spend today, cap, cache size |
| `GET /raw` | Admin only debug of the raw SERP shape |

**Lockdown** (env vars on Render):

| Env var | Purpose |
|---|---|
| `BRIGHTDATA_TOKEN` | Bright Data API token (secret) |
| `SERP_ZONE` | Bright Data zone name |
| `GIFTLY_APP_KEY` | Must match `GiftlySecrets.appKey` in the app; requests without it get 401 |
| `GIFTLY_ADMIN_KEY` | Unlocks `/raw`, `?debug=1` and spend details (header `X-Giftly-Admin`) |
| `DAILY_CAP` | Max Bright Data calls per day, everyone combined (default 1500) |

Also built in: 40 searches and 60 store links per device per hour, query length limits, bounded caches. The app shows friendly notes when a limit is hit.

```bash
cd price-proxy && npm install
BRIGHTDATA_TOKEN=... SERP_ZONE=... GIFTLY_APP_KEY=... npm start
curl -H "X-Giftly-Key: ..." "http://localhost:8787/search?q=lego&limit=5"
```

---

## Setting up a fresh clone

1. Open `Giftly.xcodeproj` (file system synchronized groups pick up every file in `Giftly/`).
2. Create `Giftly/GiftlySource/Support/GiftlySecrets.swift` (git ignored):
   ```swift
   enum GiftlySecrets { static let appKey = "<same value as GIFTLY_APP_KEY on Render>" }
   ```
3. Signing & Capabilities: iCloud (CloudKit, container `iCloud.com.aramirez.Giftly`), Push Notifications, Background Modes (Remote notifications).
4. Build and run. Debug and TestFlight builds unlock Plus automatically.

**Info.plist** holds `CFBundleDisplayName` (Pip), `NSCameraUsageDescription`, `NSFaceIDUsageDescription`, `ITSAppUsesNonExemptEncryption = NO`, and the remote notification background mode. Xcode can rewrite this file when capabilities change, so check these keys are still there before archiving.

---

## Still to do for v1 (before the App Store)

**TestFlight (now)**
- [ ] Build in Xcode and fix any compile errors
- [ ] Set Build to 2, archive, upload, submit for Beta App Review
- [ ] Invite the 5 testers; collect feedback through TestFlight screenshots
- [ ] Rename the app record in App Store Connect to **Pip: Gift Lists**
- [ ] Upgrade Render off the free plan (it sleeps when idle, so the first search can take close to a minute)

**Launch**
- [ ] **Plus with StoreKit 2:** product in App Store Connect, purchase and restore, a paywall, entitlement checks (`Entitlements` is a stub today). Decide whether Plus keeps "unlimited people" (the 3 person free limit isn't enforced yet) and "price drop alerts" (not built)
- [ ] **Reminders:** local notifications before occasions ("Mom's birthday is in 2 weeks, 1 gift not bought")
- [ ] App Store listing: screenshots, description, keywords, privacy policy on ramirezlabs.app, privacy label (search text goes to our server), review notes
- [ ] Test sync between two real devices
- [ ] Accessibility pass: VoiceOver labels, Dynamic Type on the custom cards
- [ ] Unit tests: season and holiday dates, `ProductIntent`, the budget lineup, list and text parsing

---

## v2 (January 2027)

- **Kid mode:** the kid side is built and switched off (`AppSession.kidModeEnabled = false`). Turn it on with the grown-ups gate (birth year, then Face ID), consider a separate local only store for kids' wishes, and revisit COPPA and Kids Category rules
- **Share a list** with a partner or grandparent through CloudKit sharing (`CKShare`), with "bought" hidden from the recipient
- **Price drop alerts** for picked gifts (background refresh plus the proxy)
- **Home screen widget:** countdown to the next occasion, in Pip's seasonal look
- **Share extension:** send a screenshot or a product link straight from Messages, Safari or Photos into Pip
- **App Attest** on the proxy so only the real app can spend searches
- Affiliate links (Amazon Associates and others) to offset search costs
- A softer face for the Christmas elf crew, and more Pip poses and holiday outfits

---

## Project layout

```
Giftly/
├── README.md, LICENSE
├── Giftly.xcodeproj
├── Giftly/
│   ├── Info.plist, Giftly.entitlements, Assets.xcassets (AppIcon: Pip, light/dark/tinted)
│   └── GiftlySource/
│       ├── App/         GiftlyApp (CloudKit container, local fallback)
│       ├── Models/      Models (Person, Occasion, Wish, ProductMatch, AgeProfile), AppSession
│       ├── Services/    GiftIntelligence, WishFetcher, PriceService, StoreLinks, ProductIntent,
│       │                ListScanner, ContactImport, ParentalGate, Entitlements
│       ├── Support/     GiftlyTheme, GiftlySeasons, CloudSchema, GiftlyConfig,
│       │                GiftlySecrets (git ignored), WorkshopTheme, Color+Hex
│       └── Views/       ParentHome, Person, Occasion, Wish, ScanList, Settings, PastEvents,
│           │            SwipeToDelete, Root, ProductThumbnail
│           ├── Atmosphere/  GiftlyAtmosphereView, SceneProps, SeasonScenes, OccasionScene,
│           │                WinterScene, GiftlyBackground, AtmosphereEngine
│           ├── Workshop/    BoxBuddy, ElfView, ElfHandoffView, GiftBoxMark, WorkshopWelcomeView (intro)
│           └── Kid/         KidHomeView (v2)
└── price-proxy/         server.js, package.json, render.yaml, README
```

Full builds happen in Xcode (SwiftData macros don't run from the command line).
