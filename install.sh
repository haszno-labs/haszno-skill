#!/usr/bin/env bash
# install.sh — Haszno egységes telepítő / unified installer
#
# Telepíti a haszno-cli-t, haszno-mcp-t és haszno-skillt egy lépésben.
# Installs haszno-cli, haszno-mcp, and haszno-skill in one step.
#
# Használat / Usage:
#   bash install.sh              # telepítés / install
#   bash install.sh --uninstall  # eltávolítás / uninstall
#
# Publikus változat (ha a repók nyilvánosak):
#   curl -fsSL https://raw.githubusercontent.com/haszno-labs/haszno-skill/main/install.sh | bash
#
# Privát változat (jelenleg / currently private):
#   gh repo clone haszno-labs/haszno-skill /tmp/haszno-skill-install
#   bash /tmp/haszno-skill-install/install.sh
#
# Lokális fejlesztési override:
#   HASZNO_SRC_DIR=~/Documents/medusa-shops/haszno-labs bash install.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Konfiguráció / Configuration
# ---------------------------------------------------------------------------
HASZNO_HOME="${HASZNO_HOME:-$HOME/.haszno}"
HASZNO_SRC_DIR="${HASZNO_SRC_DIR:-}"   # ha üres: GitHub-ról klónoz / empty: clone from GitHub
CLAUDE_SKILL_DIR="${CLAUDE_SKILL_DIR:-$HOME/.claude/skills}"

REPOS=(haszno-cli haszno-mcp haszno-skill)
GITHUB_ORG="haszno-labs"
GITHUB_BASE="https://github.com/${GITHUB_ORG}"

# ---------------------------------------------------------------------------
# Segédfüggvények / Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;32m[haszno]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[haszno][FIGYELEM]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[haszno][HIBA]\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\033[1;34m[haszno] ──▶\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Előfeltételek ellenőrzése / Check prerequisites
# ---------------------------------------------------------------------------
check_prerequisites() {
  step "Előfeltételek ellenőrzése... / Checking prerequisites..."

  command -v git >/dev/null 2>&1 || err "A 'git' nem található. Telepítsd: https://git-scm.com"
  command -v node >/dev/null 2>&1 || err "A 'node' nem található. Telepítsd: https://nodejs.org (node>=20 szükséges)"
  command -v npm >/dev/null 2>&1  || err "Az 'npm' nem található. Node.js-sel együtt szokott érkezni."

  local node_ver
  node_ver=$(node -e 'process.stdout.write(process.versions.node)')
  local node_major
  node_major=$(echo "$node_ver" | cut -d. -f1)
  if [ "$node_major" -lt 20 ]; then
    err "Node.js >= 20 szükséges (jelenlegi: $node_ver). Frissítsd: https://nodejs.org"
  fi

  log "node $node_ver, npm $(npm --version) — OK"
}

# ---------------------------------------------------------------------------
# Repo klónozása / frissítése — Strategy:
#   1. HASZNO_SRC_DIR megadva → helyi másolat cp/rsync
#   2. gh elérhető és autentikált → gh repo clone
#   3. Fallback → git clone (nyilvános HTTPS; privátnál PAT kell)
# ---------------------------------------------------------------------------
ensure_repo() {
  local repo="$1"
  local dest="$HASZNO_HOME/$repo"

  step "Repó: $repo"

  # Helyi forrás override
  if [ -n "$HASZNO_SRC_DIR" ]; then
    local src="$HASZNO_SRC_DIR/$repo"
    if [ ! -d "$src" ]; then
      err "HASZNO_SRC_DIR=$HASZNO_SRC_DIR megadva, de '$src' nem létezik."
    fi
    if [ -d "$dest" ]; then
      log "  Frissítés helyi forrásból: $src → $dest"
      rsync -a --delete --exclude='.git' --exclude='node_modules' --exclude='dist' \
        "$src/" "$dest/"
    else
      log "  Másolás helyi forrásból: $src → $dest"
      mkdir -p "$dest"
      rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' \
        "$src/" "$dest/"
    fi
    return 0
  fi

  # GitHub klón/pull
  if [ -d "$dest/.git" ]; then
    log "  Már megvan, frissítés (git pull)..."
    git -C "$dest" pull --ff-only --quiet || warn "  git pull nem sikerült, folytatás a meglévő verzióval."
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  # gh CLI preferált (privát repókhoz)
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      log "  Klónozás: gh repo clone ${GITHUB_ORG}/${repo} $dest"
      gh repo clone "${GITHUB_ORG}/${repo}" "$dest" -- --quiet
      return 0
    else
      warn "  gh telepítve, de nincs bejelentkezve. Fallback: git clone (HTTPS)."
    fi
  fi

  # HTTPS fallback
  local url="${GITHUB_BASE}/${repo}.git"
  log "  Klónozás: git clone $url"
  git clone --quiet "$url" "$dest" \
    || err "Klónozás sikertelen: $url — Privát repóknál 'gh auth login' vagy PAT szükséges."
}

# ---------------------------------------------------------------------------
# Build: npm install + npm run build
# ---------------------------------------------------------------------------
build_package() {
  local repo="$1"
  local dest="$HASZNO_HOME/$repo"
  step "Build: $repo"
  ( cd "$dest" && npm install --quiet && npm run build )
  log "  $repo: build kész."
}

# ---------------------------------------------------------------------------
# CLI linkelése globálisan
# ---------------------------------------------------------------------------
link_cli() {
  local cli_dir="$HASZNO_HOME/haszno-cli"
  step "CLI globális linkelése..."

  # Próbáljuk meg npm link-kel
  if ( cd "$cli_dir" && npm link --quiet 2>/dev/null ); then
    log "  'haszno' elérhető (npm link)."
    return 0
  fi

  # Fallback: ~/.local/bin symlink
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"
  local cli_bin="$cli_dir/dist/index.js"
  local link_target="$bin_dir/haszno"

  if [ ! -f "$cli_bin" ]; then
    warn "  dist/index.js nem létezik: $cli_bin — CLI linkelés kihagyva."
    return 1
  fi

  ln -sf "$cli_bin" "$link_target"
  chmod +x "$cli_bin"
  log "  Symlink: $link_target → $cli_bin"
  log "  Győződj meg róla, hogy a \$PATH tartalmazza: $bin_dir"
}

# ---------------------------------------------------------------------------
# MCP regisztrálása Claude Code-ban
# ---------------------------------------------------------------------------
register_mcp() {
  step "MCP regisztrálása Claude Code-ban..."

  if ! command -v claude >/dev/null 2>&1; then
    warn "  'claude' parancs nem található — MCP regisztrálás kihagyva."
    warn "  Kézzel: claude mcp add haszno --scope user -- node $HASZNO_HOME/haszno-mcp/dist/index.js"
    return 0
  fi

  local mcp_bin="$HASZNO_HOME/haszno-mcp/dist/index.js"
  if [ ! -f "$mcp_bin" ]; then
    warn "  MCP dist nem létezik: $mcp_bin — regisztrálás kihagyva."
    return 1
  fi

  # Ellenőrzés: már regisztrálva van-e?
  if claude mcp list 2>/dev/null | grep -q '^haszno\b'; then
    log "  'haszno' MCP már regisztrálva van — kihagyás."
    return 0
  fi

  claude mcp add haszno --scope user -- node "$mcp_bin"
  log "  MCP 'haszno' regisztrálva."
}

# ---------------------------------------------------------------------------
# Skill másolása ~/.claude/skills/haszno-ba
# ---------------------------------------------------------------------------
install_skill() {
  step "Skill telepítése: ~/.claude/skills/haszno/"

  local skill_src="$HASZNO_HOME/haszno-skill/skills/haszno"
  local skill_dest="$CLAUDE_SKILL_DIR/haszno"

  if [ ! -d "$skill_src" ]; then
    warn "  Skill forrás nem található: $skill_src — kihagyás."
    return 1
  fi

  mkdir -p "$CLAUDE_SKILL_DIR"
  rm -rf "$skill_dest"
  cp -a "$skill_src" "$skill_dest"
  log "  Skill másolva: $skill_dest"
}

# ---------------------------------------------------------------------------
# Eltávolítás / Uninstall
# ---------------------------------------------------------------------------
uninstall() {
  step "Eltávolítás / Uninstalling..."

  # Skill törlése
  local skill_dest="$CLAUDE_SKILL_DIR/haszno"
  if [ -d "$skill_dest" ]; then
    rm -rf "$skill_dest"
    log "  Skill eltávolítva: $skill_dest"
  fi

  # MCP törlése
  if command -v claude >/dev/null 2>&1; then
    if claude mcp list 2>/dev/null | grep -q '^haszno\b'; then
      claude mcp remove haszno --scope user 2>/dev/null || true
      log "  MCP 'haszno' törölve."
    fi
  fi

  # CLI symlink törlése
  local link_target="$HOME/.local/bin/haszno"
  if [ -L "$link_target" ]; then
    rm -f "$link_target"
    log "  CLI symlink törölve: $link_target"
  fi

  # npm unlink (best-effort)
  local cli_dir="$HASZNO_HOME/haszno-cli"
  if [ -d "$cli_dir" ]; then
    ( cd "$cli_dir" && npm unlink --quiet 2>/dev/null ) || true
  fi

  # HASZNO_HOME törlése
  if [ -d "$HASZNO_HOME" ]; then
    chmod -R u+rwx "$HASZNO_HOME" 2>/dev/null || true
    rm -rf "$HASZNO_HOME"
    log "  Könyvtár törölve: $HASZNO_HOME"
  fi

  log "Haszno eltávolítva."
}

# ---------------------------------------------------------------------------
# Shellcheck futtatása (ha elérhető)
# ---------------------------------------------------------------------------
run_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    if [ -f "$script_path" ]; then
      shellcheck "$script_path" && log "shellcheck: OK" || warn "shellcheck figyelmeztetések — nem blokkoló."
    fi
  fi
}

# ---------------------------------------------------------------------------
# Összefoglaló / Summary
# ---------------------------------------------------------------------------
print_summary() {
  printf '\n'
  log "======================================================"
  log " Haszno telepítés kész!"
  log "======================================================"
  log " CLI:    haszno --help"
  log " MCP:    haszno_* tools in Claude Code (ha regisztrálva)"
  log " Skill:  $CLAUDE_SKILL_DIR/haszno/SKILL.md"
  log ""
  log " Konfiguráció:"
  log "   export HASZNO_API_URL=https://your-shop.haszno.hu"
  log "   export HASZNO_API_KEY=your-api-key"
  log ""
  log " Eltávolítás: bash $HASZNO_HOME/haszno-skill/install.sh --uninstall"
  printf '\n'
}

# ---------------------------------------------------------------------------
# Belépési pont / Entry point
# ---------------------------------------------------------------------------
main() {
  # Shellcheck futtatása induláskor (nem blokkoló)
  run_shellcheck

  if [ "${1:-}" = "--uninstall" ]; then
    uninstall
    return 0
  fi

  log "Haszno telepítő indul... (HASZNO_HOME=$HASZNO_HOME)"
  mkdir -p "$HASZNO_HOME"

  check_prerequisites

  # 1. Repók klónozása/frissítése
  for repo in "${REPOS[@]}"; do
    ensure_repo "$repo"
  done

  # 2. CLI és MCP build
  build_package "haszno-cli"
  build_package "haszno-mcp"
  # skill-nek nincs build lépése (tiszta fájlok)

  # 3. CLI linkelése
  link_cli || warn "CLI linkelés részlegesen sikertelen — ellenőrizd kézzel."

  # 4. MCP regisztrálása
  register_mcp || warn "MCP regisztrálás részlegesen sikertelen — ellenőrizd kézzel."

  # 5. Skill telepítése
  install_skill || warn "Skill telepítés részlegesen sikertelen — ellenőrizd kézzel."

  print_summary
}

main "$@"
