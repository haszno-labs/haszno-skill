# Haszno CLI Command Reference

Install / run:
```bash
npm install -g @haszno/cli    # global install
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
