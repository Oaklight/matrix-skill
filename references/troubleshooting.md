# Troubleshooting

## Common errors

### `M_UNKNOWN_TOKEN` / 401

Token expired or invalid.

```json
{"errcode": "M_UNKNOWN_TOKEN", "error": "Invalid access token."}
```

**Fix**: Re-read the token from credentials. For OpenClaw agents:

```bash
TOKEN=$(jq -r '.accessToken' ~/.openclaw/credentials/matrix/credentials.json)
```

If still failing, the token may have been rotated by the gateway. Check if OpenClaw stores a newer token in its internal state.

### `M_FORBIDDEN` / 403

Insufficient permissions. Common causes:

- Not a member of the room
- Power level too low for the operation (e.g., trying to kick without PL ≥ 50)
- Room is invite-only and you haven't been invited

**Fix**: Check your membership and power level:

```bash
# Am I in the room?
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/joined_members" | jq '.joined | keys[]'

# What's my power level?
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.power_levels" \
  | jq --arg me "@me:example.com" '.users[$me] // .users_default'
```

### `M_NOT_FOUND` / 404

Room or event doesn't exist, or you're not a member.

Note: Matrix returns 404 for rooms you're not in, even if they exist. This is by design — you can't distinguish "doesn't exist" from "you don't have access".

### `M_LIMIT_EXCEEDED` / 429

Rate limited. Response includes `retry_after_ms`:

```json
{"errcode": "M_LIMIT_EXCEEDED", "retry_after_ms": 2000}
```

**Fix**: Wait and retry:

```bash
sleep $((retry_after_ms / 1000 + 1))
```

### `M_BAD_JSON` / 400

Malformed request body. Common causes:

- Forgot `Content-Type: application/json` header
- Shell variable expansion broke the JSON (use `jq -n` to build JSON safely)
- Sending partial power_levels object (must send complete object)

### Room ID encoding issues

Room IDs like `!abc:example.com` contain `!` and `:` which must be URL-encoded in paths.

**Wrong**: `curl ... /rooms/!abc:example.com/...`
**Right**: URL-encode first:

```bash
ENC=$(printf '%s' '!abc:example.com' | jq -sRr @uri)
curl ... "/rooms/$ENC/..."
```

## OpenClaw-specific issues

### sessions_send vs direct API

`sessions_send` routes a message as input to another session's agent. The agent then decides whether to relay it to the Matrix room. If the agent's group chat policy says "lurk" or the message looks like inter-session data, it may respond with `NO_REPLY` and the message never reaches the room.

**Fix**: To guarantee a message appears in a Matrix room, use direct API:

```bash
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN"
```

### Token location

OpenClaw may store the Matrix access token in multiple places:

1. `~/.openclaw/credentials/matrix/credentials.json` (preferred)
2. `~/.openclaw/openclaw.json` → `channels.matrix.accessToken` (config file)

The credentials file is the live token; the config file value may be stale.

### Cross-session isolation

Each Matrix room maps to a separate OpenClaw session. Agent state, tool results, and conversation history do **not** cross session boundaries.

To share information across sessions:
- Write to shared files (`memory/`, workspace files)
- Use Matrix API directly to read room history from another room
- Use `memory_search` to find information written by other sessions

### Shell escaping in scripts

When writing scripts to `/tmp/`, avoid `$(...)` inside heredocs unless using `<<'EOF'` (single-quoted delimiter prevents expansion):

```bash
# WRONG — $(...) expands during heredoc creation
cat > /tmp/script.sh <<EOF
TOKEN=$(jq -r '.accessToken' file.json)
EOF

# RIGHT — single-quoted EOF prevents expansion
cat > /tmp/script.sh <<'EOF'
TOKEN=$(jq -r '.accessToken' file.json)
EOF
```
