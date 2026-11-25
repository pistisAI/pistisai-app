# Privacy Policy

_Last updated: 15 November 2026 · Effective: 15 November 2026_

> The public copy of this policy is at
> [https://example.com/privacy](https://example.com/privacy) (`web/privacy.html`).

Pistisai ("Pistisai," "we," "us," or "our") is the local-first hub delivered by
Pistisai for desktop and web. This Privacy Policy explains what information we
collect, how we use it, and the choices you have. Data stays on your own device
by default. Cloud features take effect when you sign in or turn them on.

**Local-first summary.** Your conversations, memory ("local brain"), and settings
are stored in a database on your own machine. We do not sell your data,
we do not use it for advertising, and we do not mine it to train models. When you
choose to sign in or turn on cloud sync, a limited set of information is processed
as described below.

## 1. Who we are

Pistisai is software you run on your own devices, optionally connected to agent
runtimes and services that you choose. This policy covers the Pistisai desktop and
web applications and the first-party services that support sign-in and optional
cloud sync. If you connect Pistisai to third-party runtimes or model providers,
their handling of your data is governed by their own policies.

## 2. Information we collect

### 2.1 Account information (sign-in)

Sign-in is optional and is handled by Cloudflare Access (Cloudflare, Inc.). On
the sign-in page you prove your identity with a one-time code sent to your email
address, or with a Google or GitHub account where those options are offered.
Cloudflare then tells our service who signed in. We receive and store:

- your email address;
- an account identifier issued by Cloudflare Access.

We do not receive your password, and we do not request access to your Gmail,
Google Drive, contacts, repositories, or other Google or GitHub services.

### 2.2 Content you create

Conversations, avatar memory, notes, and configuration you create in Pistisai are
stored locally on your device. On desktop and mobile:

- the local database (`local_brain.sqlite`) is encrypted at rest with
  SQLCipher-compatible AES-256; its key comes from your environment
  (`PISTISAI_LOCAL_BRAIN_KEY`) or the operating system keystore, not from the app
  config;
- chat history is kept in a separate file (`conversations.json.enc`) encrypted
  with AES-256 under its own key, stored in the operating system keystore.

The app never writes these keys to a plain file. If the keystore is unavailable,
chat history is not saved until it is available again. A history file the app can
no longer decrypt (for example after the keystore was reset) is kept aside under a
new name instead of being overwritten, and is removed when you delete your local
data. On web, data is kept in the browser's origin-scoped storage. Turn on your
operating system's disk encryption (BitLocker, FileVault or LUKS) as well. This
content stays on your device unless you explicitly enable cloud sync or connect a
remote runtime, in which case it is transmitted only to the destination you have
chosen. The avatar personality you set (agent name, tone settings and stage) is
sent to the agent runtime you connected, on your machine by default, which
includes it in the instructions for each reply; it therefore reaches the same
model provider your runtime uses for the conversation itself.

On desktop, the avatar personality, avatar memory entries and a short context
summary are also written as plain, unencrypted Markdown files (`personality.md`,
`memory.md`, `context.md`) into the `pistisai` folder of your agent runtime's
skill directory (for example `~/.openclaw/skills/pistisai`), so the runtime can
read them. They are protected only by your operating system's file permissions
and disk encryption. Deleting your local data removes these three files; other
files in that folder are not touched.

### 2.3 Device and diagnostic information

To keep the app reliable we may process limited technical information such as
application version, operating system, and error/crash diagnostics. Crash reporting
is **off unless you turn it on** under Settings → General → "Send crash reports".
When it is on, crash reports (error message, stack trace, app version and operating
system) are sent to Sentry (Functional Software, Inc.), whose servers may be outside
your country. Reports are configured not to include your account details or a
history of your activity; an error message can still contain fragments of the data
being handled when the error happened. As with any internet connection, Sentry's
servers see the IP address the report comes from.

### 2.4 Spoken replies

Microsoft online speech (through the `edge-tts` tool) is **off by default**.
When you enable **Allow Microsoft online speech** in Settings, the text being
spoken for an online-voice reply is sent to Microsoft's speech service to
produce the audio. Local TTS remains available without this setting. See
`docs/governance/legal/CLOUD_PROVIDER_DATA_FLOW.md`.

### 2.5 Optional cloud model providers

By default Pistisai does not call third-party cloud LLMs. Optional cloud model
adapters (Zhipu/GLM, Moonshot/Kimi, and Google Gemini) require **both** an
explicit Settings opt-in (**Allow cloud LLM providers**) and a build that
supplies the matching API key (`GLM_API_KEY`, `KIMI_API_KEY`, or
`GEMINI_API_KEY`). Without consent the adapters are not registered; without a
key they cannot call the provider. When both are present and you select that
provider, the prompt and conversation content you send are transmitted to that
provider under their own terms. Local agent runtimes (for example Hermes) and
local support model providers (Ollama, LM Studio) stay on your machine unless
you point them elsewhere. Client-facing data flow:
`docs/governance/legal/CLOUD_PROVIDER_DATA_FLOW.md`.

### 2.6 Camera, microphone, screen, and desktop control

Optional vision (camera/OCR), voice, and desktop-control features operate under
your explicit, device-scoped permission. Media and screen data captured by these
features are processed locally or by the runtime you select; Pistisai does not
collect or retain this content on our servers. Screenshots, camera frames and
spoken-reply audio are written as plain temporary files into an app-owned folder
inside your operating system's temp directory; on macOS and Linux that folder is
readable only by your user account (mode 0700), and the app falls back to its own
support folder if the temp one cannot be used safely. Some are deleted right after use
(for example presence checks and screenshot analysis); the rest stay until the
operating system clears its temp directory or you delete your local data, which
removes the whole folder.

## 3. How we use information

- to authenticate you and secure your account;
- to provide, maintain, and improve the app's functionality;
- to synchronize your data across your devices when you enable cloud sync;
- to diagnose problems and improve reliability and security.

We do not sell your personal information and we do not use it for advertising.

## 4. Google user data

This section applies if you choose to sign in with a Google account. Pistisai's
use and transfer to any other app of information received from Google
APIs will adhere to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements. Specifically:

- we use Google account data solely to provide and improve sign-in and the
  user-facing features you request;
- we do not transfer Google user data to third parties except as necessary to
  provide or improve the app, to comply with applicable law, or as part of a merger
  or acquisition;
- we do not use Google user data for advertising;
- we do not allow humans to read Google user data unless we have your consent, it
  is necessary for security, or it is required by law.

## 5. How we store and protect your information

- **On-device:** app content is stored locally on your machine. Desktop and mobile encrypt `local_brain.sqlite` with AES-256 (SQLCipher-compatible) and chat history (`conversations.json.enc`) with AES-256, with keys in the operating system keystore; also protect the volume with your operating system's disk encryption.
- **Authentication:** sign-in is handled by Cloudflare Access; our service stores your email address and account identifier.
- **In transit:** connections to first-party services use encrypted transport
  (HTTPS/TLS). Private device-to-device connectivity is available via Tailscale.

No method of storage or transmission is completely secure, but we apply reasonable
technical and organizational safeguards appropriate to the data involved.

## 6. Sharing and third parties

We share information only in these limited circumstances:

- **Cloudflare** — to authenticate you when you sign in (Cloudflare Access);
- **Google or GitHub** — only if you choose to sign in with that account;
- **Error diagnostics (Sentry)** — crash reports, only if you turn crash reporting on;
- **Microsoft speech service** — only when you enable Microsoft online speech, the text of replies read aloud with that online voice;
- **Optional cloud model providers (Zhipu, Moonshot, Google Gemini)** — only when you enable cloud LLM providers, a build includes their API key, and you use that provider;
- **Runtimes and providers you choose** — only the data you direct Pistisai to send to them.

We do not sell, rent, or trade your personal information.

## 7. Data retention and deletion

Content stored locally remains on your device until you delete it or uninstall the
app. You can export or permanently delete on-device agent data from
**Settings → Storage → Local agent data** (local wipe completes in seconds; see
`docs/user-guide/LOCAL_DATA_EXPORT_DELETION.md` for what is removed and how to
verify). The local wipe removes the local database, the encrypted chat history,
the avatar Markdown files described in §2.2 and the app's temporary captures. It
does not delete the chat transcript your agent runtime (for example Hermes)
keeps on the machine where it runs; after a wipe the app no longer imports
messages from before the wipe, but you must clear that transcript in the runtime
itself. For account data held by our authentication provider, you may request
deletion of your account and associated authentication records by contacting us
at the address below; we will delete such data unless we are required to retain
it by law (provider processing target: within a few hours of a verified request).

## 8. Your rights and choices

- access, correct, or delete your account information;
- export or delete your local data from within the app;
- if you signed in with Google, revoke that access at any time via your
  [Google Account permissions](https://myaccount.google.com/permissions);
- turn crash reporting on or off under Settings → General;
- turn spoken replies off if you do not want text sent to Microsoft's speech service;
- cloud model providers (Zhipu, Moonshot, Gemini) are absent unless a build includes
  their API keys; when present, only prompts you route to that provider are sent;
- choose whether to enable cloud sync or keep Pistisai fully local.

## 9. Children's privacy

Pistisai is not directed to children under 13 (or the minimum age of digital
consent in your jurisdiction), and we do not knowingly collect personal information
from them. If you believe a child has provided us with personal information, please
contact us so we can remove it.

## 10. International users

If you access Pistisai from outside the region where our service providers operate,
your information may be processed in other countries. We take steps to ensure
appropriate protections are in place for such processing.

## 11. Changes to this policy

We may update this Privacy Policy from time to time. When we do, we will revise the
"Last updated" date above and, where appropriate, provide additional notice.
Continued use of Pistisai after an update constitutes acceptance of the revised
policy.

## 12. Contact us

If you have questions or requests regarding this Privacy Policy or your data,
contact us at ops@example.com. You can also reach the project at
[github.com/pistisAI/pistisai-app](https://github.com/pistisAI/pistisai-app).
