#!/usr/bin/env bash
set -euo pipefail

installer="$(cd "$(dirname "$0")/.." && pwd)/install.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" HASZNO_HOME="$tmp/home/.haszno"
export HASZNO_SRC_DIR="$tmp/src" CLAUDE_SKILL_DIR="$tmp/home/.claude/skills"
export CLAUDE_CONFIG_DIR="$tmp/claude"
export npm_config_prefix="$tmp/npm" npm_config_audit=false npm_config_fund=false npm_config_offline=true
mkdir -p "$tmp/bin" "$HOME/.config/haszno" "$CLAUDE_CONFIG_DIR" "$HASZNO_HOME" "$HASZNO_SRC_DIR/haszno-skill/skills/haszno"
ln -s "$(command -v node)" "$tmp/bin/node"
ln -s "$(command -v npm)" "$tmp/bin/npm"
export PATH="$tmp/bin:$npm_config_prefix/bin:$HOME/.local/bin:/usr/bin:/bin"
printf 'keep\n' > "$HASZNO_HOME/personal.txt"
printf 'keep\n' > "$HOME/.config/haszno/config.json"
printf 'sample\n' > "$HASZNO_SRC_DIR/haszno-skill/skills/haszno/SKILL.md"

for repo in cli mcp; do
  src="$HASZNO_SRC_DIR/haszno-$repo"
  mkdir -p "$src"
  printf '{"name":"@haszno/%s","version":"1.0.0","bin":{"haszno":"dist/index.js"},"scripts":{"build":"mkdir -p dist && cp main.js dist/index.js"}}\n' "$repo" > "$src/package.json"
  printf '#!/usr/bin/env node\n' > "$src/main.js"
  (cd "$src" && npm install --package-lock-only --ignore-scripts --quiet)
done

cat > "$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
config="$CLAUDE_CONFIG_DIR/.claude.json"
case "$2" in
  get) test -f "$config" ;;
  add)
    node -e 'console.log(JSON.stringify({mcpServers:{haszno:{type:"stdio",command:"node",args:[process.argv[1]],env:{}}}}))' "${!#}" > "$config"
    ;;
  remove) test "$4" = --scope && test "$5" = user && rm -- "$config" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/claude"

bash "$installer" >/dev/null
test -f "$CLAUDE_SKILL_DIR/haszno/SKILL.md"
test -L "$npm_config_prefix/bin/haszno"
test -f "$CLAUDE_CONFIG_DIR/.claude.json"
bash "$installer" --uninstall --dry-run > "$tmp/plan"
grep -Fq 'Would remove' "$tmp/plan"
grep -Fq 'Would remove: @haszno/cli (npm link)' "$tmp/plan"
grep -Fq 'Would remove: Claude MCP haszno' "$tmp/plan"
test -d "$HASZNO_HOME/haszno-cli"
test -f "$CLAUDE_CONFIG_DIR/.claude.json"
bash "$installer" --uninstall
for repo in haszno-cli haszno-mcp haszno-skill; do test ! -e "$HASZNO_HOME/$repo"; done
test ! -L "$npm_config_prefix/bin/haszno"
test ! -e "$CLAUDE_SKILL_DIR/haszno"
test ! -e "$CLAUDE_CONFIG_DIR/.claude.json"
test -f "$HASZNO_HOME/personal.txt"
test -f "$HOME/.config/haszno/config.json"
bash "$installer" --uninstall >/dev/null

# Legacy directories, a custom skill, an unrelated CLI and remote MCP survive.
mkdir -p "$HASZNO_HOME/haszno-cli" "$CLAUDE_SKILL_DIR/haszno" "$HOME/.local/bin"
printf 'keep\n' > "$HASZNO_HOME/haszno-cli/work.txt"
printf 'keep\n' > "$CLAUDE_SKILL_DIR/haszno/SKILL.md"
ln -s "$tmp/other-cli" "$HOME/.local/bin/haszno"
printf '{"mcpServers":{"haszno":{"type":"http","url":"https://example.invalid/mcp"}}}\n' > "$CLAUDE_CONFIG_DIR/.claude.json"
bash "$installer" --uninstall >/dev/null
test -f "$HASZNO_HOME/haszno-cli/work.txt"
test -f "$CLAUDE_SKILL_DIR/haszno/SKILL.md"
test "$(readlink "$HOME/.local/bin/haszno")" = "$tmp/other-cli"
grep -Fq 'https://example.invalid/mcp' "$CLAUDE_CONFIG_DIR/.claude.json"

# Exercise the default Git cloning path against local fixtures, without GitHub.
for repo in haszno-cli haszno-mcp haszno-skill; do
  src="$HASZNO_SRC_DIR/$repo"
  printf 'dist/\nnode_modules/\n.env\n' > "$src/.gitignore"
  git -C "$src" init -q
  git -C "$src" add .
  git -C "$src" -c user.name=Test -c user.email=test@example.invalid commit -qm fixture
  ln -s "$src/.git" "$src.git"
done
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
git config --global "url.file://$HASZNO_SRC_DIR/.insteadOf" https://github.com/haszno-labs/
export HASZNO_HOME="$HOME/git-install" CLAUDE_SKILL_DIR="$HOME/git-skills"
unset HASZNO_SRC_DIR
bash "$installer" >/dev/null
test -f "$HASZNO_HOME/haszno-cli/.haszno-installer-owned"
printf 'keep\n' > "$HASZNO_HOME/haszno-mcp/.env"
bash "$installer" --uninstall >/dev/null
test ! -e "$HASZNO_HOME/haszno-cli"
test ! -e "$HASZNO_HOME/haszno-skill"
test -f "$HASZNO_HOME/haszno-mcp/.env"
printf 'Installer/uninstaller checks passed.\n'
