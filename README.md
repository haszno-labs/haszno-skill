# haszno-skill

**Haszno Claude-skill és egységes telepítő** — a Haszno dropshipping-automatizációs SaaS
(haszno.hu) agent skillje Claude Code-hoz, plusz az `install.sh` szkript, amely
a CLI-t, az MCP-t és ezt a skillt egyszerre telepíti.

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

A régi `ARFUTAR_API_URL` / `ARFUTAR_API_KEY` env-változók és a
`~/.config/arfutar` könyvtár is felolvasásra kerül csendesen, ha az
`~/.config/haszno` még nem létezik — visszafelé kompatibilis.

---

## Skill betöltése Claude Code-ban

Telepítés után a skill automatikusan elérhető a `~/.claude/skills/haszno/`
útvonalon. A `haszno`, `haszno.hu`, `dropshipping`, `árajánlat`, `automatika`,
`termékötlet` és hasonló kulcsszavak automatikusan betöltik.

---

## MCP regisztrálása Claude Code-ban

```bash
claude mcp add haszno --scope user -- node ~/.haszno/haszno-mcp/dist/index.js
```

Az `install.sh` ezt automatikusan elvégzi, ha a `claude` parancs elérhető.

---

## Kapcsolódó repók

Ez a három repó együtt alkotja a Haszno agent SDK-t:

| Repó | Leírás |
|---|---|
| [haszno-labs/haszno-cli](https://github.com/haszno-labs/haszno-cli) | `haszno` CLI — shell-ből és cron-ból |
| [haszno-labs/haszno-mcp](https://github.com/haszno-labs/haszno-mcp) | MCP szerver — Claude Desktop / Claude Code-hoz |
| [haszno-labs/haszno-skill](https://github.com/haszno-labs/haszno-skill) | Claude skill + egységes telepítő (ez a repó) |

**Hogyan működnek együtt:**

- A **skill** (`skills/haszno/SKILL.md`) megmondja az agentnek, hogy mikor és
  hogyan használja a Haszno eszközöket: MCP-t részesít előnyben interaktív
  Claude-munkamenetben, CLI-re esik vissza, ha az MCP nem elérhető.
- A **CLI** és az **MCP** ugyanazt az API-kulcsot és konfigurációs könyvtárat
  (`~/.config/haszno`) használják, így `haszno login` (vagy az env-változók
  beállítása) egyszerre konfigurálja mindkettőt.
- Az `install.sh` (ebben a repóban) mindhárom csomagot telepíti egyetlen futtatással.

---

## English summary

**haszno-skill** is the Claude Code skill and unified installer for the Haszno
dropshipping automation SaaS (haszno.hu). It contains:

- `skills/haszno/SKILL.md` — instructs Claude to prefer `haszno_*` MCP tools when
  connected, fall back to the `haszno` CLI otherwise; includes safety rules, workflow
  recipes, and full tool/command references.
- `install.sh` — idempotent one-shot installer for all three repos (CLI, MCP, skill).
  Clones or updates each, builds CLI and MCP, links the CLI globally, registers the
  MCP with Claude Code, and copies the skill to `~/.claude/skills/haszno`.

Requires: `git`, `node >= 20`, `npm`. Optional: `claude`.

---

## Licenc / License

MIT — lásd [LICENSE](LICENSE).
