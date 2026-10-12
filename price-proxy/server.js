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

const app = express();

// ---- Config (env vars, NOT in code) ----------------------------------------
const TOKEN = process.env.BRIGHTDATA_TOKEN || "";   // Bearer API token
const ZONE  = process.env.SERP_ZONE || "alex_api1"; // your SERP API zone name
const PORT  = process.env.PORT || 8787;
const CACHE_TTL_MS = 1000 * 60 * 60 * 24 * 2;       // 2 days

const REQUEST_URL = "https://api.brightdata.com/request";

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
  "amazon", "walmart", "target", "best buy", "bestbuy", "lego",
  "costco", "kohl", "macy", "the home depot", "home depot", "lowe",
  "etsy", "nordstrom", "gamestop", "barnes", "nike", "adidas",
  "apple", "wayfair", "newegg", "sam's club", "sams club", "staples",
  "michaels", "dick's", "dicks sporting", "ulta", "sephora", "chewy",
  "disney", "mattel", "hasbro", "crocs", "rei", "petco", "petsmart",
];

function retailerTrustScore(shop) {
  const s = (shop || "").toLowerCase();
  for (const r of TRUSTED_RETAILERS) {
    if (s.includes(r)) return 1;   // trusted
  }
  // Marketplace third-party sellers often look like "Walmart - happy baby194113"
  // or random vendor names — rank them lower.
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
app.get("/search", async (req, res) => {
  const q = String(req.query.q || "").trim();
  const limit = Math.min(parseInt(req.query.limit || "5", 10) || 5, 10);

  if (!q) return res.status(400).json({ error: "missing q" });
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

    // Prefer trusted retailers: show those first, backfill with others up to
    // `limit`. (To show ONLY trusted retailers, drop the backfill line.)
    const trusted = all.filter(p => p._trust === 1);
    const others  = all.filter(p => p._trust !== 1);
    const ranked  = [...trusted, ...others].slice(0, limit);

    // Strip the internal _trust field before sending to the app.
    const products = ranked.map(({ _trust, ...rest }) => rest);

    // Debug: if we got a 200 but zero products, log the shape so we can map it.
    if (products.length === 0) {
      console.log(`[serp] 0 products. top-level keys: ${Object.keys(parsed || {}).join(", ")}`);
    }

    cache.set(key, { at: Date.now(), products });
    res.set("X-Giftly-Cache", "miss");
    return res.json(products);
  } catch (err) {
    return res.status(502).json({ error: "proxy fetch failed", detail: String(err).slice(0, 300) });
  }
});

app.get("/health", (_req, res) =>
  res.json({ ok: true, configured: Boolean(TOKEN && ZONE), zone: ZONE, mode: "serp-request" })
);

// Debug: run a live SERP call and return the RAW parsed shape (first 2 items +
// their keys) so we can map product fields exactly. Not used by the app.
//   curl "http://localhost:8787/raw?q=lego+race+car"
app.get("/raw", async (req, res) => {
  const q = String(req.query.q || "lego race car").trim();
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
});
