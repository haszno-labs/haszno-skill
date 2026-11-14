# haszno-skill

[English](README.md) | **Magyar**

**Haszno Claude-skill és egységes telepítő** — a Haszno dropshipping-automatizációs SaaS
([haszno.com](https://haszno.com)) agent skillje Claude Code-hoz, plusz az `install.sh`
szkript, amely a CLI-t, az MCP-t és ezt a skillt egyszerre telepíti.

---

## Mi ez?

Ez a repó két dolgot tartalmaz:

1. **`skills/haszno/`** — Claude Code skill, amely megtanítja az AI agentet a Haszno
   eszközök (MCP és CLI) biztonságos használatára.
2. **`install.sh`** — egyetlen telepítő szkript, amely az összes Haszno-csomagot
   (`haszno-cli`, `haszno-mcp`, ezt a skillt) egy lépésben telepíti.

---

## Gyors telepítés

```bash
curl -fsSL https://raw.githubusercontent.com/haszno-labs/haszno-skill/main/install.sh | bash
```

Vagy klónozva:

```bash
git clone https://github.com/haszno-labs/haszno-skill.git /tmp/haszno-skill-install
bash /tmp/haszno-skill-install/install.sh
```

### Lokális forrásból (fejlesztéshez):

```bash
HASZNO_SRC_DIR=~/Documents/medusa-shops/haszno-labs \
  bash install.sh
```

Az `--uninstall` kapcsolóval visszavonható minden változtatás:

```bash
bash ~/.haszno/haszno-skill/install.sh --uninstall
```

---

## Konfiguráció

```bash
export HASZNO_API_URL=https://haszno.com
export HASZNO_API_KEY=your-api-key
```

A régi `ARFUTAR_API_URL` / `ARFUTAR_API_KEY` env-változók és a `~/.config/arfutar`
könyvtár is felolvasásra kerül csendesen, ha az `~/.config/haszno` még nem létezik —
visszafelé kompatibilis.

---

## Skill betöltése Claude Code-ban

Telepítés után a skill automatikusan elérhető a `~/.claude/skills/haszno/` útvonalon.
A `haszno`, `haszno.com`, `dropshipping`, `árajánlat`, `automatika`, `termékötlet`
és hasonló kulcsszavak automatikusan betöltik.

---

## MCP regisztrálása Claude Code-ban

```bash
claude mcp add haszno --scope user -- node ~/.haszno/haszno-mcp/dist/index.js
```

Az `install.sh` ezt automatikusan elvégzi, ha a `claude` parancs elérhető.

---

## Haszno Shop — ingyenes piactér (v0.3.0)

A Haszno Shop egy ingyenes apróhirdetési piactér. Nincs csomag, nincs díj.

**Gyors start:**

```bash
haszno login            # egyszeri — CLI + MCP közös token
haszno shop search "iPhone 14" --json              # hirdetések keresése
haszno shop post --title "Billy polc" --category butor --price 8000 \
  --condition hasznalt --county Budapest --dry-run  # hirdetésvázlat előnézet
```

**v0.3.0 — Új Shop-funkciók:**

| Funkció | CLI | MCP |
|---|---|---|
| Alkudozás / ellenajánlat | `haszno shop reservation counter <id> --price <Ft>` | `haszno_shop_counter_offer` |
| Eladó ellenajánlatának elfogadása | `haszno shop reservation accept-counter <id>` | `haszno_shop_accept_counter` |
| Foglaláshoz üzenetküldés | `haszno shop reservation messages/message <id>` | `haszno_shop_list_messages` / `haszno_shop_send_message` |
| Értékelés leadása | `haszno shop reservation review <id> --rating 1-5` | `haszno_shop_review` |
| Érdeklődésre válasz | `haszno shop inquiry reply <id> --message ...` | `haszno_shop_reply_inquiry` |
| Mentett keresések + e-mail értesítő | `haszno shop saved-search add/list/remove` | `haszno_shop_save_search` / `haszno_shop_list_saved_searches` / `haszno_shop_delete_saved_search` |
| Árfigyelő | `haszno shop watch/unwatch <adId>` | `haszno_shop_watch_price` |
| Importálás külső URL-ből | `haszno shop import-url <url> [--post]` | `haszno_shop_import_from_url` |
| Hirdetésvázlat (szerveren tárolt) | `haszno shop draft show/save/clear` | `haszno_shop_get_draft` / `haszno_shop_save_draft` / `haszno_shop_clear_draft` |
| Tömeges feladás (CSV vagy képmappa) | `haszno shop post-bulk <forrás> [--from-photos] [--dry-run] [--yes]` | — |
| AI-háttér-eltávolítás | `haszno shop post --remove-bg` | `haszno_shop_remove_background` |
| Hirdetés törlése | `haszno shop delete <id>` | _(lásd `haszno_shop_set_ad_status`)_ |
| Session-token kezelés | `haszno tokens list/revoke` / `haszno logout` | — |

A skillt aktiváló kulcsszavak: `hirdetés`, `foglalás`, `eladás`, `alku`,
`ellenajánlat`, `értékelés`, `mentett keresés`, `árfigyelés`, `add fel`,
`hirdesd meg`, `keress nekem`, `foglald le`, `sell this`, `post an ad`,
`reserve this`, `import-url`, `post-bulk`.

A lépésenkénti munkafolyamatokért lásd `skills/haszno/references/recipes.md`
9–21. receptjeit.

---

## Kapcsolódó repók

Ez a három repó együtt alkotja a Haszno agent SDK-t:

| Repó | Leírás |
|---|---|
| [haszno-labs/haszno-cli](https://github.com/haszno-labs/haszno-cli) | `haszno` CLI — shell-ből és cron-ból |
| [haszno-labs/haszno-mcp](https://github.com/haszno-labs/haszno-mcp) | MCP szerver — Claude Desktop / Claude Code-hoz |
| [haszno-labs/haszno-skill](https://github.com/haszno-labs/haszno-skill) | Claude skill + egységes telepítő (ez a repó) |

**Hogyan működnek együtt:**

- A **skill** (`skills/haszno/SKILL.md`) megmondja az agentnek, hogy mikor és hogyan
  használja a Haszno eszközöket: MCP-t részesít előnyben interaktív Claude Desktop /
  Claude Code munkamenetben, CLI-re esik vissza, ha az MCP nem elérhető.
- A **CLI** és az **MCP** ugyanazt az API-kulcsot és konfigurációs könyvtárat
  (`~/.config/haszno`) használják, így `haszno login` (vagy az env-változók beállítása)
  egyszerre konfigurálja mindkettőt.
- Az `install.sh` (ebben a repóban) mindhárom csomagot telepíti egyetlen futtatással.

---

## Dokumentáció

Fejlesztői dokumentáció: [https://docs.haszno.com](https://docs.haszno.com)

---

## Követelmények

- `git`
- `node >= 20`
- `npm`
- `claude` _(nem kötelező — az automatikus MCP-regisztráláshoz szükséges)_

---

## Licenc

MIT — lásd [LICENSE](LICENSE).
