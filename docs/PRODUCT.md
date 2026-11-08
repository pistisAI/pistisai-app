# PistisAI and IAClé

PistisAI is the tool stack: a desktop hub built around the Hermes agent, plus skills. IAClé is Christopher Maltais's Quebec company and the brand that delivers that same stack to Quebec clients. One stack, one company. IAClé is not a separate application.

New capabilities are added as skills in this stack.

French client page: [Produit (français)](PRODUCT.fr.md).

## What runs where

The agent runs on the client's own computer. No special hardware is required.

The desktop app is the hub. Web, mobile, and other desktops connect through that hub. Hermes keeps its own messaging adapters (Telegram, Slack, and the rest). Those adapters do not route through the Flutter app. Direct client-to-Hermes paths that still exist are transitional ([#492](https://github.com/pistisAI/pistisai-app/issues/492)).

The stack can use cloud services the client already uses, and online language models for heavy work, only when that path is secure, the client has agreed, and it complies with Quebec Law 25. Outbound flows stay limited to what the client authorized.

Desktop actions stay on the computer that granted them, and they require permission. In an IAClé engagement, a person remains the approver for outgoing messages and critical decisions.

## Sign-in

Sign-in exists for the tunnel and sync system. Local use of the desktop app does not require an account.

| Tier | How devices reach the hub |
| --- | --- |
| Free | The pistisai.app tunnel at `api.pistisai.app`, protected by Cloudflare Access |
| Business | The customer's own Tailscale network or VPN (`PISTISAI_TUNNEL_AUTH=customer`) |
| Enterprise | The customer's own Tailscale network or VPN (`PISTISAI_TUNNEL_AUTH=customer`) |

An older Premium name still exists in the app. On the Cloudflare Access change it follows the same customer-network path as Business and Enterprise. It is not a separate product.

Supabase sign-in is removed by open pull request [#550](https://github.com/pistisAI/pistisai-app/pull/550). Describe Cloudflare Access, not Supabase. Details: [Tunnel and sync sign-in](development/TUNNEL_SIGN_IN.md).

## Public hosts

- Web app: [https://app.pistisai.app](https://app.pistisai.app)
- API and tunnel: [https://api.pistisai.app](https://api.pistisai.app)

`adminmatrix.pistisai.app` was removed on 7 November 2026. `pistisai.app` and `docs.pistisai.app` are not current hosts. Documentation lives in this repository.

## Who it is for

IAClé serves Quebec small and medium businesses, in French, including regulated practices that need a clear record of where personal information goes. Later expansion stays in Quebec and goes deeper into those regulated businesses. The open-source repository is the same stack.

## What this repository is

A Flutter desktop and web app, with optional Node.js services for the tunnel and API. Hermes is the primary agent runtime under test. OpenClaw and compatible gateways also work. Ollama and LM Studio are support model providers for app-owned features such as embeddings. They are not the agent.

Technical map: [System architecture](architecture/SYSTEM_ARCHITECTURE.md). Launch steps: [Launch guide](LAUNCH.md).
