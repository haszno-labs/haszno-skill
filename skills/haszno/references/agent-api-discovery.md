# Haszno API Discovery — Generic tools and OpenAPI registry

The Haszno server publishes its entire live route table as an OpenAPI document and
exposes three generic MCP tools (`haszno_api_list`, `haszno_api_describe`,
`haszno_api_call`) plus a matching CLI sub-command (`haszno api …`). These let an
agent discover and call any endpoint — including endpoints added after the last MCP
release — without waiting for a new package.

---

## Decision tree — which tool to reach for

```
Does a typed MCP tool exist for this operation?
  YES → use it (richer schema, better errors, e.g. haszno_shop_*, haszno_booking_*,
              haszno_list_orders, haszno_catalog_*, haszno_proposals_*, ...)
  NO  → 1. haszno_api_list  (discover: find the route)
         2. haszno_api_describe  (inspect: schema + risk level)
         3. haszno_api_call  (execute: with confirm:true when risk=confirm)
```

In a shell / Codex / Cursor session:
```
haszno api ls [query] [--tag <t>] [--risk <r>]
haszno api describe <METHOD> <path>
haszno api <METHOD> <path> [--query k=v] [--data '<json>'|@file] [--yes]
```

---

## Risk levels (`x-haszno-risk`)

Every route in `GET https://haszno.com/api/openapi.json` carries a risk annotation.

| Level | Meaning | Agent rule |
|---|---|---|
| `read` | Safe GET / HEAD. No side-effects. | Call freely; no confirmation needed. |
| `write` | Modifies shop data (CRUD). Reversible by design. | Show the user what will change; get explicit confirmation; then call. |
| `confirm` | High-impact: moves money, publishes, sends e-mail, or deletes irreversibly. | **Always ask the human first.** Pass `confirm: true` only after they say yes. Without `confirm: true`, `haszno_api_call` returns a dry-run description and stops. |
| `blocked` | Admin, cron, webhook, or auth-bootstrap route. | Refuse immediately. Never attempt to work around this. `haszno_api_call` refuses blocked paths before making any network call. |

The CLI mirrors this: `blocked` → refused; `confirm` without `--yes` and without a TTY → refused; with a TTY → prompts `y/N`.

---

## OpenAPI spec endpoint

```
GET https://haszno.com/api/openapi.json
```

Returns a standard OpenAPI 3.x document. Each operation includes:
- `summary` — one-line description
- `tags` — first tag is the API area (e.g. `products`, `orders`, `catalog`)
- `x-haszno-risk` — `read` | `write` | `confirm` | `blocked`
- `parameters` — query and path params
- `requestBody` — JSON body schema when present

The CLI caches this for 10 minutes at `~/.config/haszno/cache/openapi.json`.
Pass `--refresh` to bypass the cache.

---

## Generic MCP tools

### `haszno_api_list`

Search the live route registry.

**Parameters:**
- `query` _(string, optional)_ — keyword in path, summary, or tag
- `tag` _(string, optional)_ — filter by API tag (first segment after `/api/`)
- `risk` _(`read` | `write` | `confirm` | `blocked`, optional)_ — filter by risk level
- `limit` _(integer, 1–200, default 50)_

**Returns:** `{ routes: [{method, path, summary, tag, risk}], total, shown, hasMore }`

**Example:**
```json
{ "query": "orders", "risk": "read" }
```

---

### `haszno_api_describe`

Full details for one route: path params, body/query schemas, risk level.
Call this after `haszno_api_list` to inspect a specific route before executing.

**Parameters:**
- `method` _(string)_ — HTTP method, e.g. `GET`, `POST`
- `path` _(string)_ — path template from `haszno_api_list`, e.g. `/api/products/{id}`

**Returns:** `{ method, path, summary, tag, risk, pathParameters, bodySchema, querySchema, riskNote }`

---

### `haszno_api_call`

Execute any route using the caller's own token.

**Parameters:**
- `method` _(string)_ — HTTP method
- `path` _(string)_ — actual path with real values, e.g. `/api/products/42`
- `query` _(Record<string,string>, optional)_ — query string params
- `body` _(unknown, optional)_ — JSON body
- `confirm` _(boolean, optional)_ — pass `true` to execute a `confirm`-risk route

**Risk enforcement (enforced by the tool, not bypassed):**
- `blocked` → refused with a clear error; use `haszno_api_list` to find accessible routes.
- `confirm` without `confirm: true` → returns a dry-run description and stops; re-call with `confirm: true` after the user confirms.
- `read`-scope token + non-GET → the in-process handler returns `403`; the tool surfaces it.

**Response:** `{ status, ok, data, truncated?, total?, truncationNote? }`
Large list responses are automatically truncated to the first 20 items; `total` gives the full count.

**Safety:** absolute URLs, double slashes, dot-segment traversal, and percent-encoded path separators are rejected before any call.

---

## CLI — `haszno api`

The CLI fetches `GET /api/openapi.json` and operates on the same risk rules.

```bash
# List routes — keyword search
haszno api ls orders
haszno api ls --tag catalog --risk read
haszno api ls --json

# Inspect one route
haszno api describe GET /api/products
haszno api describe POST /api/agent/proposals --json

# Call a read route
haszno api get /api/agent/products

# Call a write route (prompts for confirmation in a TTY)
haszno api post /api/agent/proposals \
  --data '{"productId":42,"proposedPriceGross":4490,"reason":"...","nonce":"..."}'

# Skip the TTY prompt (pre-confirmed in a script)
haszno api post /api/agent/proposals --data @proposal.json --yes

# Pass query params
haszno api get /api/agent/proposals --query status=pending

# Force a spec refresh (bypass 10-minute cache)
haszno api ls --refresh
```

**--yes flag:** equivalent to `confirm: true` in the MCP. Only use it after the user has
explicitly confirmed the operation. Never pass `--yes` automatically in a loop.

---

## Pricing business rules (enforced here and by the API)

These rules apply to ALL pricing operations — whether using typed tools
(`haszno_catalog_approve_proposals`, `haszno_catalog_set_shop_pricing`,
`haszno_catalog_reprice_shop`) or generic ones (`haszno_api_call` with a pricing route).

### 1. Absolute price floor

The API will never price a product below:
```
effectiveWholesaleNet (purchase cost) + minimum profit
```
This is enforced by `deriveWholesaleNet` / `effectiveWholesaleNet` in the backend.
No rule, proposal, or manual call can breach it. If a price would fall below the
floor, the API returns `422`. Never retry with a lower price.

The floor is visible in `haszno_catalog_list_products` as part of each product's
recommended price context.

### 2. Per-shop isolation (antitrust / hub-and-spoke)

Each shop's pricing rule is computed **only** from:
- That shop's own purchase cost
- That shop's own floor, ceiling, and strategy
- Publicly available market prices

No cross-reseller data: one shop's rules, costs, or prices are never an input to
or visible in another shop's pricing. When writing copy or reporting results, always
say "minden bolt a saját árszabálya szerint áraz" — never "összehangolt", "közös ár",
or "mind a 80 boltot együtt árazzuk".

### 3. Confirm gate for pricing writes

| Operation | Risk | Rule |
|---|---|---|
| `haszno_catalog_approve_proposals` | `confirm` | Always ask human first |
| `haszno_catalog_reprice_shop` | `confirm` | Always ask human first |
| `haszno_catalog_set_shop_pricing` | `write` | Show config diff; confirm verbally |
| `haszno_catalog_push_to_shop` | `confirm` | Show item list; confirm verbally |

### 4. Omnibus price history

A per-listing price history is maintained so the lowest price in the previous 30 days
can be shown when displaying a price as a discount. The API manages this automatically.

### 5. Order approval and proposal approval — human-in-the-loop by design

- `haszno_catalog_approve_proposals` — the server refuses price-proposal approval for API keys
  (`/api/proposals/approve` returns 403 for Bearer callers, by design: `rejectBearerOnApproval` in
  the Haszno API). An agent can list and explain proposals; the owner approves them in the UI
  („Jóváhagyás”). Do not retry or look for another route.
- Order approve (`haszno_approve_order`) — CONFIRM risk; triggers stock reservation and
  supplier forwarding.
- Both are intentionally `confirm`-gated to keep a human in the loop for money-moving
  actions.

---

## Compact table of new typed tools by area

### Generic discovery (MCP only)
| Tool | Risk | Description |
|---|---|---|
| `haszno_api_list` | read | Search live route registry |
| `haszno_api_describe` | read | Full schema + risk for one route |
| `haszno_api_call` | varies | Execute any accessible route |

### Orders, returns, coupons, settings (shop token)
| Tool | Risk | Description |
|---|---|---|
| `haszno_list_orders` | read | Browse orders (optional status/cats filter) |
| `haszno_ship_order` | write | Mark order as shipped |
| `haszno_approve_order` | confirm | Approve + forward a pending-approval order |
| `haszno_reject_order` | confirm | Reject a pending-approval order |
| `haszno_cancel_order` | confirm | Cancel an order |
| `haszno_get_approval_threshold` | read | Read manual-approval threshold |
| `haszno_set_approval_threshold` | write | Set/clear manual-approval threshold |
| `haszno_list_returns` | read | List return/withdrawal requests |
| `haszno_get_return` | read | Single return request detail |
| `haszno_list_warranty_claims` | read | List warranty/guarantee claims |
| `haszno_get_warranty_claim` | read | Single warranty claim detail |
| `haszno_list_coupons` | read | List coupons |
| `haszno_create_coupon` | write | Create a new coupon |
| `haszno_update_coupon` | write | Update coupon active/limit/expiry |
| `haszno_delete_coupon` | confirm | Delete a coupon |
| `haszno_get_shop_settings` | read | Read pricing rules + shipping markets |
| `haszno_update_shop_settings` | write | Write pricing rules + shipping markets |
| `haszno_get_notification_prefs` | read | Read e-mail notification preferences |
| `haszno_update_notification_prefs` | write | Update notification preferences |
| `haszno_list_shop_connections` | read | List webshop connections |
| `haszno_get_shipping_rules` | read | Get shipping-fee rules for a connection |
| `haszno_set_shipping_rules` | write | Replace shipping-fee rules |

### Catalog, import-list, rules, proposals, dynamic pricing (shop token)
| Tool | Risk | Description |
|---|---|---|
| `haszno_catalog_list_products` | read | Own shop products with margin + recommended price |
| `haszno_catalog_update_product` | write | Patch price, marketMinGross, marketShop |
| `haszno_catalog_toggle_listing` | write | List or unlist a product (confirm to unlist) |
| `haszno_catalog_search_catalogue` | read | Search supplier catalogue with filters + pagination |
| `haszno_catalog_add_to_import_list` | write | Stage up to 200 catalogue products |
| `haszno_catalog_list_import_list` | read | Browse staged / pushed / discarded items |
| `haszno_catalog_push_to_shop` | confirm | Promote staged items to own shop products |
| `haszno_catalog_discard_import_list` | confirm | Reject staged items |
| `haszno_catalog_list_rules` | read | List all automation rules |
| `haszno_catalog_create_rule` | write | Create a new rule |
| `haszno_catalog_update_rule` | write | Update an existing rule |
| `haszno_catalog_delete_rule` | confirm | Delete a rule |
| `haszno_catalog_run_rule` | confirm | Run a rule manually right now |
| `haszno_catalog_list_proposals` | read | List pricing proposals |
| `haszno_catalog_approve_proposals` | confirm | Bulk-approve proposals (API checks floor) |
| `haszno_catalog_reject_proposals` | confirm | Reject proposals |
| `haszno_catalog_get_shop_pricing` | read | Read per-shop dynamic pricing strategy |
| `haszno_catalog_set_shop_pricing` | write | Create/update pricing strategy |
| `haszno_catalog_reprice_shop` | confirm | Trigger manual repricing for one shop |

Full tool signatures: [`references/tools.md`](tools.md)
Full CLI signatures: [`references/commands.md`](commands.md)
