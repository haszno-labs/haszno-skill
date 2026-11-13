---
name: haszno
description: >
  Work with Haszno dropshipping data: query partner catalogue, review and approve
  price proposals, manage automation rules, check orders, find new product ideas,
  connect webshops (bolt-bekötés), manage P2P peer partner invites, and read
  aggregated market blog posts. Also covers the Haszno Shop free marketplace:
  post ads, search and reserve items, manage incoming reservations and inquiries.
  Use when the user mentions Haszno, dropshipping pricing, price proposals
  (árajánlat), automation rules (automatika), product margins, Árukereső feed,
  supplier catalogue, connecting a webshop (bekötés, WooCommerce, Shopify),
  import list (import lista), push products to shop (termékek kiküldése),
  partner invite (meghívó), peer link (partner kapcsolat), or asks to run a
  daily dropshipping check. Also triggers on: sell this, post an ad, list my
  item on Haszno, find me a used … on Haszno, reserve/buy this, ad posting,
  hirdetés feladása, add fel Hasznóra, hirdesd meg, keress nekem, foglald le,
  vedd meg, approve proposals, reject proposals, run rule, margin check,
  veszteséges termékek, árazás automatizálás, partnerkatekógus, termékötlet,
  dropshipping ügynök, bolt-bekötés, barát meghívása, beszállító katalógus,
  heti összefoglaló.
triggers:
  - haszno
  - haszno.com
  - dropshipping
  - price proposal
  - árajánlat
  - automatika
  - partnerkatekógus
  - veszteséges termékek
  - margin check
  - árukereső feed
  - termékötlet
  - dropshipping check
  - pricing rules
  - árazás
  - bolt-bekötés
  - import lista
  - termékek kiküldése
  - meghívó
  - partner kapcsolat
  - heti összefoglaló
  - havi összefoglaló
  - hirdetés
  - foglalás
  - eladás
  - add fel
  - hirdesd meg
  - keress nekem
  - foglald le
  - vedd meg
  - sell this
  - post an ad
  - reserve this
  - haszno shop
  - marketplace
  - alku
  - ellenajánlat
  - értékelés
  - mentett keresés
  - árfigyelés
  - figyeld az árát
  - import linkből
  - tömeges feladás
  - post-bulk
  - saved-search
  - import-url
  - remove-bg
  - háttér eltávolítás
---

# Haszno agent skill

Haszno (haszno.com) is a Hungarian SaaS that automates dropshipping pricing. This skill
teaches AI agents how to use `@haszno/mcp` and the `haszno` CLI safely.

Detailed references live in `references/`:
- [`references/tools.md`](references/tools.md) — full MCP tool catalogue
- [`references/commands.md`](references/commands.md) — full CLI command catalogue
- [`references/recipes.md`](references/recipes.md) — step-by-step workflow recipes

---

## Quick-start

### Authentication

```bash
export HASZNO_API_URL=https://haszno.com   # alapértelmezett
export HASZNO_API_KEY=your-api-key                  # Bearer token (preferred)
# Silent fallback — the old names are also accepted:
# export ARFUTAR_API_URL=...  export ARFUTAR_API_KEY=...
# Config dir: ~/.config/haszno  (falls back to ~/.config/arfutar if present)
# OR for demo HTTP Basic fallback:
export HASZNO_BASIC="user:pass"
```

Never print, log, or echo credentials.

### Via MCP (Claude Desktop / Claude Code)

Add with one command:
```bash
claude mcp add haszno --scope user -- node ~/.haszno/haszno-mcp/dist/index.js
```

Or set env-based `npx` variant in `claude_desktop_config.json` / `.claude/settings.json`:

```json
{
  "mcpServers": {
    "haszno": {
      "command": "npx",
      "args": ["-y", "github:haszno-labs/haszno-mcp"],
      "env": {
        "HASZNO_API_URL": "https://haszno.com",
        "HASZNO_API_KEY": "your-api-key"
      }
    }
  }
}
```

Then use the `haszno_*` tools listed in `references/tools.md`.

### Via CLI (Codex / Cursor / shell)

```bash
npm install -g github:haszno-labs/haszno-cli    # one-time global install
# OR run without install (after npm link in ~/.haszno/haszno-cli):
haszno account stats --json
haszno products list --all --json
```

The installer at `install.sh` in this repo handles both — run it once, get both.

---

## MCP vs CLI — when to use which

The skill **prefers MCP tools** when they are available (i.e. in an interactive
Claude Desktop / Claude Code conversation where the `haszno_*` tools are connected).
Fall back to the `haszno` CLI when MCP is unavailable (Codex, Cursor, shell, cron).

| Situation | Prefer |
|---|---|
| Interactive Claude Desktop / Claude Code conversation — MCP connected | **MCP** (`haszno_*` tools) |
| Shell script, cron job, Codex agent, Cursor terminal | **CLI** (`haszno <domain> <cmd>`) |
| Programmatic TypeScript / Node integration | **HTTP client** directly (vendored in CLI/MCP) |
| Batch write (approve many proposals at once) | Either — both require `confirm: true` |

The MCP server exposes the same operations as the CLI; they share the same vendored
HTTP client under the hood. Use whichever is natural for your surface.

CLI and MCP also share the same API key and config directory (`~/.config/haszno`),
so `haszno login` (or setting `HASZNO_API_KEY`) once configures both.

---

## Safety rules — read before any write

1. **Read-only by default.** Use read tools and list commands freely, without asking.
2. **Every write requires `confirm: true` / explicit user confirmation.**
   Writes: approve, reject, rollback, run rule, list/unlist product, apply prices,
   import feed, update settings, ship order, import-list push, peer invite create,
   peer invite accept.
3. **Check the automation kill switch first.**
   Before any bulk write, call `haszno_automation_get` (MCP) or
   `haszno rules automation` (CLI) and confirm `automationPaused` is `false`.
   If `true`, do not approve proposals or run rules — report the status to the user.
4. **Rollback before escalating.**
   If an approved proposal batch looks wrong, call `haszno_proposals_rollback`
   with the `batchId` before anything else.
5. **Never pass negative prices.** All prices are positive whole forints (gross).
6. **Partner catalogue is aggregated.** The `supplier-view` endpoint returns
   aggregated reseller stats only — it must not expose individual shop margins.
7. **Demo environment is read-mostly.** Read-only GETs against the demo URL are
   fine for smoke tests. Never POST writes to the demo unless the user explicitly
   asks and confirms this is intentional.

---

## Safe workflows

### 1 — Find loss-making products

Goal: identify products where the current price yields a negative or below-minimum margin.

```
MCP:  haszno_account_get_stats          → shows stats.losing count
      haszno_products_list (all=true)   → filter where current.marginPct < minMarginPct
CLI:  haszno account stats --json
      haszno products list --all --json | jq '[.[] | select(.current.marginPct < 10)]'
```

Typical output fields to report: `id`, `name`, `sku`, `current.marginPct`,
`recommended.priceGross`. Never auto-fix — show the list and ask the user.

### 2 — Review and approve price proposals

Goal: review pending AI price proposals, confirm with the user, then approve or reject.

```
1. Check kill switch:   haszno_automation_get  →  automationPaused must be false
2. List proposals:      haszno_proposals_list(status="pending")
3. Show summary to user (count, avg delta, largest gain/loss)
4. Wait for explicit user confirmation
5. Approve:             haszno_proposals_approve(ids=[...], confirm=true)
   OR reject:           haszno_proposals_reject(ids=[...], confirm=true)
6. Save batchId from approve response — needed for rollback if something is wrong
```

Never approve proposals without showing the user what will change.

### 3 — Pick products to add in a category

Goal: browse the partner catalogue and find products worth listing.

```
1. List suppliers:        haszno_catalog_list_suppliers
2. Get catalogue:         haszno_catalog_get_products(supplierId=<id>)
   Filter by: stock > 0, potentialMargin.marginPct >= minMarginPct, category match
3. Cross-check:           haszno_products_list(all=true) — skip already-listed SKUs
4. Present shortlist to user
5. If user approves listing:
   haszno_products_set_listing(id=<id>, listed=true, confirm=true)
```

Do not list products automatically. Always confirm the shortlist first.

### 4 — Push import-list items to a connected store

Goal: push staged import-list items to a connected webshop (WooCommerce, Shopify, etc.).

```
1. Check the connection:  haszno_connections_list  →  use id where status = "kapcsolva"
2. List staged items:     haszno_import_list_list(status="varakozik")
3. Confirm with user: which item IDs to push, which connection to use
4. Push to connected store (returns {pushed, failed, errors}):
   haszno_import_list_push(ids=[...], targetConnectionId=<id>, confirm=true)
   OR push to local product list only (returns {pushed}):
   haszno_import_list_push(ids=[...], confirm=true)   # no targetConnectionId
5. Report pushed count; if failed > 0, show errors to the user
```

**Two API paths — both require confirm=true:**
- With `targetConnectionId` → `POST /api/connect/stores/:id/push` → returns `{ pushed, failed, errors }`
- Without `targetConnectionId` → `POST /api/import-list/push` → returns `{ pushed }` only
Never dereference `failed`/`errors` unless `targetConnectionId` was given.

### 5 — Daily dropshipping check

Goal: surface the most important issues in one pass.

```
1. haszno_account_get_stats      → products, losing, overMarket, toFix, orders
2. haszno_automation_get         → confirm not paused
3. haszno_proposals_list(status="pending")  → count + preview
4. haszno_orders_list            → last N orders, any in 'error' status?
5. haszno_account_get_impact     → profit impact last 30 days
```

Report a brief summary: overall health, pending proposals count, any stuck orders,
profit impact. Ask the user which item to drill into.

---

## Haszno Shop (free marketplace)

The Haszno Shop is a free P2C/P2P classified-ads marketplace built into Haszno.
There are no plans or paid tiers for using the Shop.

### CLI vs MCP

| Surface | Prefer |
|---|---|
| Interactive Claude Desktop / Claude Code (MCP connected) | **MCP** (`haszno_shop_*` tools) |
| Shell script, cron, Codex, Cursor | **CLI** (`haszno shop <cmd>`) |

### One-time login

```bash
haszno login          # prompts for e-mail + password, saves token to ~/.config/haszno
```

After that both CLI and MCP share the same token automatically — no further setup.

### Golden rules

**(a) The Shop is completely free.** Never mention prices, plans, or subscription tiers
when talking about using the Shop.

**(b) Posting an ad, sending an inquiry, and reserving are real, visible actions.**
Always compose the full draft and show it to the user; get an explicit "yes" before
calling any write endpoint. Use `--dry-run` (CLI) or omit `confirm: true` (MCP) to
preview first.

**(c) Reserving is not paying.** A reservation is a buyer signalling intent; payment
and handover happen directly between buyer and seller outside Haszno. Never state or
imply that money changed hands via the platform.

**(d) Never invent attributes, prices, or photos.** Ask the user for missing required
attributes. Use `haszno shop price-hint` / `haszno_shop_price_hint` for a price
suggestion, and label it as a suggestion. Use `--from-photos` / `haszno_shop_suggest_from_photos`
for AI-generated draft text, and label that as a suggestion too.

**(e) Never put the user's phone number or e-mail into the ad text or into any
free-text field** (reservation messages, inquiry replies, review comments) on their
behalf without asking explicitly. Use the dedicated `--contact-phone` / `contactPhone`
field, which is revealed to the other party only after a reservation is accepted.

**(f) Always show and confirm a counter-offer amount before sending.** A counter-offer
(`haszno_shop_counter_offer` / `haszno shop reservation counter`) is immediately visible
to the buyer and cannot be unsent. Show the exact amount ("Ellenajánlatot küldök:
195 000 Ft. Megerősíted?") and wait for an explicit "yes".

**(g) Always show and confirm a review before submitting.** A review is permanent and
publicly associated with the reviewer's account. Show the star rating and comment text,
ask the user to confirm, then pass `confirm: true`.

**(h) Always dry-run bulk posting first.** Before `haszno shop post-bulk --yes` or any
batch ad creation loop, run with `--dry-run`, show the preview table to the user, and
get an explicit "yes". The command stops on the first error.

### Status state machine (reservations)

```
fuggoben → elfogadva (accept) → teljesitve (complete)
fuggoben → elutasitva (decline, or when ad sold/paused/deleted)
elfogadva → elutasitva (when ad sold/paused/deleted)
elfogadva → lejart (when the 48-hour hold expires without completion)
fuggoben/elfogadva → visszavonva (cancel by buyer)
```

Accepted reservations hold for **48 hours** from acceptance (server-set; not caller-configurable).
`effectiveStatus` returns `"lejart"` at read time if status is `"elfogadva"` and
`heldUntil` has passed — no DB write required for display.

Contact details (phone, e-mail) become visible to the other party only after acceptance.

---

## Domain → endpoint → package map

| Domain | Key read operations | Key write operations |
|---|---|---|
| `account` | `get_stats`, `get_impact`, `get_settings`, `list_suppliers` | `update_settings` |
| `products` | `list` (own shop) | `update`, `set_listing`, `apply_prices`, `ai_description` |
| `catalog` | `list_suppliers`, `get_products`, `supplier_view` | — (read-only) |
| `catalogue` | `haszno_catalogue_search` | `haszno_import_list_add` |
| `importList` | `haszno_import_list_list` | `haszno_import_list_push` (confirm required) |
| `connections` | `haszno_connections_list` | — |
| `peers` | `haszno_peers_invite_list` | `haszno_peers_invite_create` (confirm required), `haszno_peers_invite_accept` (confirm required) |
| `blog` | `haszno_blog_latest` | — (public read-only) |
| `shop` | `haszno_shop_list_categories`, `haszno_shop_search_ads`, `haszno_shop_get_ad`, `haszno_shop_price_hint`, `haszno_shop_list_my_ads`, `haszno_shop_list_inquiries`, `haszno_shop_list_favorites`, `haszno_shop_list_reservations`, `haszno_shop_suggest_from_photos`, `haszno_shop_list_messages`, `haszno_shop_list_saved_searches`, `haszno_shop_get_draft` | `haszno_shop_upload_image`, `haszno_shop_create_ad`, `haszno_shop_update_ad`, `haszno_shop_set_ad_status`, `haszno_shop_mark_sold`, `haszno_shop_renew_ad`, `haszno_shop_send_inquiry`, `haszno_shop_reply_inquiry`, `haszno_shop_set_favorite`, `haszno_shop_reserve_ad`, `haszno_shop_respond_reservation`, `haszno_shop_cancel_reservation`, `haszno_shop_complete_reservation`, `haszno_shop_counter_offer`, `haszno_shop_accept_counter`, `haszno_shop_send_message`, `haszno_shop_review` _(confirm)_, `haszno_shop_save_search`, `haszno_shop_delete_saved_search`, `haszno_shop_watch_price`, `haszno_shop_import_from_url`, `haszno_shop_save_draft`, `haszno_shop_clear_draft`, `haszno_shop_remove_background` |
| `proposals` | `list` | `approve`, `reject`, `rollback` |
| `rules` | `list`, `list_templates`, `list_runs`, `automation_get` | `create`, `update`, `delete`, `run`, `run_all`, `trigger`, `automation_set` |
| `orders` | `list` | `ship`, `receive` |
| `ideas` | `list` | `fill_keywords` |
| `feeds` | — | `import_supplier`, `import_market` |

Full signatures: `references/tools.md` (MCP) and `references/commands.md` (CLI).

---

## Packages

| Package | Description |
|---|---|
| `@haszno/mcp` | MCP server (stdio) — exposes `haszno_*` tools to Claude Desktop / Claude Code |
| `@haszno/cli` | Node CLI — `haszno` command with `--json` flag |

## API reference

See the Haszno documentation at https://docs.haszno.com/en/
