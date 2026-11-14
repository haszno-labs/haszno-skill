# Haszno — Error Codes, Recovery, and Diagnosis

> Source: `api/src/versioning.ts:133-168`, `api/src/agent/routes.ts`, capability map.

---

## Error envelope

Every response with status ≥ 400 contains:

```jsonc
{
  "error": "Hungarian error message",   // human-readable; "en" available via Accept-Language: en
  "code": "machine_readable_code",
  "requestId": "req_abc123"             // echoes X-Request-Id if sent; use for support
}
```

Send `Accept-Language: en` to get English error strings.

---

## HTTP status codes and their `code` values

| HTTP | `code` | Typical cause |
|---|---|---|
| 400 | `invalid_request` | Missing/malformed body field, wrong Content-Type, non-integer price |
| 401 | `unauthenticated` | Missing, expired, or revoked token |
| 403 | `forbidden` | Scope mismatch, `rejectBearerOnApproval`, `seller_type_required` |
| 404 | `not_found` | Resource not found (or belongs to another shop — same response) |
| 409 | `conflict` | Duplicate nonce on proposal submission |
| 413 | `payload_too_large` | Body > 1 MB, or image > 700 KB via tool |
| 422 | `unprocessable` | Business rule violation (below price floor, invalid enum value) |
| 429 | `rate_limited` | Auth failure rate limit hit (20 failures/IP/15 min) |
| 5xx | `internal_error` | Server-side error; retry with exponential back-off |

---

## Specific 403 messages and what to do

| `error` (Hungarian) | Cause | Recovery |
|---|---|---|
| `"Ez a token csak olvasásra jogosít"` | write endpoint called with read-scope token | Reissue token with `write` scope in web app |
| `"Az ügynök-token nem hagyhat jóvá árjavaslatokat."` | approve/reject/rollback called with any Bearer token | Use web UI at haszno.com/app/javaslatok or legacy key |
| `seller_type_required` (code) | partner syndication requires `kereskedo` seller type | Shop owner must set seller type in web app → Settings → Vállalkozói adatok |

---

## Diagnosing a 401 or 403

```
Symptom: 401 on GET /api/v1/agent/products
→ Token expired (default 90 days) or revoked
→ Check tokenScope via GET /api/v1/auth/me; if 401 there too, reissue the token

Symptom: 403 on POST /api/v1/agent/proposals
→ read-scope token; check GET /api/v1/auth/me → tokenScope === "read"
→ Reissue with write scope

Symptom: 403 "Az ügynök-token nem hagyhat jóvá árjavaslatokat."
→ Calling approve/reject/rollback with a Bearer token (ANY Bearer token)
→ Not fixable with a different token; this endpoint requires a human session
→ Direct user to: haszno.com/app/javaslatok

Symptom: 401 from a session-only route (/api/v1/billing/*, /api/v1/import-list/*, etc.)
→ Bearer token falls through to the Basic-auth gate (no Basic set)
→ These routes are not accessible to agents; use web UI

Symptom: 429 on /api/agent/* or /api/mcp
→ 20 failed Bearer auth attempts from this IP in the last 15 min
→ Wait 15 min; verify token format (must start with haszno_)

Symptom: 409 "Duplikált nonce"
→ Proposal with this nonce was already submitted
→ Call GET /api/v1/agent/proposals to find the original proposal ID
→ Do not retry with the same nonce; generate a new one for a new proposal
```

---

## Proposal-specific errors

| Status | Meaning | Action |
|---|---|---|
| 201 | Proposal created | Tell user; note `id`; direct to web UI for approval |
| 400 | Missing body / wrong Content-Type | Fix request; ensure `Content-Type: application/json` |
| 403 | read-scope token | Reissue with write scope |
| 403 | Bearer-on-approve | Cannot approve with tokens; use web UI |
| 404 | productId not found | Refresh product list (`GET /api/v1/agent/products`); product may have been removed |
| 409 | Duplicate nonce | Retrieve existing proposal; generate new nonce for a new attempt |
| 422 | Below price floor | Increase `proposedPriceGross` to ≥ `recommended.floorGross` from agent/products |
| 429 | Rate limited | Wait 15 min |

---

## Shop marketplace errors

| Status | Meaning | Action |
|---|---|---|
| 400 | Missing required ad attribute for category | Call `haszno_shop_list_categories` to see required attrs for the category |
| 403 `seller_type_required` | Shop must be `kereskedo` for this operation | Set seller type in web app |
| 404 | Ad/reservation/inquiry not found | Refresh your list |
| 409 | Conflict (e.g. ad already sold/deleted) | Check current ad status first |
| 413 | Image too large | Max 700 KB per image for uploads via tools |

---

## Retry policy

The CLI and MCP auto-retry with exponential back-off on 5xx and 429 responses.
Agents implementing raw HTTP calls should do the same:
- 429: wait at least 60s (rate-limit window is 15 min)
- 5xx: 3 retries max with 2s, 4s, 8s back-off
- 4xx (except 429): do not retry; fix the request

---

## X-Request-Id for support

Send a custom `X-Request-Id` header (8–64 alphanumeric/`./_/-` chars) on every request.
The server echoes it back in the response header and embeds it in the error `requestId` field.
Include this in support reports to correlate server-side logs.

```bash
curl -H "Authorization: Bearer $HASZNO_API_TOKEN" \
     -H "X-Request-Id: agent-morning-check-$(date +%s)" \
     https://haszno.com/api/v1/agent/products
```
