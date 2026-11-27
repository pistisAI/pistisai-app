# Local agent data export and deletion

Client-facing tools for on-device agent data. Use them from **Settings → Storage → Local agent data**.

Local wipe completes in seconds on a typical install (well under the “few hours” compliance target). Cloud account deletion is a separate request to the authentication provider and is not part of this one-action local wipe.

## What is included

| Store | Path / location | Export | Delete |
| --- | --- | --- | --- |
| Local brain (SQLite) | App support dir `local_brain.sqlite` | Yes (all tables as JSON) | Yes (all rows) |
| Encrypted conversation file | App docs/support `Pistisai/conversations.json.enc` (desktop) | Yes (embedded under `conversationsFile`) | Yes |
| Avatar Markdown files | `personality.md`, `memory.md`, `context.md` in the agent skill folder (e.g. `~/.openclaw/skills/pistisai`); plain text | No | Yes (only these three files) |
| Temporary captures | App-owned `<temp>/pistisai-captures` folder, owner-only (0700) on macOS/Linux, falling back to the app support folder if the temp one is a symlink or owned by someone else (screenshots, camera frames, TTS audio); plain files | No | Yes (whole folder) |
| Agent runtime transcript | Kept by the runtime (e.g. Hermes) where it runs | No | No; the app stops importing messages from before the wipe, clear it in the runtime |
| App settings JSON export | Settings → System → Export | Separate settings-only export | Not cleared by this wipe |
| Auth / secure storage | Platform keychain / secure storage | Not exported (secrets) | Not cleared by this wipe |
| Cloudflare Access identity | Hosted identity provider | N/A (no app-held secret) | Managed by the identity provider, not this app |

### Local brain tables wiped

All Drift tables in `local_brain.sqlite` are cleared, including:

- Conversations and messages
- Main chat timeline records
- Agent logs, events, sync queue
- File index / content cache
- LLM provider rows and request history
- Avatar profiles, memories, achievements, personality, evolution history
- Clipboard / action history / macros
- Conscience thoughts and decisions
- Coordinator states and votes

After wipe, non-user infrastructure seeds are recreated (model capacity rate-limit rows and default agent identities) so the app keeps running. Those seeds are not your conversation or memory content.

## How to export

1. Open **Settings → Storage**.
2. Under **Local agent data**, choose **Export all local data**.
3. Save the JSON file when prompted (or download it on web).

### Export format

```json
{
  "version": "1.0",
  "format": "pistisai-local-agent-data",
  "exportedAt": "2026-11-15T12:00:00.000Z",
  "tables": { "conversations": [ ... ], "messages": [ ... ] },
  "rowCounts": { "conversations": 1, "messages": 2 },
  "conversationsFile": { "conversations": [ ... ] }
}
```

`conversationsFile` is present on desktop when the encrypted conversation store is available.

## How to delete (one action)

1. Export first if you want a copy.
2. Open **Settings → Storage → Local agent data**.
3. Choose **Delete all local data** and confirm.

The app:

1. Deletes every row in `local_brain.sqlite`
2. Clears the encrypted conversation file store (desktop)
3. Deletes the avatar Markdown files and the temporary captures folder (desktop)
4. Reseeds infrastructure defaults
5. Verifies user-content tables are empty and no conversation, Markdown or capture files remain
6. Records the wipe time so the chat no longer imports runtime messages from before it
7. Shows success with measured duration in milliseconds

## How to verify deletion

### In the app

A successful delete snackbar reports that data was deleted and verified empty, with the duration in ms. If verification finds remaining user-content rows, the incomplete-deletion message is shown instead.

### On disk (desktop)

1. Quit the app.
2. Confirm `local_brain.sqlite` user tables are empty, or delete the file and restart (the app recreates an empty DB with seeds).
3. Confirm `Pistisai/conversations.json.enc` is gone or empty under the app support/documents directory.
4. Optionally re-open the app and export again: `rowCounts` for conversations/messages/memories should be `0`, and `conversationsFile.total_conversations` should be `0` when present.

### Programmatic check

`LocalAgentDataPortabilityService.verifyDeletion()` returns `isEmpty: true` when every user-content table has zero rows and no conversation files, avatar Markdown files or temporary captures remain (`remainingPlainFiles` lists any that do). System seed tables (`model_capacity`, `agent_identities`) may still have rows after a successful wipe.

## Timing

| Step | Typical duration |
| --- | --- |
| Local export | Seconds |
| Local delete + verify | Seconds |
| Cloud account deletion (separate) | Provider-dependent; target within a few hours after a verified request |

## Related

- Privacy policy: `docs/governance/legal/PRIVACY.md` §7–8
- Settings-only export/import: Settings → System
- Admin cloud flush (operators only): admin data flush screen — not the client tool above
