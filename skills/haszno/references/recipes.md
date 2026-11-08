# Haszno — Workflow Recipes

Practical step-by-step recipes for common agent workflows.
Each recipe lists the MCP tool sequence and the equivalent CLI one-liner.

> **Eszközválasztás:** Ha az MCP szerver csatlakoztatva van (`haszno_*` eszközök
> elérhetők), mindig azt részesítsd előnyben. Ha nincs MCP, a `haszno` CLI-t
> használd fallbackként.

---

## Recipe 1: Daily dropshipping health check

Run this every morning to surface the most important issues quickly.

### MCP sequence

```
1. haszno_account_get_stats
   → note: products, losing, overMarket, toFix, orders

2. haszno_automation_get
   → check automationPaused (should be false)

3. haszno_proposals_list(status="pending")
   → count pending proposals; preview top 5 by price delta

4. haszno_orders_list
   → find any with status="error"

5. haszno_account_get_impact(days=7)
   → extraProfit, pctGain for the week
```

### CLI equivalent

```bash
echo "=== STATS ===" && haszno account stats --json
echo "=== AUTOMATION ===" && haszno rules automation --json
echo "=== PROPOSALS ===" && haszno proposals list --status pending --json | jq 'length'
echo "=== STUCK ORDERS ===" && haszno orders list --json | jq '[.[] | select(.status == "error")]'
echo "=== IMPACT (7d) ===" && haszno account impact --days 7 --json
```

### What to report to the user

> "Health: 42 products, 3 veszteséges (losing). Automation: active.
>  12 pending proposals (+avg 320 Ft/db). 0 stuck orders.
>  Extra profit this week: +8 400 Ft (+9.2%)."

Then ask which item to drill into.

---

## Recipe 2: Find and fix loss-making products

### Step 1 — identify

```bash
# CLI: products below 10% margin
haszno products list --all --json \
  | jq '[.[] | select(.current.marginPct < 10) | {id,name,sku,margin: .current.marginPct,recommended: .recommended.priceGross}]'
```

MCP: call `haszno_products_list(all=true)`, filter client-side on `current.marginPct < settings.minMarginPct`.

### Step 2 — present to user

Show a table: `name | SKU | current margin% | recommended price | market minimum`.
Never auto-fix. Ask: "Apply recommended prices to these N products?"

### Step 3 — apply (if user approves)

**MCP:**
```
haszno_products_apply_prices(ids=[1, 2, 3], confirm=true)
```

**CLI:**
```bash
haszno products apply-prices --ids 1,2,3
# CLI will prompt: "Apply recommended prices to 3 products? [y/N]"
```

### Step 4 — verify

Re-run `haszno_products_list` for the same ids and confirm margins improved.

---

## Recipe 3: Review and batch-approve price proposals

### Step 1 — check kill switch

**MCP:** `haszno_automation_get` — verify `automationPaused: false`.
If `true`: report to user, do not proceed.

### Step 2 — list pending proposals

**MCP:** `haszno_proposals_list(status="pending")`
**CLI:** `haszno proposals list --status pending --json`

Compute and show:
- Count
- Average price change (Ft and %)
- Largest individual increase / decrease
- Any proposal that would push margin below `minMarginPct`

### Step 3 — user confirms

Do NOT call approve until the user explicitly says yes.
Recommended phrasing: "Approve all 12 proposals? The largest change is +580 Ft on 'Párásító deluxe'."

### Step 4 — approve

**MCP:** `haszno_proposals_approve(confirm=true)` _(or pass specific `ids`)_
**CLI:** `haszno proposals approve`

Save the returned `batchId`.

### Step 5 — save batchId for rollback

Tell the user: "Approved. batchId: `abc-123`. Use `proposals rollback --batch abc-123` to undo."

### Step 6 — rollback if needed

**MCP:** `haszno_proposals_rollback(batchId="abc-123", confirm=true)`
**CLI:** `haszno proposals rollback --batch abc-123`

---

## Recipe 4: Pick new products to list from a supplier

### Step 1 — list suppliers

**MCP:** `haszno_catalog_list_suppliers`
**CLI:** `haszno catalog suppliers --json`

Ask the user which supplier (or category) to browse.

### Step 2 — fetch catalogue

**MCP:** `haszno_catalog_get_products(supplierId=<id>)`
**CLI:** `haszno catalog products <id> --json`

### Step 3 — filter candidates

Criteria (adjust per user preference):
- `stock > 0`
- `potentialMargin.marginPct >= minMarginPct` (from settings)
- Not already listed: cross-check SKUs against `haszno_products_list(all=true)`

```bash
LISTED=$(haszno products list --all --json | jq -r '.[].sku' | sort)
haszno catalog products 3 --json \
  | jq --argjson min 10 '[.[] | select(.stock > 0 and .potentialMargin.marginPct >= $min)]' \
  | grep -vFf <(echo "$LISTED")   # remove already-listed SKUs
```

### Step 4 — enrich with market view (optional)

**MCP:** `haszno_catalog_supplier_view(supplierId=<id>)`

The `resellerCount` and `saturation` fields show how crowded a product is. Low saturation = less competition.

### Step 5 — present shortlist

Show top 10 by `potentialMargin.marginPct`, including `resellerCount` if available.
Ask: "List these N products?"

### Step 6 — list approved products

For each product id the user approves:
**MCP:** `haszno_products_set_listing(id=<id>, listed=true, confirm=true)`
**CLI:** `haszno products list-cmd <id> --listed true`

---

## Recipe 5: Create a margin-guard automation rule

Goal: auto-generate proposals whenever a product's margin drops below 8%.

### Step 1 — browse templates

**MCP:** `haszno_rules_list_templates`
**CLI:** `haszno rules templates --json`

Look for a template with `key` like `"margin_guard"` or `"low_margin"`.

### Step 2 — create rule

**MCP:**
```
haszno_rules_create(
  name="Margin guard <8%",
  trigger="market_update",
  conditions=[{ field: "current.marginPct", op: "lt", value: 8 }],
  actions=[{ type: "generate_proposal" }],
  confirm=true
)
```

**CLI:** `haszno rules create --name "Margin guard <8%" --trigger market_update`
(interactive prompts for conditions and actions, or `--template <key>`)

### Step 3 — verify

**MCP:** `haszno_rules_list` — confirm the new rule appears with `enabled: true`.

### Step 4 — test-run (optional)

**MCP:** `haszno_rules_run(id=<newRuleId>, confirm=true)`
**CLI:** `haszno rules run <id>`

Then `haszno_proposals_list(status="pending")` to see what it generated.

---

## Recipe 6: Catch and retry stuck orders

### Step 1 — find stuck orders

**MCP:** `haszno_orders_list`
**CLI:** `haszno orders list --json | jq '[.[] | select(.status == "error")]'`

### Step 2 — inspect events

Each `Order` has an `events` array with timestamped log entries. Show them to the user.

### Step 3 — ship manually (if supplier confirmed shipment out-of-band)

**MCP:** `haszno_orders_ship(id=<id>, confirm=true)`
**CLI:** `haszno orders ship <id>`

---

## Recipe 7: Import a fresh supplier feed

Use when a supplier emails a new price/stock CSV.

### Step 1 — save the file locally, e.g. `/tmp/supplier42.csv`

### Step 2 — import

**CLI:**
```bash
haszno feeds import-supplier --supplier 42 --format csv --file /tmp/supplier42.csv
```

**MCP:** `haszno_feeds_import_supplier(supplierId=42, format="csv", content=<file content>, confirm=true)`

### Step 3 — check results

Report `created`, `updated`, `total` from the response.

### Step 4 — trigger market-update rule (optional)

```bash
haszno rules trigger market_update
```

This runs any rules subscribed to the `market_update` trigger, potentially generating
new proposals for products whose costs changed.

---

## Recipe 8: Weekly product idea review

### Step 1 — fetch shortlist

**MCP:** `haszno_ideas_list`
**CLI:** `haszno ideas list --json | jq 'sort_by(-.trendScore) | .[0:10]'`

### Step 2 — fill missing trend keywords (if many are null)

**MCP:** `haszno_ideas_fill_keywords(confirm=true)` — batch AI call, may take 30–60s.
**CLI:** `haszno ideas fill-keywords`

### Step 3 — enrich with catalogue data

For top ideas, call `haszno_catalog_get_products(supplierId=<id>)` to confirm stock and
exact wholesale price.

### Step 4 — cross-check market saturation

Call `haszno_catalog_supplier_view(supplierId=<id>)` for a product's `resellerCount`
and `saturation`. Prefer products with `saturation < 0.4` (less crowded market).

### Step 5 — present and list

Same as Recipe 4, steps 5–6.

---

## Jq cheatsheet for CLI pipelines

```bash
# Loss-making products (margin < 10%)
haszno products list --all --json \
  | jq '[.[] | select(.current.marginPct < 10) | {id,name,sku,m:.current.marginPct,rec:.recommended.priceGross}]'

# Products over market price
haszno products list --json \
  | jq '[.[] | select(.marketMinGross != null and .priceGross > .marketMinGross)]'

# Pending proposals summary
haszno proposals list --status pending --json \
  | jq '{count:length, avgDelta:(map(.proposedPriceGross - .currentPriceGross) | add / length | floor)}'

# Top 10 ideas by trend score
haszno ideas list --json \
  | jq 'sort_by(-.trendScore) | .[0:10] | .[] | {name,m:.recommended.marginPct,ts:.trendScore}'

# Catalogue: potential margin > 15%, in stock
haszno catalog products <id> --json \
  | jq '[.[] | select(.stock > 0 and .potentialMargin.marginPct > 15) | {sku,name,m:.potentialMargin.marginPct}]'

# Orders stuck in error
haszno orders list --json | jq '[.[] | select(.status=="error") | {id,externalId,customerName}]'
```
