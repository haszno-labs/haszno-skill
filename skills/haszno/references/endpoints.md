# Haszno — API Endpoints Accessible to Per-Shop Bearer Tokens

> Generated from the capability map (`agent-capability-map.md`, source: Webu-PRO/arfutar origin/main).
> Every endpoint here passes `isPublicPath` in `api/src/vercel.ts` and authenticates
> via `validateBearerToken` or `requireAuth` (live DB lookup; revocation + expiry checked).
> The `/api/v1/` prefix is canonical; `/api/` is equivalent but deprecated.

---

## Identity

### `GET /api/v1/auth/me`

Recommended connectivity probe. Returns the authenticated user's identity.

**Auth:** any Bearer token (read or write scope)  
**Response:** `{ id, email, name, shopId, shopName, founderSince, role, tokenScope }`  
`tokenScope` is `"read"` or `"write"` — check this before submitting proposals.

---

### `POST /api/v1/auth/tokens/revoke-current`

Revoke the current Bearer token.

**Auth:** any Bearer token  
**Response:** `{ ok: true }`

---

## Agent API (`/api/v1/agent/*`)

All four routes require a Bearer token. Session cookies are **not accepted** here.
Every response is scoped to the token's `shopId` — data from other shops is never returned.

### `GET /api/v1/agent/products`

List the shop's products with current margins and the recommended price from the pricing engine.

**Auth:** read-scope (or write-scope) Bearer  
**Response:** array of:
```jsonc
{
  "id": 42,
  "sku": "NET-ABC-123",          // "NET-" prefix for catalogue imports
  "name": "Párásító deluxe",
  "listed": true,
  "priceGross": 8990,            // current shop price (gross HUF)
  "stock": 5,
  "supplierName": "Demo Supplier",
  "current": {
    "marginNet": 420,
    "marginPct": 12.4            // current margin percentage
  },
  "recommended": {
    "priceGross": 8490,          // engine-recommended price
    "floorGross": 7190           // absolute minimum — never submit below this
  }
}
```

**Pagination:** none — all products returned in one call.  
**Note (2026-11-14):** per-shop SKU uniqueness means multiple shops can now import
the same supplier SKU (each with their own product row). `sku` = `NET-<supplierSku>`
for catalogue items.

---

### `GET /api/v1/agent/orders`

List the most recent orders.

**Auth:** read-scope (or write-scope) Bearer  
**Limit:** always last 20 orders — no pagination parameters  
**Response:** array of:
```jsonc
{
  "id": 1,
  "externalId": "SHOP-123",
  "customerName": "Kovács Béla",
  "status": "forwarded",           // received | forwarded | shipped | error
  "totalGross": 15990,
  "createdAt": "2026-11-14T10:00:00Z",
  "items": [
    { "orderId": 1, "qty": 1, "priceGross": 15990, "name": "Párásító deluxe", "sku": "NET-ABC-123" }
  ]
}
```

---

### `GET /api/v1/agent/proposals`

List pending (or all) price proposals submitted by the pricing engine or by agents.

**Auth:** read-scope (or write-scope) Bearer  
**Response:** array of:
```jsonc
{
  "id": 7,
  "productId": 42,
  "productName": "Párásító deluxe",
  "productSku": "NET-ABC-123",
  "oldPriceGross": 8990,
  "proposedPriceGross": 8490,
  "reason": "piaci minimumhoz igazítás",
  "status": "pending",
  "createdAt": "2026-11-14T10:00:00Z"
}
```

---

### `POST /api/v1/agent/proposals`

Submit a new agent-generated price proposal.

**Auth:** write-scope Bearer  
**Content-Type:** `application/json` (required)  
**Request body:**
```jsonc
{
  "productId": 42,                  // integer, from agent/products
  "proposedPriceGross": 8490,       // integer ≥ 1; must be ≥ recommended.floorGross
  "reason": "piaci minimumhoz igazítás",  // string 1–500 chars
  "nonce": "2026-11-14T10:00:00Z-prod42"  // string 1–128 chars; unique per request
}
```

**Response (201):** `{ id, status: "pending", createdAt }`

**The proposal is always `status: "pending"`.** No agent credential can change it.
A human must approve it at haszno.com/app/javaslatok.

**Price floor rule:**
- `floorGross = max(costNet × (1+VAT), costNet / (1-minMarginPct) × (1+VAT))`, rounded up to `…90 Ft`
- Submitting below the floor → `422 "A javasolt ár … a minimális haszonhoz tartozó árszint alatt van."`

**Nonce deduplication:**
- Stored in a Postgres partial unique index; a second request with the same nonce → `409`
- 409 is NOT a re-confirmation of the original — retrieve the original via `GET /api/v1/agent/proposals`

**Error codes:**
| Status | Code | Meaning |
|---|---|---|
| 201 | — | Created |
| 400 | `invalid_request` | Missing/invalid body fields or missing Content-Type |
| 403 | `forbidden` | read-scope token used on POST, or Bearer-on-approve |
| 404 | `not_found` | productId not found (or belongs to another shop) |
| 409 | `conflict` | duplicate nonce |
| 422 | `unprocessable` | below price floor |
| 429 | `rate_limited` | too many failed Bearer attempts |

---

## Hosted MCP (`/api/v1/mcp`)

### `POST /api/v1/mcp`

Stateless Streamable HTTP MCP endpoint. Wraps agent routes and shop routes.

**Auth:** Bearer token (same `validateBearerToken` as agent routes)  
**Content-Type:** `application/json`  
**Max batch:** 10 JSON-RPC messages per HTTP request  
**Body size limit:** 1 MB global; image uploads via tools ≤ 700 KB  
**Server info:** `{ name: "haszno", version: "0.1.0" }`  
**Public URL:** `https://haszno.com/api/v1/mcp`

**Tool roster via this endpoint:**

The endpoint calls `registerShopTools` from `@haszno/mcp/lib` (source: `api/src/mcp/routes.ts:144`).
The `@haszno/mcp/lib` package is not present in this reference checkout, so the exact list of tool
names registered cannot be verified here. The capability map (§3c) confirms that:

- Tools that call agent routes (`/api/v1/agent/*`) enforce their scope rules via `api/src/agent/routes.ts` guards.
- Tools that call shop routes (`/api/v1/shop/*`) enforce scope via `requireAuth`.
- Tools that call routes blocked for per-shop tokens (approval, legacy-key-only paths) will return 403.

**To discover the live tool roster**, issue a `tools/list` JSON-RPC call against the endpoint after authenticating:
```json
{ "jsonrpc": "2.0", "method": "tools/list", "id": 1 }
```

> **Note (unverified):** the function name `registerShopTools` and the open question from the implementer
> suggest the registered set may be `haszno_shop_*` only. Tool names like `haszno_proposals_list`,
> `haszno_proposals_propose`, `haszno_ping`, and `haszno_account_configure` may or may not be registered —
> confirm with the `@haszno/mcp/lib` maintainer or via `tools/list` before relying on them.

Tools that require a legacy key will return 403 when called through this endpoint with a shop token.

---

## Marketplace (`/api/v1/shop/*`)

The entire `/api/shop/` subtree passes `isPublicPath` unconditionally; inside each handler
`requireAuth` accepts both Bearer tokens and session cookies. Scope rule applies: `read`
tokens can call GET routes; `write` tokens can call all methods.

**Seller gating (`kereskedo` required for some writes):**
`PUT /api/v1/shop/partner/syndications/:adId` and partner-product catalogue push require
`sellerType = "kereskedo"` (registered business). If the shop is `maganszemely` → `403`
with `code: "seller_type_required"`.

### Key endpoints accessible to per-shop Bearer tokens

| Method | Path | Scope | Description |
|---|---|---|---|
| GET | `/api/v1/shop/my/ads` | read | List own ads |
| GET | `/api/v1/shop/my/ads/:id` | read | Single ad detail |
| POST | `/api/v1/shop/ads` | write | Create a new ad |
| PUT | `/api/v1/shop/ads/:id` | write | Update ad (now also accepts `estateCondition` for real-estate categories) |
| POST | `/api/v1/shop/ads/:id/status` | write | Change ad status (`aktiv` / `szunetel` / `torolve`) |
| POST | `/api/v1/shop/ads/:id/sold` | write | Mark ad as sold (irreversible) |
| GET | `/api/v1/shop/my/inquiries` | read | List inbound inquiries |
| POST | `/api/v1/shop/my/inquiries/:id/reply` | write | Reply to inquiry |
| POST | `/api/v1/shop/my/inquiries/:id/read` | write | Mark inquiry as read |
| DELETE | `/api/v1/shop/my/inquiries/:id` | write | Delete inquiry |
| GET | `/api/v1/shop/my/favorites` | read | Saved favorites |
| PUT | `/api/v1/shop/ads/:id/favorite` | write | Add favorite |
| DELETE | `/api/v1/shop/ads/:id/favorite` | write | Remove favorite |
| PUT | `/api/v1/shop/ads/:id/watch` | write | Enable price-drop watch |
| DELETE | `/api/v1/shop/ads/:id/watch` | write | Disable price-drop watch |
| GET | `/api/v1/shop/my/moderation` | read | Moderation decisions |
| POST | `/api/v1/shop/my/moderation/:id/appeal` | write | Appeal a moderation decision |
| GET | `/api/v1/shop/partner/profile` | read | Partner profile |
| PUT | `/api/v1/shop/partner/profile` | write | Update partner profile |
| GET | `/api/v1/shop/partner/syndications` | read | List syndicated partner ads |
| PUT | `/api/v1/shop/partner/syndications/:adId` | write + kereskedo | Upsert syndication |
| DELETE | `/api/v1/shop/partner/syndications/:adId` | write | Remove syndication |

**Public (no auth):**
- `GET /api/v1/shop/partner/:refCode/feed.json` — partner product feed (JSON)
- `GET /api/v1/shop/partner/:refCode/feed.xml` — partner product feed (Google Merchant XML)

---

## What is NOT accessible to per-shop Bearer tokens

| Endpoint group | Reason |
|---|---|
| `/api/v1/catalogue/products`, `/api/v1/import-list/*` | `isSessionAllowedPath` — outer gate rejects Bearer |
| `/api/v1/billing/*`, `/api/v1/chat/*` | `isSessionAllowedPath` |
| `/api/v1/team/*`, `/api/v1/reseller-pricing/*` | `isSessionAllowedPath` |
| `/api/v1/webshop/*`, `/api/v1/connect/stores/*` | `isSessionAllowedPath` |
| `/api/v1/launcher/jobs/*` | `isSessionAllowedPath` |
| `POST /api/v1/proposals/approve|reject|rollback` | `rejectBearerOnApproval` middleware — permanent |
| `/api/v1/rules/*`, `/api/v1/feeds/*` | HTTP Basic wall on self-hosted `x-api-key` guard |
| Token management (`POST/GET/DELETE /api/v1/auth/tokens`) | Handlers call `getSessionOrThrow` only |
| GDPR (`GET /api/v1/auth/me/export`, `DELETE /api/v1/auth/me`) | Session-only by design |
| Peers, blog, connections, signals, trends, academy | HTTP Basic wall or no agent route registered |
