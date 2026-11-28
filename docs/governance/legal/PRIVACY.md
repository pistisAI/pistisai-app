# Privacy Policy

_Last updated: 28 November 2026 · Effective: 28 November 2026_

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
as described below. The web app is the exception for chat history: while you are
signed in to it, your conversations are stored on our server (section 2.2).

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
- an account identifier issued by Cloudflare Access;
- when Cloudflare Access provides them for your sign-in method: your name,
  nickname, profile picture link, language setting (locale) and whether your email
  address is verified.

Signing in also creates session, security and activity records on our server
(section 2.7).

When you use the web app while signed in, or turn on cloud services on desktop or
mobile, we also store your conversations (section 2.2).

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
data. On web, settings are kept in the browser's origin-scoped storage; chat
history is not (see below). Turn on your operating system's disk encryption
(BitLocker, FileVault or LUKS) as well. Apart from web chat history, this
content stays on your device unless you explicitly enable cloud services or
connect a remote runtime, in which case it is transmitted only to the destination
you have chosen. The avatar personality you set (agent name, tone settings and stage) is
sent to the agent runtime you connected, on your machine by default, which
includes it in the instructions for each reply; it therefore reaches the same
model provider your runtime uses for the conversation itself.

**Chat history on our server.** On desktop and mobile, the app sends your
conversations to our server only when you are signed in **and** cloud services are
turned on. Cloud services are off by default, and the app does not yet have a
setting to turn them on, so today desktop and mobile chat history is not sent to
our server. The web app has no chat store in the browser: while you are signed in
to the web app, your conversations, including the text of every message, are
stored on our server so that you can see them again. Conversations stored on our
server are kept until they are deleted. The app does not yet offer a control to
delete them; to have them removed, contact us at the address in section 12.

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

In the web app, while crash reporting is on, the app's own diagnostic log lines are
also sent to our API server, each with its time, level, the page address without
its query string or fragment, and your browser's user agent. When crash reporting is
off, these lines stay in your browser and nothing is sent.

When you click **Check Now** in the update section of Settings, the app asks GitHub
(`api.github.com`) for the latest release, and downloading a release from the
download page opens a GitHub link; GitHub sees your IP address for those requests.
Images in release notes load only when you click them.

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

### 2.7 Records our server keeps when you sign in

This section applies only to the optional sign-in and cloud service. Nothing here
is collected while you use the app without signing in.

- **Sessions.** Each signed-in session is recorded in our database with a random
  session identifier, a hash of your sign-in token, its expiry time, the time of
  your last activity, your IP address and the user agent of your browser or app.
  The app can also copy its sign-in tokens (access, ID and refresh token) into
  that session record so that it can read them back from the server. These tokens
  are stored as the app sends them; the database does not encrypt them
  separately. They are used only to restore your signed-in session. The server
  deletes sessions after they expire (it checks every 15 minutes) and keeps a
  limited number of active sessions per account; a session you sign out of is
  marked inactive and deleted when it expires.
- **Security and activity records.** The sign-in audit log, security events (for
  example a refused sign-in), account activity records and access to shared
  tunnels record your IP address and user agent with each event. Security event
  details store email addresses masked and without tokens.
- **Server logs.** The server's request log records the address of each request
  (with session tokens and credential-like query values removed), your account
  identifier, your IP address and your user agent. Log lines about sign-in,
  administration and email sending mask email addresses. In production these log
  files are rotated by size (at most five files of 10 MB each). Web-app log lines
  (section 2.3) go to a separate file capped at 10 MB, with one older file kept.
- **No automatic purge period yet.** Apart from expired sessions and the log size
  limits above, no automatic deletion period is set for these records. They are
  kept until they are deleted on request or when your account is deleted
  (section 7).
- **Server error reporting.** Separately from the app's "Send crash reports"
  switch, our servers send their own error reports to Sentry when the operator
  of the server configures a Sentry key (`SENTRY_DSN`). Your crash-report switch
  does not turn this off. These reports contain server errors, some server log
  messages and performance traces for a sample of requests, and can include your
  account identifier and the address of the request. They are configured not to
  attach user details, cookies, request or response bodies, database query data,
  or forwarding and client-IP headers; other request headers can be included. An
  email address placed in a report's user data is removed, and authorization
  errors and 401, 403 and 404 responses are not reported.

## 3. How we use information

- to authenticate you and secure your account;
- to provide, maintain, and improve the app's functionality;
- to synchronize your data across your devices when you enable cloud sync;
- to keep your web chat history while you are signed in to the web app;
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

- **On-device:** app content is stored locally on your machine. Desktop and mobile encrypt `local_brain.sqlite` with AES-256 (SQLCipher-compatible) and chat history (`conversations.json.enc`) with AES-256, with keys in the operating system keystore; also protect the volume with your operating system's disk encryption. The Android app opts out of Android system backup, so its data is not copied to cloud backups or to another device during transfer.
- **Authentication:** sign-in is handled by Cloudflare Access; our service stores your email address, account identifier and the profile fields listed in section 2.1, plus the session records in section 2.7. Sign-in tokens copied to a session record are stored as sent, not encrypted in the database.
- **Chat history on our server:** conversations from the web app while you are signed in, and from desktop and mobile only with cloud services on, are stored in our database, including message text. They are not end-to-end encrypted.
- **In transit:** connections to first-party services use encrypted transport
  (HTTPS/TLS). Private device-to-device connectivity is available via Tailscale.

No method of storage or transmission is completely secure, but we apply reasonable
technical and organizational safeguards appropriate to the data involved.

## 6. Sharing and third parties

We share information only in these limited circumstances:

- **Cloudflare** — to authenticate you when you sign in (Cloudflare Access);
- **Google or GitHub** — only if you choose to sign in with that account;
- **Error diagnostics (Sentry)** — crash reports from the app, only if you turn crash reporting on; error reports from our servers when the server operator configures Sentry (section 2.7);
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

Account data on our server is deleted by us on request; the app does not yet
offer a self-service control. For a deletion request we use the server's full
deletion, which in one step removes your account record, your sessions
(including any stored sign-in tokens), subscriptions, conversations and their
messages, preferences, usage and activity records, and tunnel records and their
access logs. Security audit records (the general audit log and the sign-in audit
log) are kept for abuse investigation, but the link to you is removed: the user
identifier, IP address, user agent and details are cleared. Security events that
name your account identifier or email address keep only the event type and time.
No automatic retention period is defined yet for server records other than
expired sessions and the log size limits in section 2.7.

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
