# Privacy Policy

_Last updated: 4 September 2026 · Effective: 4 September 2026_

> The canonical, user-facing version of this policy is published at
> [https://pistisai.app/privacy](https://pistisai.app/privacy) (served from
> `web/privacy.html`). Keep the two in sync when editing.

Pistisai ("Pistisai," "we," "us," or "our") is a local-first AI companion for
desktop and web. This Privacy Policy explains what information we collect, how we
use it, and the choices you have. Pistisai is designed to keep your data on your
own device by default; cloud features are optional and only take effect when you
explicitly enable them.

**Local-first summary.** Your conversations, memory ("local brain"), and settings
are stored in an encrypted database on your own machine. We do not sell your data,
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

### 2.1 Account information (Google Sign-In)

When you sign in with Google, our authentication provider (Supabase Auth) receives
basic profile information from your Google Account so we can create and secure your
account. This includes:

- your email address;
- your name and profile picture, where available;
- a unique Google account identifier;
- the OAuth scopes `email` and `profile` only.

We request the minimum scopes necessary to identify you. We do not request access
to your Gmail, Google Drive, contacts, or other Google services.

### 2.2 Content you create

Conversations, avatar memory, notes, and configuration you create in Pistisai are
stored locally in an encrypted database on your device. This content stays on your
device unless you explicitly enable cloud sync or connect a remote runtime, in
which case it is transmitted only to the destination you have chosen.

### 2.3 Device and diagnostic information

To keep the app reliable we may process limited technical information such as
application version, operating system, and error/crash diagnostics. Crash reporting
(via Sentry) is used only for stability and is subject to the configuration of your
build.

### 2.4 Camera, microphone, screen, and desktop control

Optional vision (camera/OCR), voice, and desktop-control features operate under
your explicit, device-scoped permission. Media and screen data captured by these
features are processed locally or by the runtime you select; Pistisai does not
collect or retain this content on our servers.

## 3. How we use information

- to authenticate you and secure your account;
- to provide, maintain, and improve the app's functionality;
- to synchronize your data across your devices when you enable cloud sync;
- to diagnose problems and improve reliability and security.

We do not sell your personal information and we do not use it for advertising.

## 4. Google user data

Pistisai's use and transfer to any other app of information received from Google
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

- **On-device:** app content is stored in an encrypted local database on your machine.
- **Authentication:** account and session data are handled by Supabase Auth on our behalf.
- **In transit:** connections to first-party services use encrypted transport
  (HTTPS/TLS). Private device-to-device connectivity is available via Tailscale.

No method of storage or transmission is completely secure, but we apply reasonable
technical and organizational safeguards appropriate to the data involved.

## 6. Sharing and third parties

We share information only in these limited circumstances:

- **Google** — to authenticate you when you choose Google Sign-In;
- **Supabase** — our authentication and account infrastructure provider;
- **Error diagnostics (Sentry)** — for crash and stability reporting, when enabled;
- **Runtimes and providers you choose** — only the data you direct Pistisai to send to them.

We do not sell, rent, or trade your personal information.

## 7. Data retention and deletion

Content stored locally remains on your device until you delete it or uninstall the
app. You can remove local data from within the app. For account data held by our
authentication provider, you may request deletion of your account and associated
authentication records by contacting us at the address below; we will delete such
data unless we are required to retain it by law.

## 8. Your rights and choices

- access, correct, or delete your account information;
- export or delete your local data from within the app;
- revoke Google access at any time via your
  [Google Account permissions](https://myaccount.google.com/permissions);
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
contact us at privacy@pistisai.app. You can also reach the project at
[github.com/pistisAI/pistisai-app](https://github.com/pistisAI/pistisai-app).
