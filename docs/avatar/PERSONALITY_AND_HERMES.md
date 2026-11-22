# Avatar personality and Hermes

The personality set in Settings → Avatar (agent name, formality, humor,
enthusiasm, empathy, evolution stage) is applied by the user's own Hermes.

## Flow

1. `AvatarStateService` publishes the personality when it loads and whenever the
   name, a trait or the stage changes (`onPersonalityChanged`).
2. `HermesStreamingService.reportPersonality` POSTs it to
   `/api/pistisai/personality` on the Hermes API server (default
   `127.0.0.1:8642`), with the same API key as chat. If Hermes is not reachable,
   it is sent again before the next chat message. A plugin without the route
   answers 404 and the app stops retrying.
3. The bundled `pistisai` plugin stores it in `$HERMES_HOME/personality.json`
   (only known fields; traits clamped to 0..1; name stripped of control
   characters) and its `pre_llm_call` hook adds a short tone block to each turn.

The tone wording mirrors `services/openclaw-skills/pistisai/prompt.ts`, so both
runtimes describe the same personality the same way.

## Routes (plugin, same auth as the Hermes API server)

| Method | Path | Body / result |
|---|---|---|
| GET | `/api/pistisai/personality` | `{ "personality": { ... } }` |
| POST | `/api/pistisai/personality` | `agent_name`, `traits` (4 numbers 0..1), `evolution_stage` |
| DELETE | `/api/pistisai/personality` | clears the file |

## Switches (environment of the Hermes process)

- `AIGENT_PERSONALITY_DISABLE=1`: do not add the personality block.
- `AIGENT_AWARENESS_DISABLE=1`: disables the awareness block only; the
  personality block is still added.

## Privacy

The personality block is part of the prompt, so it goes to whichever model
provider Hermes is configured to use, like the conversation itself. See
`docs/governance/legal/PRIVACY.md` section 2.2.

## Tests

- `test/hermes-plugins/test_pistisai_personality.py` (plugin; run with
  `python3 -m unittest`).
- `test/services/hermes/hermes_personality_report_test.dart`
- `test/services/avatar/avatar_personality_publish_test.dart`
