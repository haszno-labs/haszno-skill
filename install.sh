#!/usr/bin/env bash
# install.sh — Haszno egységes telepítő / unified installer
#
# Telepíti a haszno-cli-t, haszno-mcp-t és haszno-skillt egy lépésben.
# Installs haszno-cli, haszno-mcp, and haszno-skill in one step.
#
# Használat / Usage:
#   bash install.sh              # telepítés / install
#   bash install.sh --uninstall  # eltávolítás / uninstall
#   bash install.sh --uninstall --dry-run  # csak lista / preview only
#
# Egysoros telepítés / one-liner:
#   curl -fsSL https://raw.githubusercontent.com/haszno-labs/haszno-skill/main/install.sh | bash
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
OWNER_FILE=".haszno-installer-owned"
DRY_RUN=false

# ---------------------------------------------------------------------------
# Segédfüggvények / Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;32m[haszno]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[haszno][FIGYELEM]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[haszno][HIBA]\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\033[1;34m[haszno] ──▶\033[0m %s\n' "$*"; }

owned_by_installer() {
  local dir="$1" purpose="$2"
  [ ! -L "$dir" ] && [ ! -L "$dir/$OWNER_FILE" ] && [ -f "$dir/$OWNER_FILE" ] &&
    [ "$(cat "$dir/$OWNER_FILE")" = "$purpose" ]
}

remove_owned() {
  local path="$1"
  if "$DRY_RUN"; then
    log "Eltávolítaná / Would remove: $path"
  else
    rm -rf -- "$path"
    log "Eltávolítva / Removed: $path"
  fi
}

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
#   3. Fallback → git clone (nyilvános HTTPS)
# ---------------------------------------------------------------------------
ensure_repo() {
  local repo="$1"
  local dest="$HASZNO_HOME/$repo"

  step "Repó: $repo"
  if [ -L "$dest" ]; then
    err "A telepítés célja egy szimbolikus link; nem írjuk felül: $dest"
  fi
  if [ -e "$dest" ] && ! owned_by_installer "$dest" git && ! owned_by_installer "$dest" copy; then
    [ -d "$dest" ] || err "A telepítés célja nem könyvtár: $dest"
    warn "Meglévő könyvtár, nincs felülírás / Existing directory, not replaced: $dest"
    return 0
  fi

  # Helyi forrás override
  if [ -n "$HASZNO_SRC_DIR" ]; then
    local src="$HASZNO_SRC_DIR/$repo"
    if owned_by_installer "$dest" git; then
      err "A cél egy Git-klón; helyi másolathoz használj másik HASZNO_HOME könyvtárat: $dest"
    fi
    if [ ! -d "$src" ]; then
      err "HASZNO_SRC_DIR=$HASZNO_SRC_DIR megadva, de '$src' nem létezik."
    fi
    if [ -d "$dest" ]; then
      log "  Frissítés helyi forrásból: $src → $dest"
      rsync -a --exclude="$OWNER_FILE" --exclude='.git' --exclude='node_modules' --exclude='dist' \
        "$src/" "$dest/"
    else
      log "  Másolás helyi forrásból: $src → $dest"
      mkdir -p "$dest"
      rsync -a --exclude="$OWNER_FILE" --exclude='.git' --exclude='node_modules' --exclude='dist' \
        "$src/" "$dest/"
    fi
    # Claim only directories the installer created, never a pre-existing checkout.
    [ -e "$dest/$OWNER_FILE" ] || printf '%s\n' copy > "$dest/$OWNER_FILE"
    return 0
  fi

  # GitHub klón/pull
  if owned_by_installer "$dest" copy; then
    err "A cél egy helyi másolat; Git-klónhoz használj másik HASZNO_HOME könyvtárat: $dest"
  fi
  if [ -d "$dest/.git" ] && [ ! -L "$dest/.git" ]; then
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
      printf '%s\n' git > "$dest/$OWNER_FILE"
      return 0
    else
      warn "  gh telepítve, de nincs bejelentkezve. Fallback: git clone (HTTPS)."
    fi
  fi

  # HTTPS fallback
  local url="${GITHUB_BASE}/${repo}.git"
  log "  Klónozás: git clone $url"
  git clone --quiet "$url" "$dest" \
    || err "Klónozás sikertelen: $url"
  printf '%s\n' git > "$dest/$OWNER_FILE"
}

# ---------------------------------------------------------------------------
# Build: npm install + npm run build
# ---------------------------------------------------------------------------
build_package() {
  local repo="$1"
  local dest="$HASZNO_HOME/$repo"
  step "Build: $repo"
  if ! owned_by_installer "$dest" git && ! owned_by_installer "$dest" copy; then
    [ -f "$dest/dist/index.js" ] || err "Meglévő könyvtár build nélkül; használj másik HASZNO_HOME könyvtárat: $dest"
    warn "Meglévő build használata módosítás nélkül: $dest"
    return 0
  fi
  ( cd "$dest" &&
    if [ -f package-lock.json ]; then npm ci --quiet; else npm install --quiet; fi &&
    npm run build )
  log "  $repo: build kész."
}

# ---------------------------------------------------------------------------
# CLI linkelése globálisan
# ---------------------------------------------------------------------------
link_cli() {
  local cli_dir="$HASZNO_HOME/haszno-cli"
  step "CLI globális linkelése..."
  if command -v haszno >/dev/null 2>&1; then
    log "  Meglévő 'haszno' parancs: nem írjuk felül."
    return 0
  fi

  # Próbáljuk meg npm link-kel
  local npm_root npm_prefix
  npm_root=$(npm root -g) || return 1
  npm_prefix=$(npm prefix -g) || return 1
  if [ ! -e "$npm_root/@haszno/cli" ] && [ ! -L "$npm_root/@haszno/cli" ] &&
    [ ! -e "$npm_prefix/bin/haszno" ] && [ ! -L "$npm_prefix/bin/haszno" ] &&
    ( cd "$cli_dir" && npm link --quiet 2>/dev/null ); then
    log "  'haszno' elérhető (npm link)."
    return 0
  fi

  # Fallback: ~/.local/bin symlink
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir" || return 1
  local cli_bin="$cli_dir/dist/index.js"
  local link_target="$bin_dir/haszno"

  if [ ! -f "$cli_bin" ]; then
    warn "  dist/index.js nem létezik: $cli_bin — CLI linkelés kihagyva."
    return 1
  fi

  if [ -e "$link_target" ] || [ -L "$link_target" ]; then
    warn "  Meglévő CLI bejegyzés, nincs felülírás: $link_target"
    return 0
  fi
  ln -s "$cli_bin" "$link_target" || return 1
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
  if claude mcp get haszno >/dev/null 2>&1; then
    log "  'haszno' MCP már regisztrálva van — kihagyás."
    return 0
  fi

  claude mcp add haszno --scope user -- node "$mcp_bin" || return 1
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

  if [ -e "$skill_dest" ] || [ -L "$skill_dest" ]; then
    warn "  Meglévő skill, nincs felülírás / Existing skill, not replaced: $skill_dest"
    return 0
  fi
  mkdir -p "$CLAUDE_SKILL_DIR" || return 1
  cp -a "$skill_src" "$skill_dest" || return 1
  printf '%s\n' skill > "$skill_dest/$OWNER_FILE" || return 1
  log "  Skill másolva: $skill_dest"
}

# ---------------------------------------------------------------------------
# Eltávolítás / Uninstall
# ---------------------------------------------------------------------------
uninstall() {
  step "Eltávolítás / Uninstalling..."

  local repo dest changes npm_root npm_prefix npm_cli
  local cli_bin="$HASZNO_HOME/haszno-cli/dist/index.js"
  local skill_dest="$CLAUDE_SKILL_DIR/haszno"
  local skill_src="$HASZNO_HOME/haszno-skill/skills/haszno"
  if owned_by_installer "$skill_dest" skill &&
    diff -qr -x "$OWNER_FILE" "$skill_src" "$skill_dest" >/dev/null 2>&1; then
    remove_owned "$skill_dest"
  elif [ -e "$skill_dest" ] || [ -L "$skill_dest" ]; then
    warn "Megmarad: nem igazolt vagy módosított skill / Keeping unverified or modified skill: $skill_dest"
  fi

  # Read user-scope Claude configuration without probing or starting any MCP server.
  local claude_config="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
  if [ -f "$claude_config" ]; then
    if command -v node >/dev/null 2>&1 && node - "$claude_config" "$HASZNO_HOME/haszno-mcp/dist/index.js" <<'NODE'
try {
  const config = JSON.parse(require('node:fs').readFileSync(process.argv[2], 'utf8'));
  const server = config.mcpServers?.haszno;
  if (server?.type === 'stdio' && server.command === 'node' &&
      Array.isArray(server.args) && server.args.length === 1 && server.args[0] === process.argv[3] &&
      Object.keys(server.env ?? {}).length === 0) process.exit(0);
} catch {}
process.exit(1);
NODE
    then
      if "$DRY_RUN"; then
        log "Eltávolítaná / Would remove: Claude MCP haszno"
      else
        command -v claude >/dev/null 2>&1 || err "A Claude CLI szükséges az MCP eltávolításához."
        claude mcp remove haszno --scope user || err "A Haszno MCP eltávolítása nem sikerült."
      fi
    fi
  fi

  local link_target="$HOME/.local/bin/haszno"
  if [ -L "$link_target" ] && [ "$(readlink "$link_target")" = "$cli_bin" ]; then
    remove_owned "$link_target"
  fi

  if command -v npm >/dev/null 2>&1 && npm_root=$(npm root -g) && npm_prefix=$(npm prefix -g); then
    npm_cli="$npm_root/@haszno/cli"
    if [ -L "$npm_cli" ] && [ -d "$HASZNO_HOME/haszno-cli" ] &&
      [ "$(cd -P "$npm_cli" && pwd)" = "$(cd -P "$HASZNO_HOME/haszno-cli" && pwd)" ]; then
      # Removing a global package may unlink its bin; don't touch it if the bin was replaced.
      local npm_bin="$npm_prefix/bin/haszno"
      local expected_bin="../lib/node_modules/@haszno/cli/dist/index.js"
      if { [ ! -e "$npm_bin" ] && [ ! -L "$npm_bin" ]; } ||
        { [ -L "$npm_bin" ] && { [ "$(readlink "$npm_bin")" = "$expected_bin" ] || [ "$(readlink "$npm_bin")" = "$cli_bin" ]; }; }; then
        if "$DRY_RUN"; then
          log "Eltávolítaná / Would remove: @haszno/cli (npm link)"
        else
          npm uninstall --global --quiet @haszno/cli || err "A Haszno npm-link eltávolítása nem sikerült."
        fi
      else
        warn "Megmarad: módosított npm parancs / Keeping replaced npm command: $npm_bin"
        return 1
      fi
    fi
  fi

  # Remove only tracked downloads. A legacy or locally changed working copy is kept.
  for repo in "${REPOS[@]}"; do
    dest="$HASZNO_HOME/$repo"
    if owned_by_installer "$dest" git && [ -d "$dest/.git" ] && [ ! -L "$dest/.git" ] &&
      changes=$(git -C "$dest" status --short -- . ":(exclude)$OWNER_FILE") && [ -z "$changes" ] &&
      changes=$(git -C "$dest" ls-files --others --ignored --exclude-standard -- . ':(exclude,top)dist' ':(exclude,top)node_modules') &&
      [ -z "$changes" ] &&
      [ -z "$(git -C "$dest" for-each-ref --format='%(refname)' --no-merged '@{upstream}' refs/heads refs/tags refs/stash)" ] &&
      git -C "$dest" merge-base --is-ancestor HEAD '@{upstream}'; then
      remove_owned "$dest"
    elif owned_by_installer "$dest" copy && [ -n "$HASZNO_SRC_DIR" ] && [ -d "$HASZNO_SRC_DIR/$repo" ] &&
      changes=$(rsync -rclni --delete --exclude="$OWNER_FILE" --exclude='.git' --exclude='node_modules' --exclude='dist' \
        "$HASZNO_SRC_DIR/$repo/" "$dest/") && [ -z "$changes" ]; then
      remove_owned "$dest"
    elif [ -e "$dest" ] || [ -L "$dest" ]; then
      warn "Megmarad: régi, ismeretlen vagy módosított könyvtár / Keeping legacy, unverified or modified directory: $dest"
    fi
  done
  log "Ellenőrzés kész / Cleanup check complete."
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
  log "   export HASZNO_API_URL=https://haszno.com"
  log "   export HASZNO_API_KEY=your-api-key"
  log ""
  log " Eltávolítás: töltsd le a friss telepítőt, majd: bash haszno-install.sh --uninstall --dry-run"
  printf '\n'
}

# ---------------------------------------------------------------------------
# Belépési pont / Entry point
# ---------------------------------------------------------------------------
main() {
  case "${1:-}" in
    --uninstall|uninstall)
      case "${2:-}" in
        '') [ "$#" -eq 1 ] || err "Használat: install.sh --uninstall [--dry-run]" ;;
        --dry-run) [ "$#" -eq 2 ] || err "Használat: install.sh --uninstall [--dry-run]"; DRY_RUN=true ;;
        *) err "Használat: install.sh --uninstall [--dry-run]" ;;
      esac
      uninstall
      return 0
      ;;
    '') ;;
    *) err "Használat: install.sh [--uninstall [--dry-run]]" ;;
  esac
  # Shellcheck futtatása induláskor (nem blokkoló)
  run_shellcheck

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
