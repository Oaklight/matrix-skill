---
name: matrix
description: "Matrix Client-Server API via curl: send messages, create/manage rooms, invite members, set power levels, read history, and query room state. Works with any spec-compliant homeserver."
homepage: https://github.com/Oaklight/matrix-skill
metadata:
  {
    "openclaw":
      {
        "emoji": "🔗",
        "requires": { "bins": ["curl", "jq"] },
      },
  }
---

# Matrix Client-Server API

Operate any Matrix homeserver directly via `curl` + `jq`. Zero external dependencies beyond standard CLI tools.

This skill covers the **standard Client-Server API** (spec.matrix.org). It works with all compliant homeservers: Synapse, Dendrite, Tuwunel/Conduit, etc.

## References

- `references/api-cheatsheet.md`: endpoint quick reference with curl examples.
- `references/room-management.md`: room creation patterns, power levels, presets.
- `references/troubleshooting.md`: common errors and fixes.

## Prerequisites

1. A Matrix homeserver URL (e.g., `https://matrix.example.com`)
2. An access token for your Matrix account
3. `curl` and `jq` available in PATH

## Auth & Config

The skill expects two values — locate them from your environment:

```bash
# OpenClaw agents: token is typically in credentials
jq -r '.accessToken' ~/.openclaw/credentials/matrix/credentials.json

# Homeserver URL from OpenClaw config
jq -r '.channels.matrix.homeserver' ~/.openclaw/openclaw.json
```

For all commands below, set these first:

```bash
TOKEN="<your-access-token>"
HS="<homeserver-url>"  # e.g., https://matrix.example.com
```

Verify auth works:

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$HS/_matrix/client/v3/account/whoami" | jq .
```

## URL encoding

Room IDs contain `!` and `:` — always URL-encode them:

```bash
ROOM='!abcdef123:matrix.example.com'
ENC=$(printf '%s' "$ROOM" | jq -sRr @uri)
# Use $ENC in URL paths
```

## Send a message

```bash
TXN="msg-$(date +%s%N)"
BODY=$(jq -n --arg msg "Hello from the agent" '{msgtype:"m.text", body:$msg}')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN"
```

For multiline messages, write to a temp file and use `--rawfile`:

```bash
cat > /tmp/msg.txt <<'EOF'
Line one
Line two
EOF
BODY=$(jq -n --rawfile msg /tmp/msg.txt '{msgtype:"m.text", body:$msg}')
```

**Transaction ID**: each `PUT /send` requires a unique `txnId` in the URL. Use `date +%s%N` or a UUID. Re-using the same txnId is idempotent (won't double-send).

## Read room history

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/messages?dir=b&limit=20" \
  | jq -r '.chunk[] | "\(.sender): \(.content.body // "(no body)")"'
```

- `dir=b` — backward (newest first). Use `dir=f` for forward.
- `limit` — number of events to return (max varies by server, typically 100).
- `from` — pagination token from previous response's `end` field.

Filter to only `m.room.message` events:

```bash
FILTER='{"types":["m.room.message"]}'
FENC=$(printf '%s' "$FILTER" | jq -sRr @uri)
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/messages?dir=b&limit=20&filter=$FENC"
```

## Create a room

```bash
BODY=$(jq -n '{
  name: "my-room",
  topic: "Room description here",
  preset: "private_chat",
  visibility: "private",
  invite: ["@alice:example.com", "@bob:example.com"],
  power_level_content_override: {
    users: {
      "@me:example.com": 100,
      "@alice:example.com": 50
    }
  },
  initial_state: []
}')
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/createRoom" | jq .
```

Presets: `private_chat` (invite-only), `trusted_private_chat` (invite-only, all members PL 100), `public_chat` (joinable).

**Encryption**: omitting `m.room.encryption` from `initial_state` creates an **unencrypted** room. Some clients add encryption by default — if you explicitly want unencrypted, pass `initial_state: []`.

## Invite a user

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"@alice:example.com"}' \
  "$HS/_matrix/client/v3/rooms/$ENC/invite"
```

## Kick / ban

```bash
# Kick
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"@alice:example.com","reason":"optional reason"}' \
  "$HS/_matrix/client/v3/rooms/$ENC/kick"

# Ban
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"@alice:example.com","reason":"optional reason"}' \
  "$HS/_matrix/client/v3/rooms/$ENC/ban"
```

## Room state

### Get room name

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.name" | jq -r '.name'
```

### Set room name / topic

```bash
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"New Room Name"}' \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.name/"

curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"topic":"New topic"}' \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.topic/"
```

### Get power levels

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.power_levels" | jq .
```

### Set power levels

Fetch current → modify → PUT back (power levels must be sent as a complete object):

```bash
PL=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.power_levels")
NEW_PL=$(echo "$PL" | jq '.users["@alice:example.com"] = 100')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$NEW_PL" \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.power_levels/"
```

### List room members

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/joined_members" \
  | jq -r '.joined | keys[]'
```

## List joined rooms

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/joined_rooms" | jq -r '.joined_rooms[]'
```

To resolve room IDs to names, loop and fetch `m.room.name` state for each.

## Reactions

```bash
TXN="react-$(date +%s%N)"
BODY=$(jq -n --arg eid "$EVENT_ID" --arg emoji "👍" '{
  "m.relates_to": {
    rel_type: "m.annotation",
    event_id: $eid,
    key: $emoji
  }
}')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.reaction/$TXN"
```

## Redact (delete) a message

```bash
TXN="redact-$(date +%s%N)"
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"reason":"cleanup"}' \
  "$HS/_matrix/client/v3/rooms/$ENC/redact/$EVENT_ID/$TXN"
```

## User profile

```bash
# Get display name
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/profile/@alice:example.com/displayname" | jq -r '.displayname'

# Get avatar URL
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/profile/@alice:example.com/avatar_url" | jq -r '.avatar_url'
```

## Room directory (alias management)

```bash
# Resolve alias to room ID
ALIAS=$(printf '%s' "#my-room:example.com" | jq -sRr @uri)
curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/directory/room/$ALIAS" | jq .

# Set alias for a room
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"room_id\":\"$ROOM\"}" \
  "$HS/_matrix/client/v3/directory/room/$ALIAS"
```

## Script pattern for batch operations

When sending to multiple rooms or performing batch operations, write a shell script to `/tmp/` and execute it:

```bash
cat > /tmp/matrix_batch.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail
TOKEN=$(jq -r '.accessToken' ~/.openclaw/credentials/matrix/credentials.json)
HS="https://matrix.example.com"

# Retry helper: handles 429 rate limiting automatically
matrix_put() {
  local url="$1" data="$2" max_retries=3
  for attempt in $(seq 1 $max_retries); do
    resp=$(curl -s -w '\n%{http_code}' -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$data" "$url")
    http_code=$(echo "$resp" | tail -1)
    resp_body=$(echo "$resp" | sed '$d')
    if [ "$http_code" = "429" ]; then
      wait_ms=$(echo "$resp_body" | jq -r '.retry_after_ms // 2000')
      echo "  ⏳ rate limited, waiting ${wait_ms}ms (attempt $attempt/$max_retries)" >&2
      sleep "$(echo "scale=1; $wait_ms / 1000 + 0.5" | bc)"
    else
      echo "$resp_body"
      return 0
    fi
  done
  echo "  ❌ failed after $max_retries retries" >&2
  return 1
}

ROOMS=("!room1:example.com" "!room2:example.com")
MSG="Broadcast message"

for ROOM in "${ROOMS[@]}"; do
  ENC=$(printf '%s' "$ROOM" | jq -sRr @uri)
  TXN="batch-$(date +%s%N)"
  BODY=$(jq -n --arg msg "$MSG" '{msgtype:"m.text", body:$msg}')
  matrix_put "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN" "$BODY"
  echo " → sent to $ROOM"
done
SCRIPT
bash /tmp/matrix_batch.sh
```

## Important notes

- **Standard API only**: this skill uses the Matrix Client-Server API spec. It works identically on Synapse, Dendrite, Tuwunel/Conduit, and any compliant homeserver. Server-specific admin APIs (e.g., `/_synapse/admin/`, `/_conduit/`) are **not covered**.
- **Idempotent sends**: PUT with the same `txnId` won't duplicate. Always generate unique txnIds for distinct messages.
- **Rate limiting**: homeservers may return `429 Too Many Requests` with a `retry_after_ms` field. The batch script pattern above includes a `matrix_put` helper that parses `retry_after_ms` and retries automatically — use it (or similar) for any multi-request workflow.
- **Encoding**: room IDs, aliases, and user IDs in URL **paths** must be percent-encoded. In JSON **bodies** they go as-is.
- **Power level race**: always GET current power levels before PUT — never send a partial object.
