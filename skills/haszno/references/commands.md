# Haszno CLI Command Reference

Install / run:
```bash
npm install -g github:haszno-labs/haszno-cli    # global install
# OR install once via the shared installer:
curl -fsSL https://raw.githubusercontent.com/haszno-labs/haszno-skill/main/install.sh | bash
```

**Global flags** (apply to every command):

| Flag | Default | Description |
|---|---|---|
| `--json` | false | Machine-readable JSON output |
| `--api-url <url>` | `$HASZNO_API_URL` | API base URL |
| `--api-key <key>` | `$HASZNO_API_KEY` | Bearer token |

Authentication fallback: if `--api-key` and `$HASZNO_API_KEY` are absent,
the client reads `$ARFUTAR_API_KEY` as a silent legacy fallback, then
`$HASZNO_BASIC="user:pass"` for HTTP Basic.
Config dir: `~/.config/haszno` (falls back to `~/.config/arfutar` if present).

---

## `haszno login` / `logout` / `whoami` — CLI authentication _(READ / WRITE)_

### `haszno login`

Interactive login: prompts for e-mail and password, issues a write-scope token saved
to `~/.config/haszno/config.json`. Run once; both CLI and MCP then share this key automatically.

```bash
haszno login
# → Email: you@example.com
# → Password: ••••••••••
# → Logged in as Kovács Anna (kovács bolt). Token saved.
```

---

### `haszno logout`

Revoke the current CLI token and remove it from local config. **Write.**

---

### `haszno whoami`

Print the authenticated user: name, email, shopName.

---

## `haszno shop` — Marketplace (free, no plans)

> The Haszno Shop is free. Never mention plans or pricing for using it.
> Posting an ad, sending an inquiry, and reserving are real, visible actions —
> show the user the final draft and get an explicit yes first. See SKILL.md §
> "Haszno Shop golden rules".

### `haszno shop categories [--json]` _(read)_

List the top-level and sub-categories available for ad posting.

---

### `haszno shop search [<query>] [--json]` _(read)_

Search active ads.

**Flags:** `--category <key>`, `--subcategory <key>`, `--county <megye>`,
`--min-price <Ft>`, `--max-price <Ft>`, `--condition <uj|ujszerű|hasznalt|hibas>`,
`--reserved` (include reserved ads), `--page <n>`

```bash
haszno shop search "iPhone 14" --condition ujszerű --max-price 200000 --json \
  | jq '.[] | {id, title, priceGross, reserved, county}'
```

---

### `haszno shop show <id> [--json]` _(read)_

Show full ad detail. Contact fields (`sellerPhone`, `sellerEmail`) are populated only
when you have an accepted reservation for that ad.

---

### `haszno shop price-hint [--json]` _(read)_

Get an AI price suggestion. **Flags:** `--title <str>`, `--category <key>`,
`--description <text>`, `--condition <str>`. Always label the result as a suggestion.

---

### `haszno shop post ...` _(write — requires `--yes`)_

Post a new ad. Always show a `--dry-run` preview first; get explicit confirmation.

| Flag | Required | Description |
|---|---|---|
| `--title <str>` | yes | Ad title |
| `--category <key>` | yes | Category key from `haszno shop categories` |
| `--subcategory <key>` | — | Subcategory |
| `--price <Ft>` | yes | Asking price in HUF gross |
| `--negotiable` | — | Mark price as negotiable |
| `--condition <str>` | — | `uj` / `ujszerű` / `hasznalt` / `hibas` |
| `--description <text>` | — | Free-text description |
| `--county <megye>` | — | County (Pest, Győr-Moson-Sopron, …) |
| `--city <varos>` | — | City / settlement |
| `--attr key=value` | — | Category-specific attribute (repeatable) |
| `--image <file>` | — | Attach image (repeatable, up to 10) |
| `--contact-name <name>` | — | Contact name shown to buyer |
| `--contact-phone <tel>` | — | Phone revealed to buyer only after acceptance |
| `--show-phone` | — | Allow buyer to see phone after acceptance |
| `--from-photos` | — | AI-suggest title/description/category from `--image` files |
| `--dry-run` | — | Preview only — does not call API |
| `--yes` | required | Skip confirmation prompt |

```bash
# Dry-run preview:
haszno shop post --title "Ikea Billy könyvespolc" --category butor \
  --price 8000 --condition hasznalt --county Budapest --dry-run

# Actual post:
haszno shop post --title "Ikea Billy könyvespolc" --category butor \
  --price 8000 --condition hasznalt --county Budapest --yes
```

---

### `haszno shop my [--json]` _(read)_

List your own ads (all statuses).

---

### `haszno shop edit <id> [same flags as post, except --from-photos / --dry-run]` _(write — requires `--yes`)_

Edit an existing ad. Only the flags you pass are updated.

---

### `haszno shop pause <id>` _(write)_

Pause an ad (hide from search results). Prompts for confirmation.

---

### `haszno shop activate <id>` _(write)_

Re-publish a paused ad. Prompts for confirmation.

---

### `haszno shop sold <id> [--price <Ft>]` _(write)_

Mark an ad as sold; optionally record the final sale price. Prompts for confirmation.

---

### `haszno shop renew <id>` _(write)_

Bump an ad back to the top of search results. Prompts for confirmation.

---

### `haszno shop inquiries [--json]` _(read)_

List messages/inquiries received on your ads (seller view).

---

### `haszno shop inquire <adId> --message <text>` _(write)_

Send a message to the seller of an ad. Prompts for confirmation.

---

### `haszno shop favorite <adId>` _(write)_

Save an ad to your favorites. Non-destructive.

---

### `haszno shop unfavorite <adId>` _(write)_

Remove an ad from your favorites.

---

### `haszno shop favorites [--json]` _(read)_

List your favorited ads.

---

### `haszno shop reserve <adId> [--message <text>] [--offer <Ft>] [--phone <tel>] [--yes]` _(write — requires `--yes`)_

Send a reservation request to the seller.

- `--message` — optional note to the seller
- `--offer <Ft>` — counter-offer price (gross HUF)
- `--phone <tel>` — your phone number, revealed to seller only on acceptance

**Reserving is not paying.** Payment and handover happen directly between buyer and
seller. Never say that money was moved via Haszno.

```bash
haszno shop reserve 42 --message "Átveszem Pest határán" --offer 7500 --yes
```

---

### `haszno shop reservations [--as buyer|seller] [--json]` _(read)_

List your reservations. `--as buyer` (default) or `--as seller`.

---

### `haszno shop reservation accept <id> [--held-until <ISO-datetime>]` _(write)_

(Seller) Accept a pending reservation. Optionally set a pick-up deadline with `--held-until`.
Prompts for confirmation.

---

### `haszno shop reservation decline <id>` _(write)_

(Seller) Decline a pending reservation. Prompts for confirmation.

---

### `haszno shop reservation cancel <id>` _(write)_

(Buyer) Cancel your own reservation. Prompts for confirmation.

---

### `haszno shop reservation complete <id> [--price <Ft>]` _(write)_

(Seller) Mark a reservation as completed. Optionally record the final sale price.
Side effect: ad status → `"eladva"`; all other open reservations for the ad →
`"elutasítva"`. Prompts for confirmation.

---

## `haszno account` — Account & settings

### `haszno account stats [--json]`

Dashboard summary: products, losing, overMarket, toFix, orders.

```
$ haszno account stats
Products: 42  Losing: 3  Over market: 1  To fix: 4  Orders: 12
```

---

### `haszno account impact [--days <n>] [--json]`

Profit impact of pricing automation.

```
$ haszno account impact --days 30
Extra profit (30d): 45 200 Ft  |  Gain: +14.1%  |  Orders: 18 (15 auto-forwarded)
```

---

### `haszno account settings [--json]`

Show current pricing rules.

---

### `haszno account settings update --undercut <n> --margin <n> --vat <n>`

Update pricing rules. **Write — prompts for confirmation.**

**Flags:**
- `--undercut <pct>` — undercutPct (0–50)
- `--margin <pct>` — minMarginPct (0–90)
- `--vat <pct>` — vatPct (0–50)

---

### `haszno account suppliers [--json]`

List own configured suppliers.

---

## `haszno products` — Own shop products

### `haszno products list [--all] [--json]`

List products. `--all` includes unlisted.

**JSON output fields:** `id`, `sku`, `name`, `listed`, `priceGross`, `costNet`,
`stock`, `current.marginPct`, `recommended.priceGross`, `marketMinGross`.

```bash
# Find loss-making products:
haszno products list --all --json \
  | jq '[.[] | select(.current.marginPct < 10) | {id,name,sku,marginPct:.current.marginPct}]'
```

---

### `haszno products update <id> [--price <gross>] [--market-min <gross>] [--market-shop <name>]`

Update market data or manual price override. **Write — prompts for confirmation.**

---

### `haszno products list-cmd <id> --listed <true|false>`

List or unlist a product. **Write — prompts for confirmation.**

---

### `haszno products apply-prices [--ids <id,...>]`

Apply recommended prices. **Write — prompts for confirmation.**
Omit `--ids` to apply to all products.

---

### `haszno products describe <id>`

Generate AI product description. **Write — prompts for confirmation.**
Prints the generated text.

---

## `haszno catalog` — Partner catalogue (read-only)

### `haszno catalog suppliers [--json]`

List network suppliers with `id`, `name`, `category`, `country`.

---

### `haszno catalog products <supplierId> [--json]`

List a supplier's catalogue. Fields: `sku`, `name`, `category`,
`wholesaleNet`, `rrpGross`, `stock`, `potentialMargin.marginPct`.

```bash
# Find products with >15% potential margin:
haszno catalog products 3 --json \
  | jq '[.[] | select(.potentialMargin.marginPct > 15) | {sku,name,marginPct:.potentialMargin.marginPct}]'
```

---

### `haszno catalog view <supplierId> [--json]`

Aggregated reseller market view (legal: aggregated only, no individual shop margins).

---

## `haszno proposals` — Price proposals

### `haszno proposals list [--status <pending|approved|rejected>] [--json]`

List price proposals.

```bash
haszno proposals list --status pending --json \
  | jq '{count: length, avgDelta: (map(.proposedPriceGross - .currentPriceGross) | add / length)}'
```

---

### `haszno proposals approve [--ids <id,...>]`

Approve proposals. **Write — prompts for confirmation.**
Omit `--ids` to approve all pending proposals.
The command prints the `batchId` — save it in case rollback is needed.

---

### `haszno proposals reject --ids <id,...>`

Reject specific proposals. **Write — prompts for confirmation.**

---

### `haszno proposals rollback --batch <batchId>`

Roll back an approved batch (restore previous prices). **Write — prompts for confirmation.**

---

## `haszno rules` — Automation rules

### `haszno rules templates [--json]`

List built-in rule templates.

---

### `haszno rules list [--json]`

List all rules with status, trigger, conditions, actions.

---

### `haszno rules create --name <n> --trigger <t> [--template <key>]`

Create a rule interactively or from a template. **Write — prompts for confirmation.**

---

### `haszno rules update <id>`

Update a rule interactively. **Write — prompts for confirmation.**

---

### `haszno rules delete <id>`

Delete a rule permanently. **Write — prompts for confirmation.**

---

### `haszno rules run <id>`

Manually run a single rule. **Write — prompts for confirmation.**
Prints `applied`, `skipped`, `errors`.

---

### `haszno rules run-all`

Run all manual-trigger rules. **Write — prompts for confirmation.**

---

### `haszno rules trigger <name>`

Fire a named event trigger. **Write — prompts for confirmation.**

---

### `haszno rules runs [--limit <n>] [--json]`

Show rule execution log (default last 20 runs).

---

### `haszno rules automation`

Show automation kill switch state (`automationPaused`).

---

### `haszno rules automation pause`

Pause automation (set `automationPaused = true`). **Write — prompts for confirmation.**

---

### `haszno rules automation resume`

Resume automation (set `automationPaused = false`). **Write — prompts for confirmation.**

---

## `haszno orders` — Orders

### `haszno orders list [--json]`

List recent orders (last ~50). Fields: `id`, `externalId`, `status`,
`customerName`, `totalGross`, `createdAt`, `items`.

```bash
# Find stuck orders:
haszno orders list --json | jq '[.[] | select(.status == "error")]'
```

---

### `haszno orders ship <id>`

Mark an order as shipped. **Write — prompts for confirmation.**

---

## `haszno ideas` — Product ideas

### `haszno ideas list [--json]`

AI product idea shortlist (network products scored by trend + margin).

Fields: `sku`, `name`, `costNet`, `supplierName`, `recommended.marginPct`, `trendScore`.

```bash
haszno ideas list --json \
  | jq 'sort_by(-.trendScore) | .[0:10] | .[] | {name, marginPct: .recommended.marginPct, trendScore}'
```

---

### `haszno ideas fill-keywords`

Fill missing trend keywords via AI (batch, may take a minute). **Write — prompts for confirmation.**

---

## `haszno feeds` — Import/export feeds

### `haszno feeds import-supplier --supplier <id> --format <csv|xml> --file <path>`

Import a supplier's product feed from a local file. **Write — prompts for confirmation.**

---

### `haszno feeds import-market --file <path>`

Import competitor market prices from a CSV file. **Write — prompts for confirmation.**

---

## Catalogue search (`haszno catalogue`)

### `haszno catalogue search`

Search the partner product catalogue.

```bash
haszno catalogue search [--q <szöveg>] [--cats <keys>] [--partner <id>]
                         [--min-margin <pct>] [--max-price <ft>] [--min-price <ft>]
                         [--in-stock] [--country <kód>]
                         [--sort margin_desc|price_asc|price_desc|name_asc]
                         [--page <n>] [--page-size <n>]
                         [--json]
```

---

## Import list (`haszno import`)

### `haszno import list`

List items in the import staging list.

```bash
haszno import list [--status varakozik|kuldve|kesz|hiba] [--partner <id>] [--q <text>] [--json]
```

---

### `haszno import add <id> [<id>...]`

Add catalogue products to the import list by their catalogue product IDs.

```bash
haszno import add 101 102 103
```

---

### `haszno import push --ids <ids> [--target <connectionId>] [--yes]`

Push import-list items to the connected webshop. **Write — requires `--yes`.**

Without `--yes` prints a preview of what would happen and exits without calling the API.

**Two paths depending on `--target`:**

- **With `--target <id>`:** calls `POST /api/connect/stores/:id/push` and prints `pushed`, `failed`, and any errors.
- **Without `--target`:** calls `POST /api/import-list/push` and prints `pushed` count only (no `failed`/`errors`).

```bash
# No target — pushes to local product list
haszno import push --ids 5,6,7 --yes

# With target — pushes to connected webshop (e.g. WooCommerce #1)
haszno import push --ids 5,6,7 --target 1 --yes
```

---

## Store connections (`haszno connections`)

### `haszno connections list`

List connected webshop store connections.

```bash
haszno connections list [--status uj|domain_ok|kapcsolva|hiba] [--json]
```

---

## P2P peer invites (`haszno peers`)

### `haszno peers invite --supplier <id> --expires <datetime> [--yes]`

Create an invite code to share a supplier with a partner shop. **Write — requires `--yes`.**

Without `--yes` prints a preview of what would happen and exits non-zero without calling the API.

```bash
# Preview (no API call)
haszno peers invite --supplier 42 --expires 2026-12-31T23:59:00Z

# Create the invite
haszno peers invite --supplier 42 --expires 2026-12-31T23:59:00Z --yes
```

---

### `haszno peers list`

List your own invite codes.

```bash
haszno peers list [--json]
```

---

### `haszno peers accept <code> --acceptor <shop> [--yes]`

Accept a peer invite code. **Write — requires `--yes`.**

```bash
haszno peers accept inv_abc123 --acceptor mybolt --yes
```

---

## Blog / market insights (`haszno blog`)

### `haszno blog latest`

Show the latest market insight blog post(s).

```bash
haszno blog latest [--period het|honap] [--limit <n>] [--json]
```

