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

---

## Recipe 6: Húzd be a barátod/beszállítód termékeit a boltodba

Ez a recept leírja, hogyan lehet egy Haszno-partner szállítójának termékeit megkeresni,
az import listára felvenni, majd a bekötött webshopba kiküldeni — és hogyan lehet
meghívóval P2P-partnerséget kialakítani.

### A teljes folyamat

#### 1. lépés — Katalógus böngészése, termékek kiválasztása

**MCP:**
```
1. haszno_catalogue_search(q="...", inStock=true, minMarginPct=15, sort="margin_desc")
   → találd meg a legjobb margójú, készleten lévő termékeket
   → jegyezd meg az item.id értékeket (katalógus termék ID-k)

2. haszno_catalogue_search(cats="elektronika", partner=42, pageSize=50)
   → kategória + partner szűrés kombinálva
```

**CLI:**
```bash
# Készleten lévő, 15%+ margójú elektronika, margin szerint rendezve
haszno catalogue search --cats elektronika --min-margin 15 --in-stock \
  --sort margin_desc --json | jq '.items[:10] | .[] | {id,name,m:.marginPct,stock}'
```

---

#### 2. lépés — Termékek hozzáadása az import listához

A katalógus `item.id` értékei (nem a saját `products.id`-k) kellenek ide.

**MCP:**
```
haszno_import_list_add(networkProductIds=[101, 102, 103])
→ { added: 3, skipped: 0 }
```

**CLI:**
```bash
haszno import add 101 102 103
```

---

#### 3. lépés — Import lista ellenőrzése

**MCP:**
```
haszno_import_list_list(status="varakozik")
→ visszaadja a kiküldésre váró tételek id-jait
```

**CLI:**
```bash
haszno import list --status varakozik --json | jq '[.[] | {id, name, sku}]'
```

---

#### 4. lépés — Célbolt kiválasztása

**MCP:**
```
haszno_connections_list(status="kapcsolva")
→ csak a tényleg bekötött boltok; jegyezd meg a connection id-t
```

**CLI:**
```bash
haszno connections list --status kapcsolva --json | jq '.[] | {id,name,platform}'
```

---

#### 5. lépés — Termékek kiküldése a webshopba

> Mindig mutasd meg a felhasználónak mit fog kiküldeni, és kérd a megerősítést.

**MCP:**
```
# Előnézet (confirm=false):
haszno_import_list_push(ids=[5,6,7], targetConnectionId=1, confirm=false)

# Megerősítés után:
haszno_import_list_push(ids=[5,6,7], targetConnectionId=1, confirm=true)
→ { pushed: 3, failed: 0, errors: [] }
```

**CLI:**
```bash
# Előnézet --yes nélkül
haszno import push --ids 5,6,7 --target 1

# Tényleges kiküldés
haszno import push --ids 5,6,7 --target 1 --yes
```

---

### P2P-partner meghívása (barát/ismerős szállítójának termékeit is behozhatod)

Ha valaki másnak is hozzáférést akarsz adni az egyik szállítódhoz:

#### Meghívó küldése (a szállító gazdája)

**MCP:**
```
haszno_peers_invite_create(supplierId=42, expiresAt="2026-12-31T23:59:00Z")
→ { code: "inv_abc123", ... }
# Add át a kódot a partnernek
```

**CLI:**
```bash
haszno peers invite --supplier 42 --expires 2026-12-31T23:59:00Z
# → Meghívó kód: inv_abc123
```

#### Meghívó elfogadása (a partner oldalán)

**MCP:**
```
# Előnézet:
haszno_peers_invite_accept(code="inv_abc123", acceptorId="partnerbolt", confirm=false)

# Elfogadás:
haszno_peers_invite_accept(code="inv_abc123", acceptorId="partnerbolt", confirm=true)
→ PeerLink: { id, supplierId: 42, partner: "partnerbolt", createdAt }
```

**CLI:**
```bash
haszno peers accept inv_abc123 --acceptor partnerbolt --yes
```

Sikeres elfogadás után a `partnerbolt` shop eléri a szállító #42 katalógusát a
`haszno_catalogue_search` eszközzel.

---

### Összefoglalás — mit mond el a felhasználónak

> "Megtaláltam 15 terméket az elektronika kategóriában, 15%+ margóval, készleten.
>  Hozzáadtam az import listához. A kapcsolva lévő 'Fő webshop' (ID: 1) felé kiküldöm,
>  3 terméket. Megerősíted?"

Visszajelzés: `{ pushed: 3, failed: 0 }` → "3 termék sikeresen kiküldve a webshopba."

---

## Recipe 9: Napi piaci kutatás (daily market research)

Ez a recept az ügynök-oldali napi kutatás teljes menetét írja le: a bolt adataiból
generált kutatási brífingtől a megállapítások beküldéséig és a javasolt műveletek
rögzítéséig. Az eredmény megjelenik a **Haszno Menedzser** (`/app/napi-jelentes`) oldalán.

> **Mikor futtasd:** naponta egyszer (reggel), mielőtt a bolt tulajdonosa megnyitja
> az appot. Futtatható ütemezőből (cron), Workflow eszközből, vagy a felhasználó
> kérésére interaktívan.

---

### Az út lépései

#### 1. lépés — Kutatási brífing lekérése

A brífing megmondja, melyik termékekre / kulcsszavakra kell figyelni ma,
és pontosan milyen kérdéseket vizsgáljon az ügynök.

**MCP:**
```
haszno_research_brief
→ ResearchBrief {
    day: "2026-11-12",
    shopFocus: [ { keyword, productId, name, priceGross, marketMinGross, trend } ],
    questions: [ "Mennyi a PS5 Pro piaci minimumára ma?", ... ],
    postTo: "/api/agent/daily-report/2026-11-12/findings"
  }
```

**CLI:**
```bash
haszno research brief --json
# → day, shopFocus[], questions[], postTo
```

Ha a `questions` lista üres, a brífing generálása még folyamatban lehet — várj
60 másodpercet, majd kíséreld meg újra.

---

#### 2. lépés — Minden kérdés megválaszolása webes kereséssel

Minden `questions[i]`-re:
1. Végezz nyilvános webes keresést (pl. Google, árösszehasonlító oldalak,
   gyártói sajtóközlemények, megbízható híroldalak).
2. Nyisd meg a legmegbízhatóbb forrást, és **olvasd ki a konkrét értéket**
   (ár, dátum, esemény neve). Ne becsülj; ha nem találsz számot, azt jelezd.
3. Jegyezd meg a forrás nevét és URL-jét — ezek kötelezőek a beküldésnél.

**Őrszabályok a kutatás alatt:**
- Csak nyilvánosan elérhető árakat használj. Más viszonteladó bolt nem nyilvános
  forrás (pl. egy másik Haszno-bolt belső adata soha nem forrás).
- Ha egy ár bizonytalan (paywalled, régóta nem frissült), jelezd az `body`-ban,
  és ne add hozzá `suggestedAction`-ként árazási javaslatot.
- Soha ne fabrikálj forrás-URL-t. Ha nincs URL, hagyd ki a `sourceUrl` mezőt.

---

#### 3. lépés — Megállapítások összegyűjtése és ellenőrzése

Összesen **3–10 megállapítást** készíts (nem többet, mint 20 egy kérésben).

Minden megállapításhoz:
- `kind`: az alábbiak egyike — `ar_emelkedes` / `ar_csokkenes` / `trend` / `hir` / `lehetoseg`
- `title`: 5–140 karakter, magyarázó, tényszerű cím
- `body`: 10–1200 karakter, konkrét tény + forrás összefoglaló
- `sourceName` + `sourceUrl`: a forrás neve és ellenőrizhető URL-je (kötelező `hir` és `ar_*` típusnál)
- `changePct`: ha az ár %-ban változott (pozitív = emelkedés, negatív = csökkenés)
- `keyword` / `productId`: ha a bolt egyik termékéhez kapcsolódik

**Ellenőrzés beküldés előtt:**
- Minden `sourceUrl` valós, megnyitható HTTP(S) cím?
- Egyetlen megállapítás sem tartalmaz más boltok árait vagy margóit?
- Az árak a mai napra vonatkoznak (nem 3 hónaposak)?

---

#### 4. lépés — Megállapítások beküldése

**MCP:**
```
haszno_post_findings(
  day="2026-11-12",
  headline="PS5 Pro ára emelkedett; új Switch 2 bundle piacon",
  summary="Három szórakoztatóipari termék árában volt elmozdulás. A PS5 Pro nagyon...",
  items=[
    {
      kind: "ar_emelkedes",
      title: "PS5 Pro piaci minimum +4,2% az elmúlt héten",
      body: "Az Árukereső.hu adatai szerint a PS5 Pro legolcsóbb ajánlata 199 990 Ft-ról 208 490 Ft-ra nőtt.",
      changePct: 4.2,
      keyword: "ps5 pro",
      productId: 112,
      sourceName: "Árukereső.hu",
      sourceUrl: "https://www.arukereso.hu/...",
      suggestedAction: { type: "ar", productId: 112, priceGross: 206000 }
    },
    {
      kind: "hir",
      title: "GTA VI megjelenési dátum megerősítve — konzolkereslet várható",
      body: "A Rockstar Games bejelentette, hogy a GTA VI 2026 őszén jelenik meg PS5-re és Xbox Series X-re...",
      sourceName: "Rockstar Games",
      sourceUrl: "https://www.rockstargames.com/...",
      suggestedAction: null
    }
  ]
)
→ DailyReport (a frissített napi jelentés)
```

**CLI:**
```bash
# Írd a findings-okat egy JSON fájlba, majd küldd be:
haszno research post --day 2026-11-12 /tmp/findings.json
# A fájl struktúrája: { headline, summary, items: FindingInput[] }
```

Sikeres beküldés után a válasz a teljes `DailyReport` objektum — ellenőrizd,
hogy az `items` listájában megjelentek-e az új tételek (`origin: "agent"`).

---

#### 5. lépés — Műveletek javaslása (legfeljebb 5 db)

Az 'agent' origin itemekből válaszd ki azokat, amelyekhez konkrét, indokolható
cselekvés tartozik. Javasolj **legfeljebb 5** műveletet — a minőség fontosabb a mennyiségnél.

**Elfogadható művelet típusok:**
| Típus | Mikor javasolható |
|---|---|
| `ar` | A piaci minimum megváltozott, és az új ár ≥ abszolút árhatár (a szerver ellenőrzi). |
| `felvetel` | A kutatás hasonló terméket talált a katalógusban, ami még nem szerepel a boltban. |
| `levetel` | Egy termék tartósan kifogyott (`keszlet` jelzéssel a jelentésben). |
| `import` | Hálózati termék megjelent, ami releváns a bolt fókuszára. |

**MCP — egy javaslat beküldése:**
```
haszno_propose_action(
  type="ar",
  productId=112,
  priceGross=206000,
  reason="A piaci minimum 208 490 Ft-ra emelkedett (Árukereső.hu, 2026-11-12). Az új ár 206 000 Ft, ami megőrzi a versenyképességet.",
  reportItemId=<az előző lépésből kapott item id>
)
→ AgentAction { id, status: "javasolt", autoApproved: false, ... }
  VAGY ha az autopilot aktív és a feltételek teljesülnek:
→ AgentAction { status: "vegrehajtva", autoApproved: true }
```

**CLI:**
```bash
haszno actions propose \
  --type ar \
  --product-id 112 \
  --price 206000 \
  --reason "A piaci minimum 208 490 Ft-ra emelkedett (Árukereső.hu, 2026-11-12)." \
  --report-item 47
```

**Amit soha ne állíts:**
- Ne mondd, hogy „végrehajtottam" — a szerver jelzi, ha autoApproved volt.
- Ne ismételj duplikált javaslatot (a szerver 409-et ad vissza).
- Ne javasolj `ar` műveletet, ha a termékhez nincs ismert beszerzési ár
  (a szerver visszadobja 400-zal).

---

#### 6. lépés — Összefoglalás a tulajdonosnak

A kutatás befejezésekor közöld röviden az eredményt, és irányítsd a tulajdonost
a Napi jelentés oldalra:

> "A napi kutatás kész. 7 megállapítást rögzítettem (3 áremelkedés, 2 hír,
>  2 lehetőség). 4 műveletet javasoltam jóváhagyásra.
>  Átnézheted és jóváhagyhatod őket itt: **[/app/napi-jelentes](/app/napi-jelentes)**"

Ha az autopilot aktiválva van, az automatikusan végrehajtott műveletek státusza
már `vegrehajtva` lesz — ezeket is tüntesd fel:

> "Ebből 2 műveletet az autopilot már automatikusan végre is hajtott
>  (mindkettő 10%-on belüli árkiigazítás volt). 2 javaslat vár a jóváhagyásodra."

---

### Gyorsreferencia — MCP eszközök (manager domain)

| Eszköz | Leírás |
|---|---|
| `haszno_daily_report` | Napi piaci jelentés lekérése (legutóbbi vagy adott napra, read-only) |
| `haszno_research_brief` | Napi kutatási brífing lekérése (read-only) |
| `haszno_post_findings` | Agent-kutatás eredményeinek beküldése |
| `haszno_propose_action` | Művelet javaslása jóváhagyásra |
| `haszno_withdraw_action` | Saját javaslat visszavonása |
| `haszno_list_actions` | Függő / legutóbbi műveletek lekérése |

### Gyorsreferencia — CLI parancsok (manager domain)

```bash
haszno report [--day DATE]                       # napi piaci jelentés
haszno research brief --json                      # kutatási brífing
haszno research post [--day DATE] <file.json>     # eredmények beküldése (- = stdin)
haszno actions propose --type TYPE --product-id N --price <gross> --reason "..."
haszno actions list [--status javasolt] [--limit 50] [--json]
```

---

### Teljes séma összefoglalója

```
GET  /api/agent/research-brief                        → ResearchBrief  (Bearer read)
POST /api/agent/daily-report/:day/findings            → DailyReport    (Bearer write; body: FindingsInput)
GET  /api/agent/daily-report                          → DailyReport|null (Bearer read; latest)
GET  /api/agent/daily-report/:day                     → DailyReport    (Bearer read; 404 if none)
POST /api/agent/actions                               → AgentAction    (Bearer write; body: ActionInput & { reason, reportItemId? })
GET  /api/agent/actions?status=javasolt               → AgentAction[]  (Bearer read; shop-scoped)
GET  /api/agent/autopilot                             → AutopilotSettings (Bearer read)
```

Az összes többi manager végpont (`/approve`, `/reject`, `/undo`, autopilot PUT)
kizárólag az emberi UI-ból hívható — API token (Bearer `haszno_…`) esetén 403.

> **Fontos (Bearer-hitelesítés és Vercel):** a `/api/agent/*` végpontokra érkező Bearer-kérések
> átjutnak a külső Basic-auth kapun (lásd `vercel.ts` `isPublicPath`). A kezelők validálják a
> per-bolt tokent (élő DB-keresés; visszavont/lejárt → 401). A `/api/daily-reports/*` útvonalak
> Bearer esetén is a Basic-auth mögött maradnak — ezek a webes UI útvonalai.

---

### Veszélyek és elkerülésük

| Veszély | Megoldás |
|---|---|
| Forrás nélküli ár a `body`-ban | Mindig add hozzá a `sourceName` + `sourceUrl` mezőt; ha nincs, ne szerepelje az árszám |
| Végrehajtottnak hitt javaslat | Csak a szerver válaszának `status` mezőjére támaszkodj; ne feltételezd |
| Másik bolt belső adata forrásként | Csak nyilvánosan elérhető, URL-lel igazolható adatokat használj |
| Napi limit túllépése | Max 60 agent-item/nap és max 20 item/kérés — az újabbakat másnapra halaszd |
| Árazási javaslat árhatár alatt | A szerver visszadobja 400-zal proposekor — ne ismételgesd; vedd figyelembe a `floorGross` értéket a previewból |

