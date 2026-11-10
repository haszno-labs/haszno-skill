# haszno-skill

**English** | [Magyar](README.hu.md)

**Haszno Claude skill and unified installer** — the AI agent skill for the Haszno
dropshipping automation SaaS ([haszno.com](https://haszno.com)), plus the `install.sh`
script that installs the CLI, the MCP server, and this skill in one step.

---

## What is this?

This repo contains two things:

1. **`skills/haszno/`** — a Claude Code skill that teaches AI agents how to use the Haszno
   tools (MCP and CLI) safely.
2. **`install.sh`** — a single installer script that installs all Haszno packages
   (`haszno-cli`, `haszno-mcp`, this skill) in one step.

---

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/haszno-labs/haszno-skill/main/install.sh | bash
```

Or by cloning:

```bash
git clone https://github.com/haszno-labs/haszno-skill.git /tmp/haszno-skill-install
bash /tmp/haszno-skill-install/install.sh
```

### Local source (for development):

```bash
HASZNO_SRC_DIR=~/Documents/medusa-shops/haszno-labs \
  bash install.sh
```

Revert all changes with `--uninstall`:

```bash
bash ~/.haszno/haszno-skill/install.sh --uninstall
```

---

## Configuration

```bash
export HASZNO_API_URL=https://haszno.com
export HASZNO_API_KEY=your-api-key
```

The legacy `ARFUTAR_API_URL` / `ARFUTAR_API_KEY` env vars and the `~/.config/arfutar`
directory are also read silently if `~/.config/haszno` does not yet exist —
backward-compatible.

---

## Loading the skill in Claude Code

After installation the skill is automatically available at `~/.claude/skills/haszno/`.
Keywords such as `haszno`, `haszno.com`, `dropshipping`, `árajánlat`, `automatika`,
`termékötlet` and similar automatically load it.

---

## Registering the MCP server in Claude Code

```bash
claude mcp add haszno --scope user -- node ~/.haszno/haszno-mcp/dist/index.js
```

`install.sh` does this automatically if the `claude` command is available.

---

## Related repos

These three repos together form the Haszno agent SDK:

| Repo | Description |
|---|---|
| [haszno-labs/haszno-cli](https://github.com/haszno-labs/haszno-cli) | `haszno` CLI — from shell and cron |
| [haszno-labs/haszno-mcp](https://github.com/haszno-labs/haszno-mcp) | MCP server — for Claude Desktop / Claude Code |
| [haszno-labs/haszno-skill](https://github.com/haszno-labs/haszno-skill) | Claude skill + unified installer (this repo) |

**How they work together:**

- The **skill** (`skills/haszno/SKILL.md`) tells the agent when and how to use the Haszno
  tools: it prefers the MCP in an interactive Claude Desktop / Claude Code session, and falls
  back to the CLI when MCP is unavailable.
- The **CLI** and the **MCP** share the same API key and configuration directory
  (`~/.config/haszno`), so `haszno login` (or setting the env vars) configures both at once.
- `install.sh` (in this repo) installs all three packages in a single run.

---

## Documentation

Full developer docs: [https://docs.haszno.com/en/](https://docs.haszno.com/en/)

---

## Requirements

- `git`
- `node >= 20`
- `npm`
- `claude` _(optional — required for automatic MCP registration)_

---

## License

MIT — see [LICENSE](LICENSE).
