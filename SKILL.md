---
name: matrix
version: 1.0.0
description: "Matrix Client-Server API via curl: send messages, create/manage rooms, invite members, set power levels, read history, and query room state. Works with any spec-compliant homeserver."
homepage: https://github.com/Oaklight/matrix-skill
metadata:
  openclaw:
    emoji: "🔗"
    requires:
      bins:
        - curl
        - jq
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

If `jq` is not installed, use the bundled installer (no root required, CDN-accelerated by default):

```bash
bash scripts/install-jq.sh           # installs to ~/.local/bin/jq
bash scripts/install-jq.sh ./bin      # or a custom directory
export PATH="$HOME/.local/bin:$PATH"  # ensure it's in PATH
```

## Auth & Config

The skill expects two values. Prefer the standalone Matrix config path when available:

```bash
jq -r '.accessToken' ~/.config/matrix/credentials.json
jq -r '.homeserver' ~/.config/matrix/config.json
```

OpenClaw agents may instead use their own config paths:

```bash
jq -r '.accessToken' ~/.openclaw/credentials/matrix/credentials.json
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

### Formatted messages (HTML)

To send bold, links, code blocks, or other rich formatting, include `format` and `formatted_body` alongside the plain-text `body`:

```bash
TXN="msg-$(date +%s%N)"
BODY=$(jq -n '{
  msgtype: "m.text",
  body: "**bold** and a link: https://example.com",
  format: "org.matrix.custom.html",
  formatted_body: "<strong>bold</strong> and a link: <a href=\"https://example.com\">example.com</a>"
}')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN"
```

The plain-text `body` is the **mandatory fallback** — clients that don't render HTML display it instead. Keep both in sync.

Common HTML subset supported by most clients:

- `<strong>`, `<em>`, `<del>`, `<code>`, `<pre>` — inline formatting
- `<a href="...">` — links
- `<blockquote>` — quotes
- `<ol>`, `<ul>`, `<li>` — lists
- `<br>` — line breaks (or use `<p>` blocks)
- `<h1>`–`<h6>` — headings (limited client support)

### Sending as a notice

Use `m.notice` instead of `m.text` for bot/automated output. Well-behaved clients render notices with reduced prominence and don't trigger notification sounds:

```bash
BODY=$(jq -n --arg msg "Automated status update" '{
  msgtype: "m.notice",
  body: $msg
}')
```

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

## Leave / forget a room

Leave a room you're currently in:

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "$HS/_matrix/client/v3/rooms/$ENC/leave"
```

After leaving, the room still appears in your room list (as a "left" room) and history is accessible. To **permanently remove** it from your room list, call forget:

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "$HS/_matrix/client/v3/rooms/$ENC/forget"
```

**Key points**:
- You must **leave** before you can **forget** — calling forget on a room you're still in will fail.
- Forgetting is irreversible: the server discards your membership record. You can rejoin (if the room allows it), but previous history may not be visible depending on the room's `history_visibility` setting.
- To leave and forget in one go: leave first, then forget.

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

## Replies

To reply to a specific message, add `m.relates_to` with `m.in_reply_to`. The plain-text `body` **must** include the fallback quote prefix — clients that don't render rich replies use it to show context:

```bash
TXN="reply-$(date +%s%N)"
BODY=$(jq -n \
  --arg eid "$EVENT_ID" \
  --arg sender "@alice:example.com" \
  --arg orig "original message text" \
  --arg reply "My reply here" '{
  msgtype: "m.text",
  body: "> <\($sender)> \($orig)\n\n\($reply)",
  format: "org.matrix.custom.html",
  formatted_body: "<mx-reply><blockquote><a href=\"https://matrix.to/#/!roomid:example.com/\($eid)\">In reply to</a> <a href=\"https://matrix.to/#/\($sender)\">\($sender)</a><br>\($orig)</blockquote></mx-reply>\($reply)",
  "m.relates_to": {
    "m.in_reply_to": {
      event_id: $eid
    }
  }
}')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN"
```

**Fallback body format**: `> <@user:server> original text` followed by a blank line and the reply. Omitting this is the most common agent mistake — the reply will appear orphaned in clients that don't parse `m.relates_to`.

## Threads

Threads use `rel_type: "m.thread"`. The `event_id` points to the **root** event of the thread (the first message), not the message you're replying to within the thread:

```bash
TXN="thread-$(date +%s%N)"
BODY=$(jq -n \
  --arg root "$THREAD_ROOT_EVENT_ID" \
  --arg msg "Thread reply" '{
  msgtype: "m.text",
  body: $msg,
  "m.relates_to": {
    rel_type: "m.thread",
    event_id: $root,
    is_falling_back: true,
    "m.in_reply_to": {
      event_id: $root
    }
  }
}')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN"
```

To reply to a **specific message within a thread**, keep `event_id` as the thread root but set `m.in_reply_to.event_id` to the target message:

```bash
BODY=$(jq -n \
  --arg root "$THREAD_ROOT_EVENT_ID" \
  --arg target "$TARGET_EVENT_ID" \
  --arg msg "Reply to a specific message in thread" '{
  msgtype: "m.text",
  body: $msg,
  "m.relates_to": {
    rel_type: "m.thread",
    event_id: $root,
    is_falling_back: false,
    "m.in_reply_to": {
      event_id: $target
    }
  }
}')
```

### `is_falling_back` explained

The `is_falling_back` boolean tells clients how to interpret the `m.in_reply_to` field:

- **`is_falling_back: true`** — the `m.in_reply_to` is **not** a genuine reply; it exists only as a fallback so that clients without thread support still render the message as a reply to the thread root. This is the normal case when simply posting to a thread without replying to a specific message within it.
- **`is_falling_back: false`** — the `m.in_reply_to` is a **genuine reply** to a specific message inside the thread. Thread-aware clients show it as an in-thread reply; non-thread-aware clients show it as a regular reply.

Rule of thumb: set `is_falling_back: true` when `m.in_reply_to.event_id` equals the thread root (no specific reply target), and `false` when it points to a different message within the thread.

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

## Edit a message (m.replace)

To edit a previously sent message, send a new `m.room.message` event with `m.relates_to` containing `rel_type: "m.replace"` and the `event_id` of the original message. The new content goes inside `m.new_content`; the top-level `body` serves as a fallback for clients that don't support edits (prefix it with `* ` by convention):

```bash
TXN="edit-$(date +%s%N)"
BODY=$(jq -n \
  --arg eid "$ORIGINAL_EVENT_ID" \
  --arg msg "corrected text" '{
  msgtype: "m.text",
  body: "* \($msg)",
  "m.new_content": {
    msgtype: "m.text",
    body: $msg
  },
  "m.relates_to": {
    rel_type: "m.replace",
    event_id: $eid
  }
}')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN"
```

To edit a message with HTML formatting, include `format` and `formatted_body` inside `m.new_content` (and in the top-level fallback):

```bash
BODY=$(jq -n \
  --arg eid "$ORIGINAL_EVENT_ID" \
  --arg msg "corrected **bold** text" \
  --arg html "corrected <strong>bold</strong> text" '{
  msgtype: "m.text",
  body: "* \($msg)",
  format: "org.matrix.custom.html",
  formatted_body: "* \($html)",
  "m.new_content": {
    msgtype: "m.text",
    body: $msg,
    format: "org.matrix.custom.html",
    formatted_body: $html
  },
  "m.relates_to": {
    rel_type: "m.replace",
    event_id: $eid
  }
}')
```

**Key points**:
- You can only edit your own messages.
- `m.new_content` holds the full replacement content — it completely replaces the original content.
- The top-level `body` with the `* ` prefix is a **fallback** for clients that don't understand `m.replace`.
- Each edit is a new event; the original `event_id` remains stable. Clients aggregate edits by `m.replace` relation.

## Upload and send media

Sending images, files, audio, or video is a two-step process: **upload** the file to the homeserver's content repository, then **send** a message referencing the returned `mxc://` URI.

### Step 1 — Upload

```bash
# Upload a file and capture the mxc:// URI
MXC=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: image/png" \
  --data-binary @/path/to/image.png \
  "$HS/_matrix/media/v3/upload?filename=image.png" \
  | jq -r '.content_uri')
echo "$MXC"   # e.g., mxc://example.com/AbCdEfG
```

Set `Content-Type` to the file's actual MIME type (e.g., `image/jpeg`, `application/pdf`, `video/mp4`). The `filename` query parameter is optional but recommended — clients display it as the download name.

### Step 2 — Send the media message

Use the appropriate `msgtype` for the content:

| Type | msgtype | Required fields |
|------|---------|----------------|
| Image | `m.image` | `url` |
| File | `m.file` | `url`, `filename` |
| Video | `m.video` | `url` |
| Audio | `m.audio` | `url` |

```bash
# Send an image
TXN="media-$(date +%s%N)"
BODY=$(jq -n --arg mxc "$MXC" '{
  msgtype: "m.image",
  body: "image.png",
  url: $mxc,
  info: {
    mimetype: "image/png"
  }
}')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HS/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN"
```

The `body` field is the **text fallback** (typically the filename). The optional `info` object can include `mimetype`, `size` (bytes), `w` and `h` (pixels, for images/video), and `duration` (ms, for audio/video).

```bash
# Send a generic file
BODY=$(jq -n --arg mxc "$MXC" '{
  msgtype: "m.file",
  body: "report.pdf",
  url: $mxc,
  filename: "report.pdf",
  info: {
    mimetype: "application/pdf",
    size: 204800
  }
}')
```

### Download media

Convert an `mxc://` URI to an HTTP download URL:

```bash
# mxc://example.com/AbCdEfG → server_name=example.com, media_id=AbCdEfG
SERVER="example.com"
MEDIA_ID="AbCdEfG"
curl -s -o output.png \
  -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/media/v3/download/$SERVER/$MEDIA_ID"
```

For thumbnails (images only):

```bash
curl -s -o thumb.png \
  -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/media/v3/thumbnail/$SERVER/$MEDIA_ID?width=320&height=240&method=scale"
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
