# matrix-skill

[中文版](README_zh.md)

An [OpenClaw](https://github.com/openclaw/openclaw) / [Claude Code](https://code.claude.com) skill for operating [Matrix](https://matrix.org) homeservers via the standard Client-Server API.

## What it does

Teaches AI agents to interact with any Matrix homeserver using `curl` + `jq` — zero external dependencies.

**Capabilities:**

- 💬 Send messages to any joined room
- 🏠 Create rooms with custom presets, power levels, and invites
- 👥 Manage membership (invite, kick, ban, unban)
- 🔑 Read and modify power levels
- 📜 Read room history with pagination and filtering
- 🏷️ Manage room state (name, topic, join rules)
- 👤 Query user profiles
- 😀 Send reactions, redact messages
- 📡 Batch operations across multiple rooms

## Why this exists

OpenClaw's built-in Matrix channel routes messages *through* agent sessions — the agent decides whether to relay. This means `sessions_send` to a group chat room might get swallowed by the agent's lurk policy.

This skill teaches the agent to **bypass the session layer** and talk directly to the Matrix API when guaranteed delivery matters. It's the difference between "ask someone to post for you" and "post it yourself".

## Compatibility

Uses only the [Matrix Client-Server API spec](https://spec.matrix.org/latest/client-server-api/). Works with:

- [Synapse](https://github.com/element-hq/synapse) (Python, reference implementation)
- [Dendrite](https://github.com/element-hq/dendrite) (Go)
- [Tuwunel](https://github.com/girlbossceo/tuwunel) / Conduit (Rust)
- Any spec-compliant homeserver

Does **not** cover server-specific admin APIs (`/_synapse/admin/`, `/_conduit/`, etc.).

## Installation

### OpenClaw

```bash
# From ClawHub
openclaw skills install matrix

# From source
git clone https://github.com/Oaklight/matrix-skill.git
cp -r matrix-skill ~/.openclaw/plugin-skills/matrix
```

### Claude Code

This skill follows the [Agent Skills](https://agentskills.io) open standard and works natively with Claude Code.

```bash
# Personal skill (available across all projects)
git clone https://github.com/Oaklight/matrix-skill.git
cp -r matrix-skill ~/.claude/skills/matrix

# Project skill (scoped to one repo)
mkdir -p .claude/skills
cp -r matrix-skill .claude/skills/matrix
```

Once installed, Claude Code will auto-load the skill when Matrix operations are relevant, or you can invoke it directly with `/matrix`.

## Prerequisites

- `curl` and `jq` (standard on most systems)
- A Matrix access token
- Network access to your homeserver

## Compatibility

| Platform | Status | Install path |
|----------|--------|-------------|
| **OpenClaw** | ✅ Full support | `~/.openclaw/plugin-skills/matrix/` |
| **Claude Code** | ✅ Full support | `~/.claude/skills/matrix/` or `.claude/skills/matrix/` |
| **Any SKILL.md agent** | ✅ Compatible | Follows [Agent Skills](https://agentskills.io) open standard |

The SKILL.md frontmatter includes both OpenClaw-specific metadata and standard fields. Platforms ignore unknown fields gracefully.

## File structure

```
matrix-skill/
├── SKILL.md                          # Main skill instructions
├── references/
│   ├── api-cheatsheet.md             # Endpoint quick reference
│   ├── room-management.md            # Room patterns & power levels
│   └── troubleshooting.md            # Common errors & fixes
├── README.md → README_en.md
├── README_en.md
└── README_zh.md
```

## License

[MIT](LICENSE)
