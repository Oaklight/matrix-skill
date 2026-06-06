# matrix-skill

[English](README_en.md)

一个 [OpenClaw](https://github.com/openclaw/openclaw) / [Claude Code](https://code.claude.com) 技能，用于通过标准 Client-Server API 操作 [Matrix](https://matrix.org) 服务器。

## 功能

教 AI agent 使用 `curl` + `jq` 与任意 Matrix 服务器交互，零外部依赖。

**支持的操作：**

- 💬 向任意已加入的房间发送消息
- 🏠 创建房间（自定义权限、预设、邀请）
- 👥 成员管理（邀请、踢出、封禁、解封）
- 🔑 读取和修改权限等级
- 📜 读取房间历史，支持分页和过滤
- 🏷️ 管理房间状态（名称、话题、加入规则）
- 👤 查询用户资料
- 😀 发送表情回应、撤回消息
- 📡 批量操作多个房间

## 为什么需要这个

OpenClaw 内置的 Matrix channel 会把消息 *路由到* agent session — 由 agent 决定是否转发。这意味着 `sessions_send` 到群聊房间可能会被 agent 的 lurk 策略吞掉。

这个 skill 教 agent **绕过 session 层**，直接调用 Matrix API，确保消息送达。区别在于「让别人帮你发」和「自己直接发」。

## 兼容性

仅使用 [Matrix Client-Server API 规范](https://spec.matrix.org/latest/client-server-api/)，兼容所有实现：

- [Synapse](https://github.com/element-hq/synapse)（Python，参考实现）
- [Dendrite](https://github.com/element-hq/dendrite)（Go）
- [Tuwunel](https://github.com/girlbossceo/tuwunel) / Conduit（Rust）
- 任何符合规范的服务器

**不覆盖**各服务器的私有管理 API（`/_synapse/admin/`、`/_conduit/` 等）。

## 安装

### OpenClaw

```bash
# 从 ClawHub
openclaw skills install matrix

# 从源码
git clone https://github.com/Oaklight/matrix-skill.git
cp -r matrix-skill ~/.openclaw/plugin-skills/matrix
```

### Claude Code

本 skill 遵循 [Agent Skills](https://agentskills.io) 开放标准，原生支持 Claude Code。

```bash
# 个人 skill（所有项目可用）
git clone https://github.com/Oaklight/matrix-skill.git
cp -r matrix-skill ~/.claude/skills/matrix

# 项目 skill（仅当前 repo）
mkdir -p .claude/skills
cp -r matrix-skill .claude/skills/matrix
```

安装后，Claude Code 会在需要 Matrix 操作时自动加载，或者直接用 `/matrix` 调用。

## 前置条件

- `curl` 和 `jq`（大多数系统自带）
- Matrix access token
- 能访问你的 homeserver

## 兼容性

| 平台 | 状态 | 安装路径 |
|------|------|----------|
| **OpenClaw** | ✅ 完全支持 | `~/.openclaw/plugin-skills/matrix/` |
| **Claude Code** | ✅ 完全支持 | `~/.claude/skills/matrix/` 或 `.claude/skills/matrix/` |
| **其他 SKILL.md agent** | ✅ 兼容 | 遵循 [Agent Skills](https://agentskills.io) 开放标准 |

SKILL.md frontmatter 包含 OpenClaw 特有元数据和标准字段，各平台会自动忽略不识别的字段。

## 文件结构

```
matrix-skill/
├── SKILL.md                          # 主技能指令
├── references/
│   ├── api-cheatsheet.md             # API 端点速查
│   ├── room-management.md            # 房间管理模式与权限
│   └── troubleshooting.md            # 常见错误与解决
├── README.md → README_en.md
├── README_en.md
└── README_zh.md
```

## 许可证

[MIT](LICENSE)
