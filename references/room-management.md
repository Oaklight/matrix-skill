# Room Management Patterns

## Room creation presets

| Preset | Join rule | History visibility | Guest access | Power levels |
|--------|-----------|--------------------|--------------|--------------|
| `private_chat` | `invite` | `shared` | `can_join` | Creator PL 100 |
| `trusted_private_chat` | `invite` | `shared` | `can_join` | All members PL 100 |
| `public_chat` | `public` | `shared` | `forbidden` | Creator PL 100 |

## Encryption considerations

- `initial_state: []` → no encryption (explicit)
- Omitting `initial_state` → server default (usually no encryption, but some clients auto-add)
- Adding `m.room.encryption` to `initial_state` → encrypted room

For OpenClaw agent rooms, prefer **unencrypted** — encrypted rooms require Olm/Megolm key management that `curl` cannot handle.

## Power level defaults

```json
{
  "users_default": 0,
  "events_default": 0,
  "state_default": 50,
  "ban": 50,
  "kick": 50,
  "redact": 50,
  "invite": 0,
  "events": {
    "m.room.name": 50,
    "m.room.power_levels": 100,
    "m.room.history_visibility": 100,
    "m.room.canonical_alias": 50,
    "m.room.avatar": 50,
    "m.room.tombstone": 100,
    "m.room.server_acl": 100,
    "m.room.encryption": 100
  }
}
```

Power level values:
- **0** — normal user (can send messages, react)
- **50** — moderator (can kick, ban, set room name/topic)
- **100** — admin (can change power levels, room settings)

## Common room creation patterns

### Private team room (no encryption)

```bash
jq -n '{
  name: "team-room",
  topic: "Internal team discussion",
  preset: "private_chat",
  visibility: "private",
  invite: ["@alice:example.com", "@bob:example.com"],
  power_level_content_override: {
    users: {
      "@me:example.com": 100,
      "@alice:example.com": 50,
      "@bob:example.com": 50
    }
  },
  initial_state: []
}'
```

### DM room

```bash
jq -n '{
  is_direct: true,
  preset: "trusted_private_chat",
  invite: ["@alice:example.com"],
  initial_state: []
}'
```

### Public room with alias

```bash
jq -n '{
  name: "open-discussion",
  room_alias_name: "open-discussion",
  preset: "public_chat",
  visibility: "public",
  initial_state: []
}'
```

## Modifying power levels safely

Always read-modify-write. Never send a partial power levels object — the server replaces the entire state event.

```bash
# 1. Read current
PL=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.power_levels")

# 2. Modify (add admin)
NEW_PL=$(echo "$PL" | jq '.users["@alice:example.com"] = 100')

# 3. Write back
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$NEW_PL" \
  "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.power_levels/"
```

## Bulk room name resolution

```bash
for ROOM_ID in $(curl -s -H "Authorization: Bearer $TOKEN" \
  "$HS/_matrix/client/v3/joined_rooms" | jq -r '.joined_rooms[]'); do
  ENC=$(printf '%s' "$ROOM_ID" | jq -sRr @uri)
  NAME=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$HS/_matrix/client/v3/rooms/$ENC/state/m.room.name" | jq -r '.name // "(unnamed)"')
  echo "$ROOM_ID → $NAME"
done
```
