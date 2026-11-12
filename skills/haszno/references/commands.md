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


---

## Napi piaci menedzser (`haszno report`, `haszno research`, `haszno actions`)

Agent-facing commands. All require a valid per-shop Bearer token (`HASZNO_API_KEY=haszno_...`).
Write commands (`haszno research post`, `haszno actions propose`) require a write-scope token.
Approve and undo are intentionally NOT available in the CLI — these are human decisions made in the Haszno UI at `/app/napi-jelentes`.

---

### `haszno report [--day YYYY-MM-DD]`

Display the daily market report (latest by default).

```bash
haszno report [--day 2026-11-12] [--json]
```

- Without `--day`: fetches the most recent report (`GET /api/agent/daily-report`)
- With `--day`: fetches the report for a specific day (`GET /api/agent/daily-report/:day`)

**Returns:** Pretty-printed report with items grouped by kind; `--json` returns raw `DailyReport`.

---

### `haszno research brief`

Display today's research brief: shop focus products/keywords, prices, trend indicators, and research questions.

```bash
haszno research brief [--json]
```

Calls `GET /api/agent/research-brief`. Returns `ResearchBrief { day, shopFocus[], questions[], postTo }`.

---

### `haszno research post [--day YYYY-MM-DD] <file.json | ->`

Post agent research findings to the daily report. Items appear as `origin: "agent"`.

```bash
# From file:
haszno research post --day 2026-11-12 /path/to/findings.json

# From stdin:
cat findings.json | haszno research post -

# Without --day: defaults to today (UTC)
haszno research post findings.json
```

The file must contain a valid `FindingsInput` JSON object: `{ headline?, summary?, items: FindingInput[] }`.

Calls `POST /api/agent/daily-report/:day/findings`. Max 20 items per call; max 60 agent items per day.

---

### `haszno actions list [--status <s>] [--limit <n>]`

List the shop's agent actions (newest first).

```bash
haszno actions list [--status javasolt|vegrehajtva|elutasitva|hiba|visszavonva] [--limit 50] [--json]
```

Calls `GET /api/agent/actions?status=&limit=`. Default limit: 50, max: 200.

---

### `haszno actions propose --type <t> --reason <text> [options]`

Propose a new agent action for the shop owner to review.

```bash
# Propose a price change:
haszno actions propose \
  --type ar \
  --product-id 112 \
  --price 206000 \
  --reason "A piaci minimum emelkedett (Árukereső.hu, 2026-11-12)." \
  [--report-item 47]

# Propose listing a product:
haszno actions propose --type felvetel --product-id 55 --reason "Trendelő termék."

# Propose removing a product:
haszno actions propose --type levetel --product-id 33 --reason "Tartósan kifogyott."

# Propose adding a network product to the import list:
haszno actions propose --type import --network-product-id 999 --reason "Releváns kategória."
```

Options:
- `--type` _(required)_: `felvetel | levetel | ar | import`
- `--product-id <id>` _(required for felvetel, levetel, ar)_
- `--network-product-id <id>` _(required for import)_
- `--price <gross>` _(required for ar)_: bruttó ár forintban
- `--reason <text>` _(required)_: 5–500 chars
- `--report-item <id>` _(optional)_: link to a report item ID

Calls `POST /api/agent/actions`. Returns the new `AgentAction`.

**Note:** The proposed action is NOT executed immediately. Approval must happen in the Haszno UI at `/app/napi-jelentes`.
