---
name: haszno
description: >
  Work with Haszno dropshipping data: query partner catalogue, review and approve
  price proposals, manage automation rules, check orders, find new product ideas,
  connect webshops (bolt-bekötés), manage P2P peer partner invites, read
  aggregated market blog posts, run daily market research (napi piaci kutatás),
  post agent findings to the daily report, propose and approve agent actions,
  and manage autopilot settings. Use when the user mentions Haszno, dropshipping
  pricing, price proposals (árajánlat), automation rules (automatika), product
  margins, Árukereső feed, supplier catalogue, connecting a webshop (bekötés,
  WooCommerce, Shopify), import list (import lista), push products to shop
  (termékek kiküldése), partner invite (meghívó), peer link (partner kapcsolat),
  daily report (napi jelentés), agent actions (ügynök javaslat, jóváhagyás),
  autopilot, or asks to run a daily dropshipping or market research check.
  Also triggers on: approve proposals, reject proposals, run rule, margin check,
  veszteséges termékek, árazás automatizálás, partnerkatekógus, termékötlet,
  dropshipping ügynök, bolt-bekötés, barát meghívása, beszállító katalógus,
  heti összefoglaló, napi kutatás, menedzser.
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
  - napi jelentes
  - napi kutatás
  - piaci kutatás
  - daily market research
  - napi piaci jelentes
  - agent javaslat
  - jóváhagyás
  - autopilot
  - menedzser
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
8. **Agent actions are propose-only.** An agent (Bearer `haszno_…` token) may
   call `POST /api/agent/actions` to propose an action, and `POST …/:id/reject`.
   It may NOT call `/approve`, `/undo`, or `PUT /api/agent/autopilot` — these
   return 403. The owner approves in the UI at `/app/napi-jelentes`.
9. **Antitrust rule.** Every report item and action proposal must be computed
   from THIS shop's own data plus publicly available market prices only. Never
   use or expose another reseller's prices, costs, or rules — even indirectly.

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

### 6 — Napi piaci kutatás (daily market research)

Goal: post agent-side market findings and action proposals to the daily report.

```
1. haszno_research_brief
   → day, shopFocus[], questions[], postTo

2. For each question in questions[]:
   - Web search (public sources only — no other resellers' private data)
   - Verify every fact against its source URL before including it

3. haszno_post_findings(day, headline, summary, items[3–10])
   → DailyReport (confirms items persisted with origin="agent")

4. haszno_propose_action(type, payload, reason, reportItemId) × ≤5
   → AgentAction { status: "javasolt" }
      (may be "vegrehajtva" if autopilot auto-ran it — check the response)

5. Tell the owner: N findings posted, M actions await approval at /app/napi-jelentes
```

**Agent rules for this workflow:**
- Never fabricate source URLs or prices. If you cannot verify, omit the number.
- Never say an action was "executed" unless the server returned `status: "vegrehajtva"`.
- Never use another shop's prices, margins, or rules as an input or source.
- POST `/api/agent/actions` only — `/approve`, `/undo`, and autopilot PUT are
  blocked for API tokens (403). Approval is for humans.
- An `'ar'` action is refused (400) if the product has no known cost — do not retry.

Full step-by-step: **[Recipe 9 in references/recipes.md](references/recipes.md)**

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
| `manager` | `haszno_daily_report`, `haszno_research_brief`, `haszno_list_actions` | `haszno_post_findings` (agent findings), `haszno_propose_action` (propose only — no confirm flag; never self-approve), `haszno_withdraw_action` (withdraw own proposal) |
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
