# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-06

### Added

- SKILL.md with comprehensive Matrix Client-Server API instructions
  - Send messages (text, HTML, m.notice)
  - Create rooms (presets, power levels, encryption control)
  - Manage membership (invite, kick, ban, unban)
  - Read and modify power levels (read-modify-write pattern)
  - Read room history (pagination, filtering)
  - Reactions, redactions, user profiles
  - Room aliases and directory management
  - Reply and thread support (`m.relates_to`, `m.in_reply_to`)
  - Batch operations with 429 retry pattern
- `references/api-cheatsheet.md` — endpoint quick reference table
- `references/room-management.md` — room creation patterns, power level guide
- `references/troubleshooting.md` — common errors, OpenClaw-specific issues
- `scripts/install-jq.sh` — portable jq installer (no root, multi-platform)
- Bilingual README (EN/ZH) with language switch links
- Claude Code compatibility documentation
- jsdelivr CDN links for China mainland users
- China mirror support (`DOWNLOAD_URL` env) for jq download

[1.0.0]: https://github.com/Oaklight/matrix-skill/releases/tag/v1.0.0
