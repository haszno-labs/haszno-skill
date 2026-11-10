# Haszno — Agent Integration Guide (Codex / Cursor / headless agents)

This document covers how to integrate Haszno tools into Codex, Cursor, and
other terminal-based or headless agents. For Claude Desktop / Claude Code (MCP),
see `SKILL.md` and `references/tools.md`.

---

## Environment setup

```bash
export HASZNO_API_URL=https://haszno.com   # default
export HASZNO_API_KEY=your-api-key                  # Bearer token
# Legacy fallback (also accepted silently):
# export ARFUTAR_API_URL=...  export ARFUTAR_API_KEY=...
# Config dir: ~/.config/haszno  (falls back to ~/.config/arfutar if present)
# HTTP Basic fallback for the demo:
export HASZNO_BASIC="user:pass"
```

Never echo, log, or hard-code credentials. Read them from the environment only.

---

## CLI usage pattern

```bash
# Install once (via the shared installer):
curl -fsSL https://raw.githubusercontent.com/haszno-labs/haszno-skill/main/install.sh | bash

# Or npm global install:
npm install -g github:haszno-labs/haszno-cli

# Or run without install (auto-fetches latest):
npx -y github:haszno-labs/haszno-cli <command> [--json] [--api-url <url>] [--api-key <key>]
```

Always pass `--json` in agent scripts. Human-readable output is for terminals only.

```bash
# Health check (verify credentials work):
haszno account stats --json

# List loss-making products:
haszno products list --all --json \
  | jq '[.[] | select(.current.marginPct < 10) | {id,name,sku,margin:.current.marginPct}]'

# Daily summary in one pass:
haszno account stats --json && \
haszno rules automation --json && \
haszno proposals list --status pending --json | jq 'length'
```

---

## Safety contract — MUST follow

| Rule | Detail |
|---|---|
| **Read first** | Always fetch the current state before proposing changes. |
| **Show before writing** | Present a summary of what will change; wait for explicit user approval. |
| **Check kill switch** | Before any bulk write: `haszno rules automation --json` → `automationPaused` must be `false`. |
| **Confirm flag** | Every write command prompts `[y/N]`. Never pipe `yes` to bypass this — the user must confirm. |
| **Save batchId** | After `proposals approve`, note the returned `batchId` for rollback. |
| **No negative prices** | All prices are positive whole forints (gross). |
| **Partner view is aggregated** | `haszno catalog view` returns aggregated stats. Do not infer or expose individual shop margins. |
| **Demo is read-mostly** | Against the demo URL, only GETs are safe. Skip write commands unless the user explicitly confirms they want to test a write on demo data. |

---

## Recommended workflows for headless agents

### Morning health check (cron-safe, read-only)

```bash
#!/usr/bin/env bash
set -euo pipefail

STATS=$(haszno account stats --json)
AUTO=$(haszno rules automation --json)
PENDING=$(haszno proposals list --status pending --json | jq 'length')
ERRORS=$(haszno orders list --json | jq '[.[] | select(.status=="error")] | length')
IMPACT=$(haszno account impact --days 7 --json)

echo "Products: $(echo "$STATS" | jq '.products'), Losing: $(echo "$STATS" | jq '.losing')"
echo "Automation: $(echo "$AUTO" | jq '.automationPaused')"
echo "Pending proposals: $PENDING"
echo "Error orders: $ERRORS"
echo "7d extra profit: $(echo "$IMPACT" | jq '.extraProfit') Ft (+$(echo "$IMPACT" | jq '.pctGain')%)"
```

### Approve proposals (requires user confirmation via prompt)

```bash
# Preview:
haszno proposals list --status pending --json \
  | jq '{count: length, avgDelta: (map(.proposedPriceGross - .currentPriceGross) | add / length | floor)}'

# Approve (CLI will prompt [y/N] — do not auto-confirm):
haszno proposals approve
```

### Find and report loss-making products

```bash
MIN_MARGIN=$(haszno account settings --json | jq '.minMarginPct')
haszno products list --all --json \
  | jq --argjson m "$MIN_MARGIN" \
       '[.[] | select(.current.marginPct < $m) | {id,name,sku,margin:.current.marginPct,fix:.recommended.priceGross}]'
```

---

## TypeScript / Node.js integration

If you need programmatic access (not just shell scripts), the HTTP client is
vendored inside `@haszno/cli` and `@haszno/mcp`. For direct use:

```typescript
// The client reads HASZNO_API_URL + HASZNO_API_KEY from process.env
// (falls back to ARFUTAR_API_URL / ARFUTAR_API_KEY silently)
const stats = await client.stats.get()
const products = await client.products.list({ all: true })
const losers = products.filter(p => p.current.marginPct < stats.minMarginPct)
```

The client throws `HasznoApiError` on 4xx/5xx with a Hungarian message in `error.message`.
5xx and 429 responses are retried automatically with exponential back-off.

---

## Codex / Cursor — AGENTS.md snippet

Paste this block into the project's `AGENTS.md` or `CURSOR.md` to give your agent
context about Haszno tools:

```markdown
## Haszno dropshipping tools

This project uses the Haszno SaaS (haszno.hu) for dropshipping pricing automation.
CLI: `haszno` (from `@haszno/cli`). MCP: `haszno_*` tools.
Auth: `HASZNO_API_URL`, `HASZNO_API_KEY` env vars.

**Safety rules (non-negotiable):**
- Read-only by default. Fetch state before proposing any change.
- Every write command (`approve`, `reject`, `rollback`, `run`, `list-cmd`, `apply-prices`,
  `import-*`, `settings update`) requires explicit user confirmation — never auto-confirm.
- Check `haszno rules automation --json` before bulk writes; stop if `automationPaused: true`.
- Save `batchId` from approve operations for potential rollback.
- Partner catalogue (`haszno catalog view`) shows aggregated stats only.

**Common read operations:**
  haszno account stats --json          # dashboard: losing, toFix counts
  haszno products list --all --json    # all products + margins
  haszno proposals list --status pending --json
  haszno orders list --json
  haszno ideas list --json

Full tool reference: skills/haszno/references/tools.md (MCP)
                     skills/haszno/references/commands.md (CLI)
Workflow recipes:    skills/haszno/references/recipes.md
```

---

## MCP server configuration

For Claude Desktop / Claude Code (not Codex/Cursor):

```bash
# One-line register (after install.sh):
claude mcp add haszno --scope user -- node ~/.haszno/haszno-mcp/dist/index.js
```

Or set env-based `npx` variant in `claude_desktop_config.json` / `.claude/settings.json`:

```json
{
  "mcpServers": {
    "haszno": {
      "command": "node",
      "args": ["~/.haszno/haszno-mcp/dist/index.js"],
      "env": {
        "HASZNO_API_URL": "https://haszno.com",
        "HASZNO_API_KEY": "your-api-key"
      }
    }
  }
}
```

After connecting, use the `haszno_*` tools. Full list: `references/tools.md`.
