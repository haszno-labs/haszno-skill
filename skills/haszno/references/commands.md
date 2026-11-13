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
`--city <város>`, `--min-price <Ft>`, `--max-price <Ft>`,
`--sort <newest|price_asc|price_desc>`, `--page <n>`

```bash
haszno shop search "iPhone 14" --max-price 200000 --json \
  | jq '.[] | {id, title, priceGross, condition, county}'
```

---

### `haszno shop show <id> [--json]` _(read)_

Show full ad detail. Contact fields (`sellerPhone`, `sellerEmail`) are populated only
when you have an accepted reservation for that ad.

---

### `haszno shop price-hint [--json]` _(read)_

Get an AI price suggestion. **Flags:** `--category <key>`, `--subcategory <key>`.
Always label the result as a suggestion.

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
| `--condition <állapot>` | yes | `uj` \| `ujszeru` \| `hasznalt` \| `serult` |
| `--description <text>` | — | Free-text description |
| `--county <megye>` | yes | County (Pest, Győr-Moson-Sopron, …) |
| `--city <varos>` | yes | City / settlement |
| `--attr key=value` | — | Category-specific attribute (repeatable) |
| `--image <file>` | — | Attach image (repeatable, up to 10) |
| `--contact-name <name>` | yes | Contact name shown to buyer |
| `--contact-email <email>` | yes | Contact e-mail address |
| `--contact-phone <tel>` | — | Phone revealed to buyer only after acceptance |
| `--show-phone` | — | Allow buyer to see phone after acceptance |
| `--resellable` | — | Allow partner shops to list this ad in their webshops |
| `--commission-pct <szám>` | — | Partner reseller commission % (default 0) |
| `--from-photos` | — | AI-suggest title/description/category from `--image` files |
| `--dry-run` | — | Preview only — does not call API |
| `--yes` | required | Skip confirmation prompt |

```bash
# Dry-run preview:
haszno shop post --title "Ikea Billy könyvespolc" --category butor \
  --price 8000 --condition hasznalt --county Budapest --city Óbuda \
  --contact-name "Kovács Anna" --contact-email "anna@example.com" --dry-run

# Actual post:
haszno shop post --title "Ikea Billy könyvespolc" --category butor \
  --price 8000 --condition hasznalt --county Budapest --city Óbuda \
  --contact-name "Kovács Anna" --contact-email "anna@example.com" --yes
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

### `haszno shop inquire <adId> --name <név> --email <email> --message <text>` _(write)_

Send a message to the seller of an ad. Prompts for confirmation.

**Flags:** `--name <név>` (required), `--email <email>` (required),
`--phone <telefon>` (optional), `--message <text>` (required)

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
`"elutasítva"`. Prompts for confirmation. (Note: there is no `--yes` flag for this
command — always prompts interactively.)

---

### `haszno shop reservation counter <id> --price <Ft>` _(write)_

(Seller) Send a counter-offer price on a pending (`"fuggoben"`) reservation.
`--price` is required (HUF gross, must be a positive integer).
Always show the amount to the user and confirm before running — a counter-offer is
immediately visible to the buyer.
Prompts for confirmation.

---

### `haszno shop reservation accept-counter <id>` _(write)_

(Buyer) Accept the seller's active counter-offer on a pending reservation.
After acceptance the reservation remains `"fuggoben"` — the seller still needs to
formally accept. Prompts for confirmation.

Errors: 409 if no active counter-offer exists.

---

### `haszno shop reservation messages <id> [--json]` _(read)_

List the message thread for a reservation. Both buyer and seller can read.
Messages are shown oldest-first.

---

### `haszno shop reservation message <id> --text <szöveg>` _(write)_

Send a free-text message on a reservation thread.
`--text` is required (1–2000 characters).

**Never put the user's phone number or e-mail into the message body on their
behalf without asking.** Use the dedicated contact fields instead.

Rate-limited: 20 messages per hour.

---

### `haszno shop reservation review <id> --rating <1-5> [--comment <szöveg>]` _(write)_

Leave a review on a completed (`"teljesitve"`) reservation.
`--rating` is required (integer 1–5). `--comment` is optional (max 1000 chars).
Always show the rating and comment to the user and confirm — a review is permanent.
Prompts for confirmation.

Errors: 409 if the reservation is not `"teljesitve"` or already reviewed.

---

### `haszno shop inquiry reply <id> --message <szöveg>` _(write)_

(Seller) Reply to an inquiry from a buyer. `--message` is required (1–2000 chars).
Each inquiry accepts exactly one reply.

**Never put the user's phone number or e-mail into the reply body on their
behalf without asking.**

Errors: 409 if the inquiry already has a reply.

---

### `haszno shop saved-search list [--json]` _(read)_

List your saved searches with their filters and alert settings.

---

### `haszno shop saved-search add --name <név> [filters] [--no-alert]` _(write)_

Create a new saved search with optional e-mail alerts (alerts are **on** by default).
`--name` is required. Use `--no-alert` to disable e-mail notifications.

**Filter flags** (same as `haszno shop search`):

| Flag | Description |
|---|---|
| `--query <szöveg>` | Free-text search query |
| `--category <id>` | Category key |
| `--subcategory <id>` | Subcategory key |
| `--min-price <Ft>` | Minimum price (HUF gross) |
| `--max-price <Ft>` | Maximum price (HUF gross) |
| `--county <megye>` | County |
| `--condition <állapot>` | `uj` \| `ujszeru` \| `hasznalt` \| `serult` |

Errors: 422 if the 20 saved-search cap is reached.

```bash
haszno shop saved-search add --name "Túrakerékpár <50 000 Ft" \
  --query "túrakerékpár" --max-price 50000 --condition hasznalt
```

---

### `haszno shop saved-search remove <id>` _(write)_

Delete a saved search by ID. Idempotent.

---

### `haszno shop watch <adId>` _(write)_

Subscribe to price-drop e-mail alerts for a specific active ad.
The ad must be `"aktiv"`.

---

### `haszno shop unwatch <adId>` _(write)_

Unsubscribe from price-drop alerts for an ad. Idempotent.

---

### `haszno shop import-url <url> [--post] [--yes]` _(read / write)_

Fetch an external product page and extract its metadata (title, description, price, images)
as a pre-filled ad draft. **Never posts without `--post`.**

| Flag | Description |
|---|---|
| _(none)_ | Print extracted data only — no ad is created |
| `--post` | Also attempt to create an ad from the extracted data (interactively confirms unless `--yes`) |
| `--yes` | Skip confirmation when used with `--post` |

```bash
# Extract only (safe to run without confirmation):
haszno shop import-url "https://jofogasoldal.hu/ajanlat/12345"

# Extract and post (confirms unless --yes):
haszno shop import-url "https://jofogasoldal.hu/ajanlat/12345" --post
```

---

### `haszno shop draft show [--json]` _(read)_

Show the current server-side ad creation draft.

---

### `haszno shop draft save` _(write)_

Save a draft from JSON piped on stdin (upsert, max 64 KB).

```bash
echo '{"title":"Ikea Billy","priceGross":8000}' | haszno shop draft save
```

---

### `haszno shop draft clear` _(write)_

Delete the current ad creation draft. Idempotent.

---

### `haszno shop post --remove-bg` _(flag for `shop post`)_

When passed alongside `--image` files, runs AI background removal on each uploaded
image before creating the ad. The original images are preserved; the processed
versions are used in the ad.

```bash
haszno shop post --image product.jpg --remove-bg \
  --title "Fehér konyhai szék" --category butor \
  --price 5000 --condition hasznalt --county Budapest --city Óbuda \
  --contact-name "Kovács Anna" --contact-email "anna@example.com" --yes
```

---

### `haszno shop post-bulk <forrás> [--from-photos] [--dry-run] [--yes]` _(write)_

Post multiple ads from a CSV file or a folder of subdirectories.

| Mode | Trigger | Behaviour |
|---|---|---|
| CSV | `<forrás>` ends in `.csv` or is a file | Reads rows from the CSV; each row becomes one ad |
| Könyvtár | `<forrás>` is a directory (or `--from-photos`) | Each subdirectory = one ad; images are uploaded and AI fills in the metadata |

**CSV column names** (must match exactly):
`title, category, subcategory, price, negotiable, condition, description, county, city, contact_name, contact_phone, contact_email, show_phone, images`

| Flag | Description |
|---|---|
| `--from-photos` | Force directory mode even if source looks like a file |
| `--dry-run` | Print a preview table, do not call API |
| `--yes` | Skip per-batch confirmation (required for live posting) |

**Golden rule: always run `--dry-run` first. Show the preview to the user and
get an explicit "yes" before posting. Stops on the first error.**

```bash
# CSV mode — preview only:
haszno shop post-bulk ads.csv --dry-run

# Directory mode — post for real (each subdir must contain image files):
haszno shop post-bulk ./photos --from-photos --yes
```

---

### `haszno shop delete <id>` _(write)_

Permanently delete an ad. Irreversible. Prompts for confirmation.

---

## `haszno tokens` — API token management

### `haszno tokens list [--json]` _(read — session auth required)_

List active API tokens for the current account.
Requires session-based authentication (not a Bearer token) — only usable in
environments with cookie/session support.

**Output fields:** `id, name, scope, createdAt, lastUsedAt, expiresAt`

---

### `haszno tokens revoke <id>` _(write — session auth required)_

Revoke an API token by its ID.
Requires session-based authentication.

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

