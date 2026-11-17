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

---

## Recipe 9: Sell something from photos in under a minute

Goal: take one or more photos the user shares and post them as an ad on the Haszno Shop.

> **Prerequisite — seller type (one-time):** A new account must call
> `haszno_shop_set_seller_profile(sellerType="maganszemely")` (or `"kereskedo"` with company details)
> before the first ad. The API returns HTTP 409 otherwise.
> Check first with `haszno_shop_list_my_ads` — if the user already has ads, skip this step.

### MCP sequence

```
1. haszno_shop_upload_image(base64=<base64>, mimeType="image/jpeg")
   → { id: 7, url: "/api/shop/images/7" }
   Repeat for each photo; collect both id and url from each result.

2. haszno_shop_suggest_from_photos(imageIds=[7, 8, ...])
   — pass the numeric id values from step 1 (1–3 IDs)
   → { title, description, category, subcategory, attrs, confidence }
   Show this draft to the user and ask: "Ez stimmel? Módosítani kell valamit?"

3. haszno_shop_price_hint(cat=<category from step 2>)
   → { suggestedPriceGross, rangeMin, rangeMax }
   Tell the user: "Az AI szerint a piaci ár kb. X–Y Ft, javasolt ár: Z Ft."

4. Show the draft to the user (title, price, category, description, images).
   Ask: "Feladhatom?"

5. After user says yes:
   haszno_shop_create_ad(
     title=..., category=..., subcategory=..., priceGross=...,
     condition=..., description=..., county=..., city=...,
     attrs=..., images=["/api/shop/images/7", "/api/shop/images/8"],
     contactName=<user's name>, contactEmail=<user's email>,
     contactPhone=<user's phone if provided>,
     negotiable=false, showPhone=false, resellable=false, partnerCommissionPct=0,
     confirm=true
   )
   → { ad: { id, title, ... } }
```

### CLI equivalent

```bash
# 1. Upload + suggest from photos:
haszno shop post --image photo1.jpg --image photo2.jpg --from-photos --dry-run

# 2. After user reviews and tweaks:
haszno shop post --image photo1.jpg --image photo2.jpg \
  --title "Ikea Billy könyvespolc" --category butor --price 8000 \
  --condition hasznalt --county Budapest --city Óbuda \
  --contact-name "Kovács Anna" --contact-email "anna@example.com" --yes
```

### What to tell the user

> "Az AI az alapján, amit a képeken lát, ezt a hirdetésvázlatot javasolja: [draft].
>  A becsült piaci ár kb. 6 000–10 000 Ft. Módosítasz valamit, vagy feladhatom így?"

After posting: "Feladva! Hirdetés ID: #123 — itt éred el: haszno.com/shop/123"

---

## Recipe 10: Sell a car

Car ads require specific attributes. Missing required attributes block posting — always
collect them before calling the API.

### Required attributes for category `auto`

| Attribute key | Values / format | Example |
|---|---|---|
| `brand` | string (make) | `Toyota` |
| `model` | string | `Corolla` |
| `year` | integer | `2019` |
| `mileage_km` | integer | `85000` |
| `fuel` | `benzin` / `diesel` / `elektromos` / `hibrid` / `lpg` | `benzin` |
| `transmission` | `manualis` / `automata` | `manualis` |
| `body` | `szedán` / `kombi` / `suv` / `ferdehátú` / `coupe` / `cabrio` / `egyterű` | `szedán` |
| `doors` | integer | `5` |
| `color` | string | `fehér` |
| `condition` | `uj` / `ujszerű` / `hasznalt` / `hibas` | `hasznalt` |

Ask the user for any missing attributes before drafting.

### MCP sequence

```
1. Collect attrs from user (brand, model, year, mileage_km, fuel, transmission, body, doors, color)

2. haszno_shop_price_hint(title="Toyota Corolla 2019", category="auto",
                          condition="hasznalt")
   → suggest a price range

3. haszno_shop_create_ad(
     title="Toyota Corolla 2019 1.6 benzin — 85 000 km",
     category="auto",
     priceGross=3200000,
     condition="hasznalt",
     description=<user's text>,
     county=<user's county>,
     city=<user's city>,
     attrs={ brand:"Toyota", model:"Corolla", year:2019,
             mileage_km:85000, fuel:"benzin",
             transmission:"manualis", body:"szedán",
             doors:5, color:"fehér" },
     images=["/api/shop/images/7", "/api/shop/images/8"],
     contactName=<user's name>,
     contactEmail=<user's email>,
     contactPhone=<user's phone>,
     negotiable=true, showPhone=true, resellable=false, partnerCommissionPct=0,
     confirm=true
   )
   → { ad: { id, title, ... } }

   Before calling, show the draft (title, price, category, attrs) and ask: "Feladhatom?"
   Call only after user confirms.
```

### CLI equivalent

```bash
haszno shop post \
  --title "Toyota Corolla 2019 1.6 benzin — 85 000 km" \
  --category auto --price 3200000 --condition hasznalt \
  --county "Győr-Moson-Sopron" --city Győr \
  --attr brand=Toyota --attr model=Corolla --attr year=2019 \
  --attr mileage_km=85000 --attr fuel=benzin \
  --attr transmission=manualis --attr body=szedán \
  --attr doors=5 --attr color=fehér \
  --image car1.jpg --image car2.jpg \
  --contact-name "Varga Péter" --contact-email "peter@example.com" \
  --contact-phone "+36301234567" --show-phone \
  --dry-run   # review first, then re-run with --yes
```

### What to tell the user

> "A hirdetésvázlat kész. Az autó piaci ára kb. 3,0–3,5 M Ft. Feladhatom?"

---

## Recipe 11: Find the best offer and reserve it

Goal: search for a specific item, compare offers, and send a reservation to the seller.

### MCP sequence

```
1. haszno_shop_search_ads(q="iPhone 14 Pro", condition="ujszerű",
                           maxPrice=250000)
   → list of ads; show to user: id, title, priceGross, reserved, county

2. User picks an ad (or asks to see details):
   haszno_shop_get_ad(id=<chosen id>)
   → show title, description, attrs, images, priceGross, county, city,
     negotiable, contactName (seller's display name)
   Note: sellerPhone/sellerEmail are not shown until reservation is accepted.

3. User says "reserve it":
   Show the user a summary: "Ezt a foglalási kérelmet küldöm el az eladónak:
   [message, offerPriceGross if set]. Megerősítesz? (A foglalás NEM fizetés —
   az eladóval közvetlenül egyeztek meg a fizetésről és az átadásról.)"

4. After user confirms:
   haszno_shop_reserve_ad(
     adId=<id>,
     message="Délután 5 után tudok átmenni.",
     offerPriceGross=220000,  # optional counter-offer
     phone="+36201234567",    # optional, only if user explicitly provides it
     confirm=true
   )
   → { reservation: { id, status:"fuggoben", ... } }
```

### CLI equivalent

```bash
haszno shop search "iPhone 14 Pro" --max-price 250000 --json \
  | jq '.[] | {id, title, priceGross, condition, county}'

haszno shop show 42

haszno shop reserve 42 --message "Délután 5 után tudok átmenni." --offer 220000 --yes
```

### What to tell the user

> "Foglalási kérelem elküldve (#7). Az eladó értesítést kap, és elfogadhatja vagy
>  visszautasíthatja. Ha elfogadja, megkapod az elérhetőségeit.
>  Emlékeztető: a fizetés és az átadás közvetlenül köztetek zajlik, a Haszno nem
>  közvetíti a pénzt."

---

## Recipe 12: Handle incoming inquiries and reservations as a seller

Goal: a seller checks new messages and reservation requests, then accepts or declines them.

### MCP sequence

```
1. haszno_shop_list_inquiries
   → show each: adTitle, senderName, message, createdAt
   Seller can reply with `haszno_shop_reply_inquiry(id=<id>, message='...')`; each inquiry allows at most one reply.

2. haszno_shop_list_reservations(role="seller", status="fuggoben")
   → list pending reservation requests

3. For each reservation, show: ad.title, buyerName, message, offerPriceGross, createdAt

4. User says "accept #3":
   Tell user: "Elfogadom a foglalást — a vevő megkapja az elérhetőségeidet.
   Határidő: nov. 20. 18:00. Megerősítesz?"

5. After user confirms:
   haszno_shop_respond_reservation(id=3, action="accept")
   — the server automatically sets heldUntil to 48 hours from now
   → { reservation: { id:3, status:"elfogadva", heldUntil:... } }

6. User says "decline #5":
   haszno_shop_respond_reservation(id=5, action="decline", confirm=true)

7. After handover — mark complete:
   haszno_shop_complete_reservation(id=3, soldPriceGross=220000, confirm=true)
   → ad status becomes "eladva"; other open reservations → "elutasítva"
```

### CLI equivalent

```bash
haszno shop inquiries --json

haszno shop reservations --as seller --json | jq '.[] | select(.status=="fuggoben")'

haszno shop reservation accept 3 --held-until "2026-11-20T18:00:00Z"

haszno shop reservation decline 5

haszno shop reservation complete 3 --price 220000
```

### What to tell the user

After `accept`: "Elfogadva. A vevő megkapta az elérhetőségeidet. Miután átadtad,
jelöld teljesítettnek."

After `complete`: "Teljesítve. A hirdetés 'eladva' státuszba került, az összes többi
foglalást automatikusan visszautasítottuk."

---

## Recipe 13: Lower the price / renew / mark sold

Three common post-publishing tasks.

### Lower the price

```
MCP:  haszno_shop_update_ad(id=<id>, priceGross=<new_price>, confirm=true)
CLI:  haszno shop edit <id> --price <new_price> --yes
```

### Renew (bump to top)

```
MCP:  haszno_shop_renew_ad(id=<id>, confirm=true)
CLI:  haszno shop renew <id>
```

### Mark sold (without a Haszno reservation)

```
MCP:  haszno_shop_mark_sold(id=<id>, soldPriceGross=<Ft or omit>, confirm=true)
CLI:  haszno shop sold <id> [--price <Ft>]
```

### What to tell the user

Lower price: "Ár módosítva: [old] Ft → [new] Ft."

Renew: "Hirdetés megújítva — visszakerült az elejére."

Mark sold: "Hirdetés 'eladva' státuszba állítva."

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

## Recipe 22: Napi piaci kutatás (daily market research)

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
## Recipe 14: "Szólj, ha felkerül ilyen" — mentett keresés és árfigyelő

### Mentett keresés (értesítő, ha új hirdetés illik a szűrőre)

```
MCP:
1. haszno_shop_save_search(
     name="Túrakerékpár <50 000 Ft",
     filters={ q:"túrakerékpár", max:50000, cond:"hasznalt" },
     alertEnabled=true      # e-mail értesítőt küld, ha új hirdetés jelenik meg
   )
   → { id: 7, name: "Túrakerékpár <50 000 Ft", alertEnabled: true, createdAt: ... }

2. Lista:
   haszno_shop_list_saved_searches()
   → tömb SavedSearch-ekkel

3. Törlés (ha már nem kell):
   haszno_shop_delete_saved_search(id=7)
   → { ok: true }
```

```bash
# CLI:
haszno shop saved-search add --name "Túrakerékpár <50 000 Ft" \
  --query "túrakerékpár" --max-price 50000 --condition hasznalt

haszno shop saved-search list --json

haszno shop saved-search remove 7
```

### Árfigyelő egy konkrét hirdetésnél

```
MCP:
haszno_shop_watch_price(adId=42, watch=true)
   → { watched: true }
   # E-mail értesítő, ha az ár csökken

# Leiratkozás:
haszno_shop_watch_price(adId=42, watch=false)
   → { watched: false }
```

```bash
haszno shop watch 42
haszno shop unwatch 42
```

### Mit mondj a felhasználónak

> "Elmentettem a keresést. Ha felkerül ilyen hirdetés, e-mailben értesítelek."

---

## Recipe 15: Hirdetés feladása linkből

Goal: a felhasználó beküld egy URL-t (pl. egy másik hirdetési oldal hirdetése),
és Hasznóra akarja feladni.

```
MCP:
1. haszno_shop_import_from_url(url="https://masikoldal.hu/ajanlat/12345")
   → { title: "Nokia 3310", description: "...", price: 3500,
       images: [...], parsed: { condition: "hasznalt" } }
   Ez az eszköz SOHA NEM ad fel hirdetést — csak az adatokat nyeri ki.

2. Mutasd meg a kinyert adatokat a felhasználónak:
   "Ezt találtam: [title], ár: [price] Ft, [leírás részlet].
    Feladjuk így Hasznóra?"

3. Ha a felhasználó igent mond, kérd be a hiányzó kötelező mezőket:
   county, city, contactName, contactEmail, category (ha nem sikerült kinyerni).

4. haszno_shop_create_ad(
     title=..., priceGross=..., description=..., images=[...],
     category=..., condition="hasznalt",
     county=..., city=...,
     contactName=..., contactEmail=...,
     negotiable=false, showPhone=false, resellable=false, partnerCommissionPct=0,
     confirm=true
   )
```

```bash
# CLI — csak kinyerés:
haszno shop import-url "https://masikoldal.hu/ajanlat/12345"

# Kinyerés + feladás (megerősítést kér):
haszno shop import-url "https://masikoldal.hu/ajanlat/12345" --post
```

**Figyelmeztetés:** a Facebook-os URL-eket a szerver visszautasítja (bejelentkezési fal).

---

## Recipe 16: Tömeges hirdetésfeladás könyvtárból vagy CSV-ből

### Könyvtár-mód (AI-javaslat képekből)

Minden alkönyvtár = egy hirdetés képei.

```
Mappa-struktúra:
  termekek/
    billy-konyvespolc/
      foto1.jpg
      foto2.jpg
    samsung-monitor/
      foto1.jpg
```

```bash
# Előnézet (nem ad fel):
haszno shop post-bulk ./termekek --from-photos --dry-run

# Éles (minden alkönyvtárból egyet felad):
haszno shop post-bulk ./termekek --from-photos --yes
```

### CSV-mód

**Kötelező CSV-oszlopok:** `title, category, condition, county, city, contact_name, contact_email`

**Opcionális:** `subcategory, price, negotiable, description, contact_phone, show_phone, images`

```bash
# Előnézet:
haszno shop post-bulk ads.csv --dry-run

# Éles:
haszno shop post-bulk ads.csv --yes
```

**Aranyszabályok:**
- Mindig futtasd `--dry-run` előbb — mutasd meg az előnézeti táblát a felhasználónak.
- Az első hibánál megáll és jelenti a hiba okát.
- Ne futtasd `--yes` nélkül, hacsak a felhasználó nem adott kifejezett jóváhagyást.

---

## Recipe 17: Alku és ellenajánlat — a teljes tárgyalási folyamat

Goal: vevő lefoglalja az árut, az eladó ellenajánlatot tesz, a vevő elfogadja,
majd az eladó elfogadja a foglalást, és végül teljesítik.

### MCP szekvencia

```
1. VEVŐ: Foglalás küldése ellenajánlattal:
   haszno_shop_reserve_ad(adId=42, offerPriceGross=180000, confirm=true)
   → { reservation: { id:7, status:"fuggoben", offerPriceGross:180000 } }

2. ELADÓ: Ellenajánlat küldése:
   [Mutasd az eladónak: "Az aktuális ajánlat 180 000 Ft. Ellenajánlatot küldesz?"]
   haszno_shop_counter_offer(id=7, priceGross=195000)
   → { reservation: { ..., counterPriceGross:195000 } }
   FONTOS: mindig kérd az eladó megerősítését az ellenajánlat összegével.

3. VEVŐ: Ellenajánlat elfogadása:
   haszno_shop_accept_counter(id=7)
   → { reservation: { ..., offerPriceGross:195000, counterPriceGross:null } }

4. ELADÓ: Foglalás elfogadása:
   haszno_shop_respond_reservation(id=7, action="accept")
   → { reservation: { ..., status:"elfogadva", heldUntil:... } }

5. (Átadás/fizetés közvetlenül a felek között)

6. ELADÓ: Teljesítés:
   haszno_shop_complete_reservation(id=7, soldPriceGross=195000, confirm=true)
   → { reservation: { ..., status:"teljesitve", agreedPriceGross:195000 } }
```

```bash
# CLI:
haszno shop reserve 42 --offer 180000 --yes
haszno shop reservation counter 7 --price 195000
haszno shop reservation accept-counter 7
haszno shop reservation accept 7
haszno shop reservation complete 7 --price 195000
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
## Recipe 18: Üzenetküldés a foglaláson

Goal: vevő és eladó szöveges üzeneteket váltanak egy foglaláson belül.

```
MCP:
1. haszno_shop_list_messages(id=7)
   → { items: [ { id, author:"buyer"|"seller", body, createdAt } ] }

2. haszno_shop_send_message(id=7, body="Mikor tudod elhozni?")
   → { message: { id, author, body, createdAt } }

ARANYSZABÁLY: soha ne tedd bele a felhasználó telefonszámát vagy e-mail-
ét az üzenet szövegébe az ő nevében anélkül, hogy megkérdezted volna.
```

```bash
# CLI:
haszno shop reservation messages 7
haszno shop reservation message 7 --text "Mikor tudod elhozni?"
```

---

## Recipe 19: Válasz érdeklődőnek (eladóként)

Goal: az eladó válaszol egy vevő által küldött érdeklődésre (inquiry).

```
MCP:
1. haszno_shop_list_inquiries()
   → { items: [ { id, adId, adTitle, senderName, message, readAt, createdAt } ] }

2. haszno_shop_reply_inquiry(id=3, message="Igen, még elérhető! Pest déli részén.")
   → { reply: { id, inquiryId, message, createdAt } }

ARANYSZABÁLYOK:
- Minden érdeklődés legfeljebb egy válasz kaphat (409, ha már válaszolt).
- Soha ne tedd bele a felhasználó telefonszámát vagy e-mail-ét a válasz szövegébe
  anélkül, hogy megkérdezted volna.
```

```bash
# CLI:
haszno shop inquiries --json
haszno shop inquiry reply 3 --message "Igen, még elérhető! Pest déli részén."
```

---

## Recipe 20: Értékelés leadása teljesített foglalásra

Goal: a foglalás teljesítése után vevő és/vagy eladó értékelést hagy egymásnak.

```
MCP:
haszno_shop_review(id=7, rating=5, comment="Gyors, pontos, barátságos!", confirm=true)
→ { review: { id, reservationId, role:"buyer"|"seller", rating, comment, createdAt } }

ARANYSZABÁLYOK:
- Mindig mutasd meg a csillagszámot és a megjegyzést a felhasználónak,
  és kérj megerősítést — az értékelés végleges és nyilvános.
- 409 hiba: a foglalás még nincs "teljesitve", vagy már adott értékelést.
- Csak "teljesitve" státuszú foglalásra lehet értékelni.
```

```bash
# CLI:
haszno shop reservation review 7 --rating 5 --comment "Gyors, pontos, barátságos!"
```

---

## Recipe 21: Biztonságos kijelentkezés (token visszavonása)

Goal: a felhasználó ki szeretne jelentkezni — a token visszavonódjon a szerveren is.

```bash
# CLI — revoke + local delete:
haszno logout
# → "Token visszavonva a szerveren."
# → "Kijelentkezve. Token törölve: ~/.config/haszno/config.json"

# Ha listázni akarod az aktív tokeneket (session auth szükséges):
haszno tokens list --json

# Egy konkrét token visszavonása (session auth szükséges):
haszno tokens revoke 5
```

**Megjegyzés:** a `haszno logout` Bearer-tokent vált, és ha a szerver nem érhető el,
akkor is törli a helyi konfigurációt (figyelmeztetéssel). A `tokens list` és `tokens revoke`
session-alapú hitelesítést igényelnek — ezek csak böngészős session-nel rendelkező
környezetben érhetők el.

---

## Recipe 22: Booking oldal beállítása üzleti leírásból

**Goal:** an owner describes their business in plain language; the agent sets up
a complete booking page — services, resources, opening hours, theme — and publishes
it only after the owner explicitly approves.

**Safety rules for this recipe:**
- Never invent prices. If the owner does not mention a price, ask before continuing.
- Never call `haszno_booking_publish` (or `haszno booking publish`) without an
  explicit "yes" from the owner.
- Always dry-run `haszno_booking_apply_setup` first.

---

### Step 1 — Read the current state

```
MCP:  haszno_booking_get_setup
CLI:  haszno booking status --json
```

Note `checklist`, `nextStep`, and whether the page is already published.
If it is already published, tell the owner and ask whether to continue.

---

### Step 2 — Draft the setup JSON from the owner's description

Based on what the owner told you, draft a setup object. For anything missing or
unclear, ask before moving on.

```jsonc
{
  "services": [
    {
      "name": "Fodrászat — rövid haj",
      "durationMin": 45,
      "priceGross": 4500,     // ask the owner if not stated
      "description": "Mosás, vágás, szárítás"
    }
  ],
  "resources": [
    { "name": "Anna" },
    { "name": "1-es szék" }
  ],
  "hours": [
    { "day": 1, "open": "09:00", "close": "18:00" },
    { "day": 2, "open": "09:00", "close": "18:00" },
    { "day": 3, "open": "09:00", "close": "18:00" },
    { "day": 4, "open": "09:00", "close": "18:00" },
    { "day": 5, "open": "09:00", "close": "16:00" }
    // Sunday (0) and Saturday (6) are omitted → closed
  ],
  "theme": {
    "accent": "#1a7a5e",
    "background": "soft",
    "radius": "round",
    "font": "inter",
    "headline": "Foglaljon időpontot online",
    "buttonLabel": "Foglaljon most"
  }
}
```

Show the full draft to the owner and ask if the services, prices, hours and
theme look right. Do not proceed until they confirm the draft.

---

### Step 3 — Dry-run apply

```
MCP:  haszno_booking_apply_setup(setup=<draft>, dryRun=true)
CLI:  haszno booking apply setup.json --dry-run
```

Show the returned `changes` list to the owner:
> "A következő változásokat fogom elvégezni: …  Folytathatom?"

---

### Step 4 — Apply for real

```
MCP:  haszno_booking_apply_setup(setup=<draft>, confirm=true)
CLI:  haszno booking apply setup.json --yes
```

---

### Step 5 — Set theme (if theme was not part of the bulk apply)

```
MCP:  haszno_booking_set_theme(accent="#1a7a5e", background="soft", ...)
CLI:  haszno booking theme set --accent "#1a7a5e" --background soft --font inter \
        --headline "Foglaljon időpontot online" --button-label "Foglaljon most"
```

---

### Step 6 — Confirm before publishing

Read the current checklist:

```
MCP:  haszno_booking_get_setup  → check checklist.services, .resources, .hours
CLI:  haszno booking status --json
```

If any checklist item is `false`, report it and stop — the page cannot be published
until all three are set up.

Then show the owner the page slug and ask:
> "A foglalási oldal elkészült. Közzétegyem? (haszno.com/book/<slug>)"

**Wait for an explicit "yes" before calling publish.**

---

### Step 7 — Publish

```
MCP:  haszno_booking_publish(published=true, confirm=true)
CLI:  haszno booking publish
```

Report the live URL to the owner:
> "Az időpontfoglaló oldal elérhető: haszno.com/book/<slug>"

---

### CLI one-liner (dry-run → apply → publish, scripted)

```bash
# Step 1: dry-run
haszno booking apply setup.json --dry-run

# Step 2: apply (after owner confirmation)
haszno booking apply setup.json --yes

# Step 3: set theme (optional)
haszno booking theme set --accent "#1a7a5e" --background soft \
  --headline "Foglaljon időpontot online" --button-label "Foglaljon most"

# Step 4: check status
haszno booking status --json | jq '{published, checklist}'

# Step 5: publish (only after owner confirms)
haszno booking publish
```

