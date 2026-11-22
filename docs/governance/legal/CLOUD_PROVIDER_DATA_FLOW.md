# Cloud provider data flow (opt-in)

Pistisai defaults to **local-only** operation. Optional cloud integrations stay
in the codebase but do not send data until the user turns them on in
**Settings → General**. Compile-time API keys alone are not consent.

Governance: shipping or enabling a build that sends personal information to
these providers for a client deployment requires EFVP review before that
outbound path is used in production. The in-app switches below are the
client-facing consent controls (Loi 25 / privacy-by-default).

## Controls

| Setting | Default | What it unlocks |
| --- | --- | --- |
| Allow cloud LLM providers | Off | Zhipu/GLM, Moonshot/Kimi, Google Gemini adapters |
| Allow Microsoft online speech | Off | `edge-tts` → Microsoft online speech |

Local agent runtimes (Hermes, OpenClaw) and local support providers (Ollama,
LM Studio) are unchanged by these switches.

## Data sent when enabled

### Zhipu / GLM (`open.bigmodel.cn`)

- **Trigger:** user (or a client of the local router) selects a Zhipu/GLM model
  after cloud LLM providers are enabled and `GLM_API_KEY` is present in the
  build.
- **Payload:** chat completion request — model id, message roles/content from
  the conversation turn(s) being completed, optional temperature / max tokens.
- **Not sent by this path:** local brain contents, camera frames, desktop
  screenshots, Cloudflare Access tokens, or unrelated settings.

### Moonshot / Kimi (`api.moonshot.cn`)

- **Trigger:** same as above with a Moonshot model and `KIMI_API_KEY`.
- **Payload:** same OpenAI-compatible chat completion fields as Zhipu.

### Google Gemini (`generativelanguage.googleapis.com`)

- **Trigger:** same as above with a Gemini model and `GEMINI_API_KEY`.
- **Payload:** conversation contents mapped into Gemini `contents` /
  `generationConfig` (prompt text, optional temperature / max output tokens).

### Microsoft online speech (`edge-tts`)

- **Trigger:** a spoken-reply / `/v1/audio/speech` request after Microsoft
  speech is enabled.
- **Payload:** the text string being synthesized, plus voice / format options.
- **Not sent by this path:** microphone audio, chat history beyond the spoken
  string, or cloud LLM prompts.

## What stays local when switches are off

- No registration of Zhipu / Moonshot / Gemini on the embedded router.
- Cloud LLM completion requests receive `cloud_llm_consent_required`.
- Microsoft speech requests receive `microsoft_speech_consent_required` and
  `edge-tts` is not invoked.
- Local Piper TTS and local STT continue to work without these switches.

See also `docs/governance/legal/PRIVACY.md` §§2.4–2.5 and `web/privacy.html`.
