// server.js — Giftly price proxy (SERP API via /request, real-time)
//
// Why this exists: the app must NEVER carry Bright Data credentials. The app
// talks only to this proxy; the proxy holds the token and talks to Bright Data.
//
// Uses Bright Data's REAL-TIME SERP endpoint:
//   POST https://api.brightdata.com/request
//   Authorization: Bearer <API token>
//   body: { zone, url, format: "json", data_format: "parsed" }
// We point `url` at a Google Shopping search (udm=28) so the parsed response
// carries a `shopping` array of products. Returns in ~1-2s — no snapshots,
// no polling (unlike the async dataset scraper, which took 2-5 min).
//
// Run locally:
//   npm install
//   BRIGHTDATA_TOKEN="your-api-token" SERP_ZONE="alex_api1" npm start
//   curl "http://localhost:8787/search?q=lego+race+car&limit=5"

import express from "express";
import crypto from "node:crypto";

const app = express();
// Render sits behind a load balancer; trust it so req.ip is the real client.
app.set("trust proxy", 1);

// ---- Config (env vars, NOT in code) ----------------------------------------
const TOKEN = process.env.BRIGHTDATA_TOKEN || "";   // Bearer API token
const ZONE  = process.env.SERP_ZONE || "alex_api1"; // your SERP API zone name
const PORT  = process.env.PORT || 8787;
const CACHE_TTL_MS = 1000 * 60 * 60 * 24 * 2;       // 2 days

const REQUEST_URL = "https://api.brightdata.com/request";

// ---- Lockdown ---------------------------------------------------------------
// GIFTLY_APP_KEY   shared key the app sends as X-Giftly-Key. When it's set,
//                  requests without it get 401. (A key in an app binary can
//                  be dug out, so the limits below are what actually cap spend.)
// GIFTLY_ADMIN_KEY unlocks /raw and ?debug=1 via X-Giftly-Admin. Unset = off.
// DAILY_CAP        max Bright Data calls per UTC day across everyone (cache
//                  hits are free and don't count). Default 1500.
// Per client (X-Giftly-Device, else IP): 40 searches and 60 store links an hour.
const APP_KEY   = process.env.GIFTLY_APP_KEY || "";
const ADMIN_KEY = process.env.GIFTLY_ADMIN_KEY || "";
const DAILY_CAP = parseInt(process.env.DAILY_CAP || "1500", 10) || 1500;
const HOUR_MS   = 60 * 60 * 1000;
const LIMITS    = { search: 40, resolve: 60 };
const MAX_QUERY = 120;
const MAX_CACHE = 5000;

function safeEqual(a, b) {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

function requireAppKey(req, res, next) {
  if (!APP_KEY) return next();                    // not enforced until the env var is set
  if (safeEqual(req.get("X-Giftly-Key") || "", APP_KEY)) return next();
  return res.status(401).json({ error: "unauthorized" });
}

function isAdmin(req) {
  return Boolean(ADMIN_KEY) && safeEqual(req.get("X-Giftly-Admin") || "", ADMIN_KEY);
}

// Fixed one hour windows per client and route.
const windows = new Map();
function clientId(req) {
  const device = String(req.get("X-Giftly-Device") || "").slice(0, 64);
  return /^[A-Za-z0-9-]{8,64}$/.test(device) ? "d:" + device : "ip:" + req.ip;
}
function rateLimit(kind) {
  return (req, res, next) => {
    const key = kind + "|" + clientId(req);
    const now = Date.now();
    let w = windows.get(key);
    if (!w || now - w.start > HOUR_MS) { w = { start: now, count: 0 }; windows.set(key, w); }
    w.count += 1;
    if (w.count > LIMITS[kind]) {
      res.set("Retry-After", String(Math.ceil((w.start + HOUR_MS - now) / 1000)));
      return res.status(429).json({ error: "slow down" });
    }
    next();
  };
}
setInterval(() => {                               // forget stale windows
  const now = Date.now();
  for (const [k, w] of windows) if (now - w.start > HOUR_MS) windows.delete(k);
}, 10 * 60 * 1000).unref();

// Global daily spend cap on Bright Data calls.
let spend = { day: "", calls: 0 };
function takeBudget() {
  const day = new Date().toISOString().slice(0, 10);
  if (spend.day !== day) spend = { day, calls: 0 };
  if (spend.calls >= DAILY_CAP) return false;
  spend.calls += 1;
  return true;
}

// Bounded caches: drop the oldest entry when full.
function cacheSet(map, key, value) {
  if (map.size >= MAX_CACHE) map.delete(map.keys().next().value);
  map.set(key, value);
}

// ---- Tiny in-memory cache --------------------------------------------------
const cache = new Map();
const cacheKey = (q, limit) => `${q.trim().toLowerCase()}::${limit}`;

// ---- Price parsing + normalizer --------------------------------------------
function parsePriceToCents(raw) {
  if (raw == null) return 0;
  const num = Number(String(raw).replace(/[^0-9.]/g, ""));
  return Number.isFinite(num) ? Math.round(num * 100) : 0;
}

// Retailers we trust / recognize — results from these rank first, and we can
// optionally drop everything else. Matched case-insensitively as a substring
// of the `shop` field (e.g. "Walmart - StarGlow" matches "walmart").
const TRUSTED_RETAILERS = [
  "amazon", "walmart", "target", "best buy", "bestbuy", "lego", "costco",
  "sam's club", "sams club", "kohl's", "kohls", "macy's", "macys",
  "home depot", "the home depot", "lowe's", "lowes", "nordstrom",
  "gamestop", "barnes & noble", "barnes and noble", "nike", "adidas",
  "apple", "wayfair", "newegg", "staples", "michaels", "dick's sporting goods",
  "dicks sporting goods", "ulta", "ulta beauty", "sephora", "chewy",
  "disney", "shopdisney", "disney store", "mattel", "crocs", "rei", "petco",
  "petsmart", "jcpenney", "old navy", "gap", "academy sports", "hobby lobby",
  "pottery barn", "crate & barrel", "williams sonoma", "ikea", "toys r us",
  "toysrus", "dell", "samsung", "microsoft", "nintendo", "playstation",
  "bass pro shops", "cabela's", "foot locker", "under armour", "the north face",
  "lululemon", "kroger", "meijer", "h-e-b", "bj's", "office depot", "belk",
  "dillard's", "bloomingdale's", "saks fifth avenue", "neiman marcus",
  "build-a-bear", "american girl", "fao schwarz", "scholastic",
];

// Whole-word match so "rei" doesn't match "Reiss". Marketplaces and unknown
// resellers (Mercari, eBay, Poshmark, random shops) are NOT on the list and
// are dropped entirely.
function retailerTrustScore(shop) {
  const name = " " + String(shop || "").toLowerCase()
    .replace(/\.com/g, "").replace(/\u2019/g, "'").trim() + " ";
  for (const r of TRUSTED_RETAILERS) {
    if (name.includes(" " + r + " ")) return 1;
  }
  return 0;
}

// Clean up a retailer label: "Walmart - StarGlow" → "Walmart" when the prefix
// is a trusted store (hides the sketchy third-party seller name).
function cleanRetailer(shop) {
  if (!shop) return "Store";
  const dashSplit = shop.split(/\s*[-–]\s*/)[0].trim();
  if (retailerTrustScore(dashSplit) === 1) return dashSplit;
  return shop;
}

// A Google Shopping result → the app's RemoteProduct shape.
// CONFIRMED fields: title, price ("$229.99"), shop, link, rating, image
// (base64 data URI). We PASS THROUGH the image data URI (renders a real
// thumbnail with no extra network call); it's capped so a giant blob can't
// bloat the payload.
function normalize(item) {
  // Prefer the smaller shop image? No — use the product `image`. Cap size so a
  // single huge data URI can't dominate the response (~120KB is plenty for a
  // thumbnail; anything larger we drop to null and show a placeholder).
  let img = item.image || item.image_base64 || null;
  if (typeof img === "string" && img.length > 120_000) img = null;

  return {
    title:        item.title || "Untitled",
    priceCents:   parsePriceToCents(item.price),
    currencyCode: "USD",
    retailer:     cleanRetailer(item.shop || item.merchant || item.source),
    buyURL:       item.link || item.url || "",
    imageURL:     img,
    _trust:       retailerTrustScore(item.shop),   // internal, stripped before send
  };
}

// Pull the product array out of the parsed SERP JSON, tolerant of key names.
function extractShopping(parsed) {
  if (!parsed || typeof parsed !== "object") return [];
  // common shapes: { shopping: [...] } or { shopping_results: [...] }
  return (
    parsed.shopping ||
    parsed.shopping_results ||
    parsed.products ||
    parsed.organic_shopping ||
    []
  );
}

// ---- The one route the app calls -------------------------------------------
app.get("/search", requireAppKey, rateLimit("search"), async (req, res) => {
  const q = String(req.query.q || "").trim();
  const limit = Math.min(parseInt(req.query.limit || "5", 10) || 5, 10);

  if (!q) return res.status(400).json({ error: "missing q" });
  if (q.length > MAX_QUERY) return res.status(400).json({ error: "query too long" });
  if (!TOKEN || !ZONE) {
    return res.status(500).json({ error: "proxy not configured: set BRIGHTDATA_TOKEN and SERP_ZONE" });
  }

  // 1) cache
  const key = cacheKey(q, limit);
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) {
    res.set("X-Giftly-Cache", "hit");
    return res.json(hit.products);
  }
  if (!takeBudget()) return res.status(503).json({ error: "daily limit reached" });

  // 2) real-time SERP request. udm=28 = Google Shopping results surface.
  //    gl=us is REQUIRED — without a shopping country, Google returns the
  //    notice "Please specify shopping country (&gl= parameter)" instead of
  //    products. hl=en keeps labels/currency in US English.
  try {
    const googleURL =
      "https://www.google.com/search?q=" + encodeURIComponent(q) +
      "&udm=28&gl=us&hl=en";

    const bdRes = await fetch(REQUEST_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        zone: ZONE,
        url: googleURL,
        format: "json",
        data_format: "parsed",
      }),
    });

    const text = await bdRes.text();
    if (!bdRes.ok) {
      console.log(`[serp] HTTP ${bdRes.status}: ${text.slice(0, 300)}`);
      return res.status(502).json({ error: `brightdata ${bdRes.status}`, detail: text.slice(0, 300) });
    }

    // The /request response wraps the target's body. With format=json it's
    // usually { status_code, headers, body: <parsed-or-string> }.
    let outer;
    try { outer = JSON.parse(text); }
    catch { return res.status(502).json({ error: "serp response not JSON", detail: text.slice(0, 200) }); }

    let parsed = outer.body ?? outer;
    if (typeof parsed === "string") {
      // Bright Data sometimes returns a PLAIN-TEXT NOTICE instead of product
      // JSON: rate-limit cooldowns, "specify shopping country", block pages,
      // etc. Detect that and surface a clear retry message instead of a
      // misleading empty list.
      const trimmed = parsed.trim();
      const looksLikeJSON = trimmed.startsWith("{") || trimmed.startsWith("[");
      if (!looksLikeJSON) {
        console.log(`[serp] notice instead of products: ${trimmed.slice(0, 160)}`);
        const isRateLimit = /recently failed|try again|minimum of \d+ seconds/i.test(trimmed);
        return res.status(503).json({
          error: isRateLimit
            ? "This search was tried too recently. Wait about a minute and try again."
            : "The price service returned a notice, not products.",
          detail: trimmed.slice(0, 200),
          retryable: isRateLimit,
        });
      }
      try { parsed = JSON.parse(parsed); } catch { /* leave as-is */ }
    }

    const items = extractShopping(parsed);

    // Normalize everything, keep only priced results.
    const all = items.map(normalize).filter(p => p.priceCents > 0);

    // Reputable stores ONLY (Target, Walmart, Amazon, Best Buy...). No
    // backfill with marketplaces or unknown resellers: an empty list is
    // better than a Mercari listing, and the app widens the search itself.
    const ranked = all.filter(p => p._trust === 1).slice(0, limit);

    // Strip the internal _trust field before sending to the app.
    const products = ranked.map(({ _trust, ...rest }) => rest);

    // Debug: if we got a 200 but zero products, log the shape so we can map it.
    if (products.length === 0) {
      console.log(`[serp] 0 products. top-level keys: ${Object.keys(parsed || {}).join(", ")}`);
    }

    cacheSet(cache, key, { at: Date.now(), products });
    res.set("X-Giftly-Cache", "miss");
    return res.json(products);
  } catch (err) {
    return res.status(502).json({ error: "proxy fetch failed", detail: String(err).slice(0, 300) });
  }
});

// ---- Store link resolver ----------------------------------------------------
// Google Shopping results only carry Google's own product page. When the
// parent taps Buy, the app asks here for the store's real product page:
// fetch Google's product page through Bright Data, collect every outbound
// link, and return the first one on the STORE'S OWN DOMAIN (lego.com for
// "LEGO.com", walmart.com for "Walmart"). Anything else returns url: null and
// the app falls back to searching that store's site for the exact title.
//   curl "http://localhost:8787/resolve?u=<google product link>&store=LEGO.com&debug=1"
const resolveCache = new Map();

function pickMerchantLink(html, store) {
  const text = String(html)
    .replace(/\\u003d/g, "=").replace(/\\u0026/g, "&")
    .replace(/&amp;/g, "&").replace(/\\\//g, "/");
  const candidates = new Set();
  // Google redirect wrappers: /url?q=<target>&..., ?adurl=, ?url=
  for (const m of text.matchAll(/[?&](?:q|url|adurl)=(https?(?:%3A%2F%2F|:\/\/)[^&"'\s<>]+)/gi)) {
    try { candidates.add(decodeURIComponent(m[1])); } catch { /* skip */ }
  }
  for (const m of text.matchAll(/https?:\/\/[^"'\s<>\\)]+/g)) candidates.add(m[0]);

  const blocked = /(google\.|gstatic\.|googleusercontent\.|googleapis\.|youtube\.|ggpht\.|schema\.org|w3\.org|doubleclick\.|googlesyndication\.|googleadservices\.)/i;
  const links = [...candidates].filter((c) => {
    try {
      const host = new URL(c).hostname;
      return !blocked.test(host) && !/\.(png|jpe?g|gif|webp|svg|js|css|ico)(\?|$)/i.test(c);
    } catch { return false; }
  });

  const want = store.replace(/com$/, "");
  const onStore = want
    ? links.filter((c) => new URL(c).hostname.toLowerCase().replace(/[^a-z0-9]/g, "").includes(want))
    : [];
  // Prefer a deep link (a product page) over the store's home page.
  onStore.sort((a, b) => new URL(b).pathname.length - new URL(a).pathname.length);
  return { url: onStore[0] || null, links };
}

app.get("/resolve", requireAppKey, rateLimit("resolve"), async (req, res) => {
  const u = String(req.query.u || "");
  const store = String(req.query.store || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  const debug = req.query.debug === "1" && isAdmin(req);

  if (u.length > 2048) return res.status(400).json({ url: null, error: "link too long" });

  if (!/^https:\/\/www\.google\.[a-z.]+\/search\?/i.test(u)) {
    return res.status(400).json({ url: null, error: "not a google shopping link" });
  }
  if (!TOKEN || !ZONE) return res.status(500).json({ url: null, error: "proxy not configured" });

  const key = `${u}::${store}`;
  const hit = resolveCache.get(key);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS && !debug) {
    res.set("X-Giftly-Cache", "hit");
    return res.json({ url: hit.url });
  }
  if (!takeBudget()) return res.status(503).json({ url: null, error: "daily limit reached" });

  try {
    const bdRes = await fetch(REQUEST_URL, {
      method: "POST",
      headers: { "Authorization": `Bearer ${TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ zone: ZONE, url: u, format: "raw" }),
    });
    const html = await bdRes.text();
    if (!bdRes.ok) {
      console.log(`[resolve] HTTP ${bdRes.status}: ${html.slice(0, 200)}`);
      return res.status(502).json({ url: null, error: `brightdata ${bdRes.status}` });
    }
    const { url, links } = pickMerchantLink(html, store);
    cacheSet(resolveCache, key, { at: Date.now(), url });
    if (debug) {
      return res.json({ url, store, htmlBytes: html.length, outboundLinks: links.length, sample: links.slice(0, 15) });
    }
    return res.json({ url });
  } catch (err) {
    return res.status(502).json({ url: null, error: String(err).slice(0, 200) });
  }
});

app.get("/health", (req, res) => {
  const base = { ok: true, configured: Boolean(TOKEN && ZONE), locked: Boolean(APP_KEY) };
  if (!isAdmin(req)) return res.json(base);
  return res.json({ ...base, zone: ZONE, spendToday: spend, dailyCap: DAILY_CAP,
                    cached: cache.size, clients: windows.size });
});

// Debug: run a live SERP call and return the RAW parsed shape (first 2 items +
// their keys) so we can map product fields exactly. Not used by the app.
// Admin only (X-Giftly-Admin header).
//   curl "http://localhost:8787/raw?q=lego+race+car"
app.get("/raw", async (req, res) => {
  if (!isAdmin(req)) return res.status(404).json({ error: "not found" });
  const q = String(req.query.q || "lego race car").trim().slice(0, MAX_QUERY);
  try {
    const googleURL = "https://www.google.com/search?q=" + encodeURIComponent(q) + "&udm=28&gl=us&hl=en";
    const bdRes = await fetch(REQUEST_URL, {
      method: "POST",
      headers: { "Authorization": `Bearer ${TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ zone: ZONE, url: googleURL, format: "json", data_format: "parsed" }),
    });
    const text = await bdRes.text();
    let outer; try { outer = JSON.parse(text); } catch { outer = null; }

    let body = outer && outer.body;
    if (typeof body === "string") { try { body = JSON.parse(body); } catch {} }

    const arrayKeys = body && typeof body === "object"
      ? Object.keys(body).filter(k => Array.isArray(body[k]) && body[k].length && typeof body[k][0] === "object")
      : [];
    const report = {};
    for (const k of arrayKeys) {
      report[k] = { count: body[k].length, firstItemKeys: Object.keys(body[k][0]), firstItem: body[k][0] };
    }

    return res.json({
      httpStatus: bdRes.status,
      bodyTopLevelKeys: body && typeof body === "object" ? Object.keys(body) : null,
      bodyHeadIfString: typeof body === "string" ? body.slice(0, 400) : null,
      arrayFields: arrayKeys,
      arrayFieldDetails: report,
    });
  } catch (err) {
    return res.status(502).json({ error: String(err).slice(0, 300) });
  }
});

app.listen(PORT, () => {
  console.log(`Giftly price proxy (SERP /request) on http://localhost:${PORT}`);
  console.log(`Configured: ${Boolean(TOKEN && ZONE)} (token ${TOKEN ? "set" : "MISSING"}, zone ${ZONE})`);
  console.log(`App key: ${APP_KEY ? "enforced" : "NOT SET (open)"}, daily cap ${DAILY_CAP}`);
});
