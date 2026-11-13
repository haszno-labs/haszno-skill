# Haszno MCP Tool Reference

All tools are prefixed `haszno_`. Read-only tools can be called freely.
Every write tool requires a `confirm: true` argument — the agent must not pass
`true` until the user has acknowledged what will happen.

---

## Shop / marketplace (`haszno_shop_*`)

The Haszno Shop is a free P2C/P2P classified-ads marketplace. No plans, no fees for
using the Shop. Golden rules: (a) show the user every draft before writing; (b) reserving
is not paying — payment and handover are always between buyer and seller; (c) never invent
attributes, prices, or photos; (d) never put phone/email in ad text — use `contactPhone`.

---

### `haszno_shop_list_categories` _(read-only)_

List ad categories and subcategories with their `key` values (required for creating ads).

**Returns:** `{ categories: [{ key, name, subcategories: [{key, name, requiredAttrs}] }] }`

---

### `haszno_shop_search_ads` _(read-only)_

Search active ads.

**Parameters:**
- `q` _(string, optional)_ — free-text query
- `category` _(string, optional)_ — category key
- `subcategory` _(string, optional)_
- `county` _(string, optional)_ — Hungarian county name
- `minPrice` _(integer, optional)_ — HUF gross
- `maxPrice` _(integer, optional)_ — HUF gross
- `condition` _(`"uj" | "ujszerű" | "hasznalt" | "hibas"`, optional)_
- `reserved` _(boolean, optional)_ — include reserved ads (default false)
- `page` _(integer, optional, default 1)_

**Returns:** array of `Ad` with `id, title, priceGross, negotiable, condition, county, city,
image, status, reserved, createdAt`

---

### `haszno_shop_get_ad` _(read-only)_

Full ad detail. Contact fields (`sellerPhone`, `sellerEmail`) are non-null only when
you have an accepted/completed reservation for this ad.

**Parameters:** `id` _(integer)_

**Returns:** `Ad` with attrs, imageUrls, contactName, contactPhone (gated), contactEmail (gated), showPhone

---

### `haszno_shop_price_hint` _(read-only)_

AI price suggestion. Label the result as a suggestion to the user.

**Parameters:**
- `title` _(string)_
- `category` _(string, optional)_
- `description` _(string, optional)_
- `condition` _(string, optional)_

**Returns:** `{ suggestedPriceGross: number, rangeMin: number, rangeMax: number }`

---

### `haszno_shop_list_my_ads` _(read-only)_

List the authenticated user's own ads (all statuses).

**Returns:** array of `Ad`

---

### `haszno_shop_list_inquiries` _(read-only)_

List messages/inquiries received on the user's ads.

**Returns:** `{ items: [{ id, adId, adTitle, senderName, message, createdAt }] }`

---

### `haszno_shop_list_favorites` _(read-only)_

List the user's favorited ads.

**Returns:** array of `Ad`

---

### `haszno_shop_list_reservations` _(read-only)_

List reservations.

**Parameters:**
- `role` _(`"buyer"` (default) | `"seller"`)_
- `status` _(string, optional)_ — e.g. `"fuggoben"`, `"elfogadva"`, `"teljesitve"`
- `page` _(integer, optional, default 1)_

**Returns:** `{ items: [Reservation] }`

Each `Reservation`: `id, adId, ad{id,title,priceGross,image,status}, status, message,
offerPriceGross, buyerName, buyerPhone (gated), buyerEmail (gated), sellerName,
sellerPhone (gated), sellerEmail (gated), heldUntil, createdAt, updatedAt, decidedAt`

Contact fields are non-null only when `status` is `"elfogadva"` or `"teljesitve"`.

---

### `haszno_shop_upload_image` _(write, non-destructive)_

Upload an image file; returns a URL to reference in `haszno_shop_create_ad`.

**Parameters (choose one input form):**
- `filePath` _(string)_ — absolute local path to a JPEG, PNG, or WebP file (e.g. `/tmp/photo.jpg`). The tool rejects files whose extension or magic bytes are not in that set.
- `base64` _(string)_ + `mimeType` _(`"image/jpeg" | "image/png" | "image/webp"`)_ — base-64 encoded image data (without the `data:` prefix) together with its MIME type.

**Returns:** `{ url: string, imageId: string }`

---

### `haszno_shop_suggest_from_photos` _(read-only)_

AI-suggest title, description, category, subcategory, and attributes from one or more
image URLs. Always label the result as a suggestion — do not post without user review.

**Parameters:** `imageUrls` _(string[])_

**Returns:** `{ title, description, category, subcategory, attrs: {key: value}, confidence }`

---

### `haszno_shop_create_ad` _(write — confirm required)_

Post a new ad. Always show the full draft to the user and require an explicit yes.
To preview before posting, use `haszno shop post --dry-run` on the CLI instead of this tool.

**Parameters:**
- `title` _(string)_
- `category` _(string)_ — key from `haszno_shop_list_categories`
- `subcategory` _(string, optional)_
- `priceGross` _(integer)_ — HUF gross
- `negotiable` _(boolean, optional)_
- `condition` _(`"uj" | "ujszerű" | "hasznalt" | "hibas"`, optional)_
- `description` _(string, optional)_
- `county` _(string, optional)_
- `city` _(string, optional)_
- `attrs` _(object, optional)_ — category-specific key/value attributes
- `imageUrls` _(string[], optional)_ — from `haszno_shop_upload_image`
- `contactName` _(string, optional)_
- `contactPhone` _(string, optional)_ — revealed only after acceptance
- `showPhone` _(boolean, optional)_ — allow buyer to see phone after acceptance
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ ad: Ad }`

---

### `haszno_shop_update_ad` _(write — confirm required)_

Edit an existing ad. Pass only the fields you want to change.

**Parameters:** `id` _(integer)_, any subset of `haszno_shop_create_ad` fields, `confirm`

**Returns:** `{ ad: Ad }`

---

### `haszno_shop_set_ad_status` _(write — confirm required)_

Pause or re-activate an ad.

**Parameters:**
- `id` _(integer)_
- `status` _(`"aktiv" | "szuneteltetve"`)_
- `confirm` _(boolean, must be `true`)_

---

### `haszno_shop_mark_sold` _(write — confirm required)_

Mark an ad as sold.

**Parameters:**
- `id` _(integer)_
- `soldPriceGross` _(integer, optional)_ — final sale price
- `confirm` _(boolean, must be `true`)_

---

### `haszno_shop_renew_ad` _(write — confirm required)_

Bump an ad to the top of search results.

**Parameters:** `id` _(integer)_, `confirm` _(boolean, must be `true`)_

---

### `haszno_shop_send_inquiry` _(write — confirm required)_

Send a message to the seller of an ad.

**Parameters:**
- `adId` _(integer)_
- `message` _(string)_ — max 1 000 chars
- `confirm` _(boolean, must be `true`)_

---

### `haszno_shop_set_favorite` _(write, non-destructive)_

Add or remove an ad from favorites.

**Parameters:**
- `adId` _(integer)_
- `save` _(boolean)_ — `true` = add to favourites, `false` = remove

---

### `haszno_shop_reserve_ad` _(write — confirm required)_

Reserve an ad (send a reservation request to the seller).

**Reserving is not paying.** Payment and handover happen directly between buyer and
seller. Never state or imply that money changed hands via Haszno.

**Parameters:**
- `adId` _(integer)_
- `message` _(string, optional)_ — note to seller, max 1 000 chars
- `offerPriceGross` _(integer, optional)_ — counter-offer in HUF gross
- `phone` _(string, optional)_ — buyer's phone, revealed to seller only on acceptance
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ reservation: Reservation }`

Errors: 409 if an open reservation already exists for this ad.

---

### `haszno_shop_respond_reservation` _(write — confirm required)_

(Seller) Accept or decline a pending reservation.

**Parameters:**
- `id` _(integer)_ — reservation id
- `action` _(`"accept" | "decline"`)_
- `heldUntil` _(ISO-8601 datetime, optional)_ — pick-up deadline (accept only)
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ reservation: Reservation }` (serializeSimple fields)

Errors: 400 if status is not `"fuggoben"`; 409 on accept if another accepted reservation exists.

---

### `haszno_shop_cancel_reservation` _(write — confirm required)_

(Buyer) Cancel your own reservation.

**Parameters:** `id` _(integer)_, `confirm` _(boolean, must be `true`)_

**Returns:** `{ reservation: Reservation }`

---

### `haszno_shop_complete_reservation` _(write — confirm required)_

(Seller) Complete a reservation and mark the transaction as done.

**Parameters:**
- `id` _(integer)_
- `soldPriceGross` _(integer, optional)_ — final sale price
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ reservation: Reservation, status: "teljesitve" }`

Side effects: ad status → `"eladva"`; all other open reservations for the ad →
`"elutasítva"`.

---

## Account & settings (`haszno_account_*`)

### `haszno_account_get_stats` _(read-only)_

Dashboard summary.

**Returns:**
```json
{
  "products": 42,
  "losing": 3,
  "overMarket": 1,
  "toFix": 4,
  "orders": 12
}
```

Fields:
- `losing` — products whose current price yields a margin below `minMarginPct`
- `overMarket` — products priced above the market minimum (losing sales)
- `toFix` — `losing + overMarket`

---

### `haszno_account_get_impact` _(read-only)_

Profit impact of pricing automation.

**Parameters:**
- `days` _(optional, default 30)_ — look-back window

**Returns:**
```json
{
  "days": 30,
  "extraProfit": 45200,
  "baseline": 320000,
  "pctGain": 14.1,
  "orders": 18,
  "autoForwardedOrders": 15
}
```

---

### `haszno_account_get_settings` _(read-only)_

Current pricing rules (singleton row).

**Returns:**
```json
{
  "id": 1,
  "undercutPct": 1,
  "minMarginPct": 10,
  "vatPct": 27,
  "automationPaused": false
}
```

---

### `haszno_account_update_settings` _(write — confirm required)_

Update pricing rules.

**Parameters:**
- `undercutPct` _(integer 0–50)_ — % to undercut market minimum
- `minMarginPct` _(integer 0–90)_ — minimum net margin the engine maintains
- `vatPct` _(integer 0–50)_ — VAT rate for all margin calculations
- `confirm` _(boolean, must be `true`)_

---

### `haszno_account_list_suppliers` _(read-only)_

List the shop's own configured suppliers (not the network).

**Returns:** array of `Supplier` objects with `id`, `name`, `orderMode`, `network`, `category`, `country`.

---

## Products (`haszno_products_*`)

### `haszno_products_list` _(read-only)_

List own shop products.

**Parameters:**
- `all` _(optional boolean, default false)_ — include unlisted products

**Returns:** array of `Product` with:
- `id`, `supplierId`, `sku`, `name`, `costNet`, `stock`, `rrpGross`
- `marketMinGross`, `marketShop` — lowest known market price and shop name
- `priceGross` — current shop price
- `listed` — whether currently listed
- `current` — `{ priceGross, marginNet, marginPct }` for the current price
- `recommended` — `{ priceGross, marginNet, marginPct }` from the pricing engine

---

### `haszno_products_update` _(write — confirm required)_

Update market data or override price for a product.

**Parameters:**
- `id` _(integer)_ — product id
- `marketMinGross` _(optional integer | null)_ — override market minimum
- `marketShop` _(optional string | null)_ — competing shop name
- `priceGross` _(optional integer)_ — manual price override
- `confirm` _(boolean, must be `true`)_

---

### `haszno_products_set_listing` _(write — confirm required)_

List or unlist a product.

**Parameters:**
- `id` _(integer)_ — product id
- `listed` _(boolean)_ — `true` = list, `false` = unlist
- `confirm` _(boolean, must be `true`)_

---

### `haszno_products_apply_prices` _(write — confirm required)_

Apply recommended prices (from the pricing engine) to products.

**Parameters:**
- `ids` _(optional integer[])_ — subset to apply; omit for all products
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ changed: number, total: number }`

---

### `haszno_products_ai_description` _(write — confirm required)_

Generate an AI product description.

**Parameters:**
- `id` _(integer)_ — product id
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ text: string }`

---

## Catalogue (`haszno_catalog_*`)

Network supplier catalogue. All tools are read-only.
The `supplier-view` endpoint returns aggregated stats only — never individual shop margins.

### `haszno_catalog_list_suppliers` _(read-only)_

List all network suppliers.

**Returns:** array of `NetworkSupplier` with `id`, `name`, `category`, `country`, `description`, `shopUrl`.

---

### `haszno_catalog_get_products` _(read-only)_

Get a network supplier's product catalogue.

**Parameters:**
- `supplierId` _(integer)_

**Returns:** array of `NetworkProduct` with `id`, `sku`, `name`, `category`,
`wholesaleNet`, `rrpGross`, `stock`, `potentialMargin` (margin at minimum undercut price).

---

### `haszno_catalog_supplier_view` _(read-only)_

Aggregated reseller market view for a supplier (legal note: shows aggregated stats
across all resellers; individual margins are not exposed).

**Parameters:**
- `supplierId` _(integer)_

**Returns:** `SupplierView`:
```json
{
  "supplier": { "id": 1, "name": "Demo Supplier", "category": "...", "country": "HU", "shopUrl": "..." },
  "products": [
    {
      "id": 1, "sku": "ABC-123", "name": "...",
      "wholesaleNet": 3500, "rrpGross": 9990, "stock": 10,
      "resellerCount": 5, "minGross": 8200, "avgGross": 8800,
      "maxGross": 9500, "belowRrp": 4, "lossCount": 1, "saturation": 0.6
    }
  ]
}
```

---

## Proposals (`haszno_proposals_*`)

Price proposals are generated by the pricing engine. Review them before approving.

### `haszno_proposals_list` _(read-only)_

List price proposals.

**Parameters:**
- `status` _(optional: `"pending"` | `"approved"` | `"rejected"`)_

**Returns:** array of `Proposal` with `id`, `productId`, `sku`, `name`,
`currentPriceGross`, `proposedPriceGross`, `marginPct`, `status`, `createdAt`.

---

### `haszno_proposals_approve` _(write — destructiveHint — confirm required)_

Approve price proposals (prices are changed immediately).

**Parameters:**
- `ids` _(optional integer[])_ — specific proposal ids; omit to approve all pending
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ batchId: string, applied: number }` — save `batchId` for potential rollback.

---

### `haszno_proposals_reject` _(write — confirm required)_

Reject price proposals.

**Parameters:**
- `ids` _(integer[])_
- `confirm` _(boolean, must be `true`)_

---

### `haszno_proposals_rollback` _(write — destructiveHint — confirm required)_

Roll back an approved batch (restores previous prices).

**Parameters:**
- `batchId` _(string)_ — from the approve response
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ rolledBack: number }`

---

## Rules (`haszno_rules_*`)

### `haszno_rules_list_templates` _(read-only)_

List built-in rule templates (starting points for new rules).

**Returns:** array of `RuleTemplate` with `key`, `name`, `description`.

---

### `haszno_rules_list` _(read-only)_

List all rules.

**Returns:** array of `Rule` with `id`, `name`, `enabled`, `trigger`,
`conditions` (`[{ field, op, value }]`), `actions` (`[{ type, params }]`), `template`.

---

### `haszno_rules_create` _(write — confirm required)_

Create a new rule.

**Parameters:**
- `name` _(string)_
- `trigger` _(string)_ — e.g. `"manual"`, `"schedule:daily"`, `"market_update"`
- `conditions` _(RuleCondition[])_
- `actions` _(RuleAction[])_
- `template` _(optional string)_
- `confirm` _(boolean, must be `true`)_

---

### `haszno_rules_update` _(write — confirm required)_

Update an existing rule.

**Parameters:**
- `id` _(integer)_
- Partial rule fields (`name`, `enabled`, `conditions`, `actions`, …)
- `confirm` _(boolean, must be `true`)_

---

### `haszno_rules_delete` _(write — destructiveHint — confirm required)_

Delete a rule permanently.

**Parameters:**
- `id` _(integer)_
- `confirm` _(boolean, must be `true`)_

---

### `haszno_rules_run` _(write — confirm required)_

Manually trigger a single rule.

**Parameters:**
- `id` _(integer)_
- `confirm` _(boolean, must be `true`)_

**Returns:** `RunResult` with `applied`, `skipped`, `errors`.

---

### `haszno_rules_run_all` _(write — confirm required)_

Run all rules with a `"manual"` trigger.

**Parameters:**
- `confirm` _(boolean, must be `true`)_

---

### `haszno_rules_trigger` _(write — confirm required)_

Fire a named event trigger (runs all rules subscribed to that trigger).

**Parameters:**
- `name` _(string)_
- `confirm` _(boolean, must be `true`)_

---

### `haszno_rules_list_runs` _(read-only)_

Rule execution log.

**Parameters:**
- `limit` _(optional integer, default 20)_

**Returns:** array of `RuleRun` with `id`, `ruleId`, `ruleName`, `status`, `appliedCount`, `createdAt`.

---

### `haszno_automation_get` _(read-only)_

Get the automation kill switch state.

**Returns:** `{ automationPaused: boolean }`. Check this before any bulk write.

---

### `haszno_automation_set` _(write — idempotentHint — confirm required)_

Pause or resume the automation engine.

**Parameters:**
- `paused` _(boolean)_
- `confirm` _(boolean, must be `true`)_

---

## Orders (`haszno_orders_*`)

### `haszno_orders_list` _(read-only)_

List recent orders.

**Returns:** array of `Order` with `id`, `externalId`, `customerName`, `address`,
`status` (`received | forwarded | shipped | error`), `totalGross`, `items`, `events`, `createdAt`.

---

### `haszno_orders_ship` _(write — idempotentHint — confirm required)_

Mark an order as shipped (once the supplier confirms).

**Parameters:**
- `id` _(integer)_
- `confirm` _(boolean, must be `true`)_

---

### `haszno_orders_receive` _(write — confirm required)_

Manually inject an incoming order (webhook alternative).

**Parameters:**
- `externalId` _(string)_
- `customerName` _(string)_
- `address` _(string)_
- `items` _(array of `{ sku: string, qty: number }`)_
- `confirm` _(boolean, must be `true`)_

---

## Ideas (`haszno_ideas_*`)

### `haszno_ideas_list` _(read-only)_

AI product idea shortlist — products from the network catalogue scored by trend + margin.

**Returns:** `Recommendations`:
```json
{
  "anchor": "hu",
  "geo": "HU",
  "items": [
    {
      "id": 1, "sku": "ABC-123", "name": "...",
      "costNet": 3500, "stock": 10, "supplierName": "...",
      "recommended": { "priceGross": 8500, "marginNet": 1200, "marginPct": 16.1 },
      "trendScore": 0.87
    }
  ]
}
```

---

### `haszno_ideas_fill_keywords` _(write — confirm required)_

Fill missing trend keywords for products via AI (batch job).

**Parameters:**
- `confirm` _(boolean, must be `true`)_

---

## Feeds (`haszno_feeds_*`)

### `haszno_feeds_import_supplier` _(write — confirm required)_

Import a supplier's product feed (CSV or XML).

**Parameters:**
- `supplierId` _(integer)_
- `format` _(`"csv"` | `"xml"`)_
- `content` _(string)_ — raw file content
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ created: number, updated: number, total: number }`

---

### `haszno_feeds_import_market` _(write — confirm required)_

Import market competitor prices (CSV format).

**Parameters:**
- `content` _(string)_ — raw file content
- `confirm` _(boolean, must be `true`)_

**Returns:** `{ matched: number, total: number }`

---

## Catalogue search (`haszno_catalogue_search`)

### `haszno_catalogue_search` _(read-only)_

Search the partner product catalogue.

**Parameters:**
- `q` _(string, optional)_ — free-text search on name or category
- `cats` _(string, optional)_ — comma-separated category keys, e.g. `"elektronika,ruházat"`
- `partner` _(integer, optional)_ — filter by supplier/partner id
- `minMarginPct` _(number, optional)_ — minimum margin %, e.g. `15`
- `maxPrice` _(number, optional)_ — maximum RRP gross in HUF
- `minPrice` _(number, optional)_ — minimum RRP gross in HUF
- `inStock` _(boolean, optional)_ — only in-stock products
- `hasImage` _(boolean, optional)_ — only products with an image
- `country` _(string, optional)_ — supplier country code, e.g. `"HU"`
- `sort` _(`"margin_desc" | "price_asc" | "price_desc" | "name_asc"`, optional)_
- `page` _(integer, optional, default 1)_
- `pageSize` _(integer, optional, default 24, max 100)_

**Returns:** `{ items: CatalogueItem[], total: number, facets: CatalogueFacets }`

Each `CatalogueItem`: `id, name, imageUrl, partnerId, partnerName, partnerCountry, category, categoryKey, wholesaleNet, rrpGross, marginNet, marginPct, stock, inImportList, inShop`

---

## Import list (`haszno_import_list_*`)

### `haszno_import_list_list` _(read-only)_

List items in the import staging list.

**Parameters:**
- `status` _(`"varakozik" | "kuldve" | "kesz" | "hiba"`, optional)_ — filter by push status
- `partner` _(integer, optional)_ — filter by supplier id
- `q` _(string, optional)_ — free-text search

**Returns:** `{ items: ImportListItem[], total: number }`

Each `ImportListItem`: `id, networkProductId, name, sku, partnerName, wholesaleNet, rrpGross, stock, pushStatus, targetConnectionId, targetExternalId, addedAt`

---

### `haszno_import_list_add` _(write, non-destructive)_

Add network/catalogue products to the import list.

**Parameters:**
- `networkProductIds` _(integer[], 1–100)_ — IDs from `haszno_catalogue_search`

**Returns:** `{ added: number, skipped: number }`

---

### `haszno_import_list_push` _(write — confirm required)_

Push import-list items to the connected webshop.

**Parameters:**
- `ids` _(integer[])_ — import list item IDs from `haszno_import_list_list`
- `targetConnectionId` _(integer, optional)_ — target store connection; if omitted, pushes to the shop's local product list via the default import-list endpoint
- `confirm` _(boolean, must be `true`)_ — without `true`, returns a dry-run preview and does **not** call the API

**Returns (with `targetConnectionId`):** `ConnectStorePushResult`
```json
{ "pushed": 2, "failed": 1, "errors": ["Widget Pro: out of stock"] }
```

**Returns (without `targetConnectionId`):** `ImportListPushResult`
```json
{ "pushed": 3 }
```

The two paths call different API endpoints: with a target → `POST /api/connect/stores/:id/push`; without → `POST /api/import-list/push`. Check for the presence of `failed`/`errors` before accessing them — they are only present when a target connection was used.

---

## Store connections (`haszno_connections_list`)

### `haszno_connections_list` _(read-only)_

List connected webshop store connections.

**Parameters:**
- `status` _(`"uj" | "domain_ok" | "kapcsolva" | "hiba"`, optional)_

**Returns:** `{ connections: StoreConnection[] }`

Each `StoreConnection`: `id, platform, name, status, domain, lastError, connectedAt, lastSyncAt, createdAt`

Status values: `uj` (new/setup), `domain_ok` (domain verified), `kapcsolva` (connected), `hiba` (error)

Platforms: `shoprenter`, `unas`, `woocommerce`, `shopify`, `medusa`, `mock`

---

## P2P peer invites (`haszno_peers_*`)

### `haszno_peers_invite_create` _(write — confirm required)_

Create an invite code to share a supplier's catalogue with a partner shop.

**Parameters:**
- `supplierId` _(integer)_ — supplier to share
- `expiresAt` _(ISO-8601 datetime string)_ — expiry, must be in the future
- `confirm` _(boolean, must be `true`)_ — without `true`, returns a dry-run preview and does **not** call the API

**Returns:** `PeerInvite` — includes `code` to share with the partner

**Dry-run (confirm=false):** returns `{ preview: true, message, supplierId, expiresAt }` — no invite is created.

---

### `haszno_peers_invite_list` _(read-only)_

List your created invite codes.

**Returns:** `{ invites: PeerInvite[] }`

Each `PeerInvite`: `id, code, supplierId, expiresAt, acceptedBy, acceptedAt, revokedAt, createdAt`

---

### `haszno_peers_invite_accept` _(write — confirm required)_

Accept a peer invite code and establish a partner link.

**Parameters:**
- `code` _(string)_ — the invite code
- `acceptorId` _(string)_ — your shop/tenant identifier
- `confirm` _(boolean, must be `true`)_

**Returns:** `PeerLink` — `{ id, supplierId, partner, createdAt }`

---

## Blog / market insights (`haszno_blog_latest`)

### `haszno_blog_latest` _(read-only)_

Fetch the latest published market insight blog post(s). Data is anonymised aggregate from >= 5 shops.

**Parameters:**
- `period` _(`"het" | "honap"`, optional)_ — weekly or monthly posts
- `limit` _(integer 1–10, optional, default 1)_

**Returns:** `{ posts: BlogPost[], total: number }`

Each `BlogPost`: `id, slug, period, periodStart, periodEnd, title, summary, bodyMd, data, publishedAt, status, createdAt`

`data` may include: `rankedCategories: [{category, score}]`, `rankedProducts: [{name, score}]`, `shopsCount`

