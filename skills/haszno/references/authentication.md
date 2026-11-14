# Haszno — Authentication & Credential Modes

> Source of truth: `api/src/auth/tokens.ts`, `api/src/vercel.ts`, `api/src/app.ts`.
> Every claim below is verified against the capability map at
> `/tmp/.../scratchpad/agent-capability-map.md` (generated from origin/main of Webu-PRO/arfutar).

---

## Four credential modes

### Mode 1 — Per-shop Bearer token (`Authorization: Bearer haszno_…`)

The agent/MCP/CLI mode. Used for programmatic access to a single shop's data.

**Format:** `haszno_<43 chars base64url>`  
**Env vars:** `HASZNO_API_TOKEN` (preferred) or `HASZNO_API_KEY`  
**Config file:** `~/.config/haszno/config.json` → `{ "apiKey": "haszno_…" }`  
**Target:** `https://haszno.com` only (not self-hosted deployments, see mode 2)

**Scopes:**
- `read` — GET/HEAD/OPTIONS only; write-method requests → 403
- `write` — all methods; also required for `POST /api/agent/proposals`

**Token limits:**
- Max 25 active tokens per shop
- Default expiry: 90 days; max: 365 days; `null` = no expiry
- Issued in the web app (Settings → API-kulcsok); creation requires a human session

**What per-shop Bearer tokens can reach:**

| Route | Scope |
|---|---|
| `GET /api/v1/auth/me` | any |
| `POST /api/v1/auth/tokens/revoke-current` | any |
| `GET /api/v1/agent/products` | read |
| `GET /api/v1/agent/orders` | read |
| `GET /api/v1/agent/proposals` | read |
| `POST /api/v1/agent/proposals` | write |
| `POST /api/v1/mcp` (hosted MCP) | depends on tool |
| `/api/v1/shop/*` (marketplace) | read/write per route |

**What they CANNOT reach (403 or gate falls through):**
- `/api/v1/catalogue/products`, `/api/v1/import-list/*` — `isSessionAllowedPath`, outer gate rejects
- `/api/v1/billing/*`, `/api/v1/chat/*`, `/api/v1/team/*` — session-only
- `POST /api/v1/proposals/approve|reject|rollback` — permanently blocked (`rejectBearerOnApproval` middleware)
- `/api/v1/rules/*`, `/api/v1/feeds/*` — HTTP Basic wall (self-hosted `x-api-key` guard)
- Order management beyond last-20 read — no agent route exists

**Rate limiting on auth failures:**
- `/api/agent/*`: 20 failed Bearer attempts per IP per 15 min → 429
- `/api/mcp`: same 20/15-min cap

---

### Mode 2 — Self-hosted shared key (`x-api-key` header)

For self-hosted Haszno instances. Set `HASZNO_API_KEY` (or legacy `ARFUTAR_API_KEY`) env var on the server.  
Every endpoint is accessible (no `isSessionAllowedPath` gate on self-hosted).  
Bearer tokens in `/api/agent/*` and `/api/mcp` are exempt from the `x-api-key` check.

**Feed exception:** `GET /feed/*` also accepts `?api_key=<value>` query param (no other route does).

---

### Mode 3 — HTTP Basic (`Authorization: Basic <base64(demo:password)>`)

For the hosted demo dataset on `haszno.com`.  
`username=demo`, `password` = `DEMO_PASSWORD` env var on the server.  
Provides read/write access to a **shared synthetic demo dataset** — not live shop data.  
The CLI/MCP reads this from `HASZNO_BASIC="demo:password"`.

Failure response:
```json
{ "error": "A demóadatok megtekintéséhez hitelesítés szükséges.", "demo": true }
```
(status 401; the `demo: true` field tells the web app to show a sample instead of an error screen)

---

### Mode 4 — Session cookie (`haszno_session`)

Human-only. Created by `POST /api/v1/auth/login` or `POST /api/v1/auth/register`.

**Required for:**
- Approving / rejecting / rolling back proposals
- Billing, team management
- Creating / listing / revoking tokens
- GDPR export / erasure
- Webshop wizard, reseller-pricing, chat
- Abandoned-cart token rotation

> **Never attempt session-only routes from agent code.** These are behind `isSessionAllowedPath`
> checks in the hosted Vercel entry — a Bearer token falls through to the Basic-auth gate
> and receives 401 or 403.

---

## Credential resolution order (CLI and MCP)

1. `HASZNO_API_TOKEN` — preferred for per-shop Bearer tokens
2. `HASZNO_API_KEY` / `ARFUTAR_API_KEY` — also accepted (shop token or legacy key)
3. `~/.config/haszno/config.json` — written by `haszno login` or `haszno_account_configure`
4. `~/.config/arfutar/config.json` — silent backwards-compatibility

The token starting with `haszno_` selects per-shop Bearer mode automatically.
Any other credential (plain string, `x-api-key`) selects legacy/full-access mode.

---

## `haszno login` — CLI mint

`POST /api/v1/auth/cli-login` — one step: verifies password, mints a write-scope Bearer token (90-day expiry).  
Returns `{ token, scope: "write", user: { email, name, shopName } }`.  
Rate-limited: 30 attempts/IP/15 min; 10 attempts/email/15 min.

---

## Credential reach summary

| Credential | `/api/agent/*` | `/api/mcp` | `/api/shop/*` | `/api/auth/me` | Import-list | Billing | Rules/Feeds |
|---|---|---|---|---|---|---|---|
| Bearer `haszno_…` | ✅ scope-gated | ✅ scope-gated | ✅ scope-gated | ✅ | ❌ | ❌ | ❌ |
| HTTP Basic (`demo:pw`) | ✅ (demo data) | ❌ | ✅ (demo data) | ✅ | ✅ (demo) | ✅ (demo) | ✅ |
| `x-api-key` (self-hosted) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Session cookie | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |

Bearer tokens are the **only way to get real per-shop data programmatically** on `haszno.com`.
HTTP Basic provides the synthetic demo dataset, not live shop data.

---

## Diagnosing a 401 or 403

| Symptom | Likely cause | Fix |
|---|---|---|
| `401 unauthenticated` on `/api/agent/*` | Token expired, revoked, or format wrong | Reissue token in web app |
| `403 forbidden` on `POST /api/agent/proposals` | Using `read`-scope token | Reissue with `write` scope |
| `403 "Az ügynök-token nem hagyhat jóvá árjavaslatokat."` | Calling approve/reject/rollback with Bearer | Use web UI or legacy key |
| `401 demo` with `demo: true` | Missing HTTP Basic on haszno.com route | Set `HASZNO_BASIC` |
| `403 seller_type_required` | Trying to syndicate a partner ad as `maganszemely` | Shop must be `kereskedo` type |
| `429 rate_limited` | Too many failed auth attempts (20/15 min) | Wait 15 min; check token format |
| `401` on `isSessionAllowedPath` route | Called session-only route with Bearer | Use web UI; this endpoint is not agent-accessible |

---

## Version and API path

- `/api/v1/<path>` = canonical form; unversioned `/api/<path>` is accepted but adds `Deprecation: true` header.
- `GET /api/v1` (no auth) → `{ current: "v1", supported: ["v1"] }`
- Every response includes `X-Request-Id` (echo of `X-Request-Id` request header if sent, else server-generated).
- Error bodies: `{ error: string, code: string, requestId: string }` — machine-readable `code`, Hungarian `error` by default; `Accept-Language: en` returns English.
