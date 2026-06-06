# Matrix Client-Server API — Quick Reference

All endpoints use base URL `$HS/_matrix/client/v3` unless noted otherwise.

All requests require header: `Authorization: Bearer $TOKEN`

## Identity

| Action | Method | Endpoint |
|--------|--------|----------|
| Who am I | GET | `/account/whoami` |
| Get profile | GET | `/profile/{userId}` |
| Get display name | GET | `/profile/{userId}/displayname` |
| Get avatar | GET | `/profile/{userId}/avatar_url` |

## Rooms — Discovery

| Action | Method | Endpoint |
|--------|--------|----------|
| List joined rooms | GET | `/joined_rooms` |
| Resolve alias | GET | `/directory/room/{roomAlias}` |
| Room summary | GET | `v1/room_summary/{roomIdOrAlias}` |
| Public rooms | GET | `/publicRooms` |
| Search users | POST | `/user_directory/search` |

## Rooms — Create & Join

| Action | Method | Endpoint |
|--------|--------|----------|
| Create room | POST | `/createRoom` |
| Join room | POST | `/join/{roomIdOrAlias}` |
| Leave room | POST | `/rooms/{roomId}/leave` |
| Forget room | POST | `/rooms/{roomId}/forget` |

## Rooms — Membership

| Action | Method | Endpoint |
|--------|--------|----------|
| Invite user | POST | `/rooms/{roomId}/invite` |
| Kick user | POST | `/rooms/{roomId}/kick` |
| Ban user | POST | `/rooms/{roomId}/ban` |
| Unban user | POST | `/rooms/{roomId}/unban` |
| List members | GET | `/rooms/{roomId}/joined_members` |
| Member details | GET | `/rooms/{roomId}/members` |

## Rooms — State

| Action | Method | Endpoint |
|--------|--------|----------|
| Get all state | GET | `/rooms/{roomId}/state` |
| Get state event | GET | `/rooms/{roomId}/state/{type}/{stateKey}` |
| Set state event | PUT | `/rooms/{roomId}/state/{type}/{stateKey}` |

Common state event types:
- `m.room.name` — room name (`{name: "..."}`)
- `m.room.topic` — room topic (`{topic: "..."}`)
- `m.room.power_levels` — power levels (complex object, always GET before PUT)
- `m.room.join_rules` — join rules (`{join_rule: "invite|public|knock"}`)
- `m.room.history_visibility` — history visibility (`{history_visibility: "shared|invited|joined|world_readable"}`)

## Messaging

| Action | Method | Endpoint |
|--------|--------|----------|
| Send message | PUT | `/rooms/{roomId}/send/{eventType}/{txnId}` |
| Read history | GET | `/rooms/{roomId}/messages?dir=b&limit=N` |
| Get single event | GET | `/rooms/{roomId}/event/{eventId}` |
| Redact event | PUT | `/rooms/{roomId}/redact/{eventId}/{txnId}` |

Message body for `m.room.message`:
```json
{"msgtype": "m.text", "body": "Hello"}
```

Other msgtypes: `m.notice` (bot output), `m.emote` (/me), `m.image`, `m.file`, `m.video`, `m.audio`.

## Reactions

| Action | Method | Endpoint |
|--------|--------|----------|
| Send reaction | PUT | `/rooms/{roomId}/send/m.reaction/{txnId}` |

Body:
```json
{
  "m.relates_to": {
    "rel_type": "m.annotation",
    "event_id": "$target_event_id",
    "key": "👍"
  }
}
```

## Room Aliases

| Action | Method | Endpoint |
|--------|--------|----------|
| Set alias | PUT | `/directory/room/{roomAlias}` |
| Delete alias | DELETE | `/directory/room/{roomAlias}` |
| List aliases | GET | `/rooms/{roomId}/aliases` |

## Sync (advanced)

| Action | Method | Endpoint |
|--------|--------|----------|
| Sync | GET | `/sync?timeout=30000&since={nextBatch}` |

## Media (v1 endpoints)

| Action | Method | Endpoint |
|--------|--------|----------|
| Upload | POST | `/_matrix/media/v3/upload` |
| Download | GET | `/_matrix/media/v3/download/{serverName}/{mediaId}` |
| Thumbnail | GET | `/_matrix/media/v3/thumbnail/{serverName}/{mediaId}` |

## HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Bad request (malformed JSON, missing fields) |
| 403 | Forbidden (insufficient power level, not in room) |
| 404 | Not found (room/event doesn't exist or you're not a member) |
| 429 | Rate limited — check `retry_after_ms` in response body |
