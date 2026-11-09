# IAClé

IAClé is a local-first AI assistant for Quebec businesses. [Français](README.md)

IAClé is based on PistisAI.

## Local-first

The agent runs on a computer at the client's site. The audit checks whether their current PC can host it. If it can, it runs there. If not, IAClé provides a dedicated mini PC (standard: Beelink GTi15). Custom hardware only when the audit shows the need.

It can reach a cloud service the client already uses only when that is secure, the client consents, and the provider has been assessed under Quebec Law 25 (a privacy impact assessment). Outbound flows are documented. They can be pulled back.

In the service, an employee approves outgoing messages and important decisions.

## Who it is for

Quebec SMBs. First in Estrie, then further into Quebec, especially regulated firms: legal, health, and finance.

## What the assistant does

- Chat, voice, and avatar.
- Screen reading and OCR, with the person's permission.
- Desktop actions, each one permissioned.
- Skills, sessions, and scheduled tasks.
- A private mesh across the client's computers.

Hermes is the main runtime. OpenClaw and compatible gateways work too. Ollama and LM Studio handle memory and embeddings.

## Services

- **Readiness audit.** Three columns: what current tools already do, what is still done by hand, and what is left to automate. It also checks whether the current PC can host the agent.
- **Setup.** One operational path, then installation and support. Examples: email triage, invoices, a bilingual AI receptionist, reports, bookkeeping.
- **Managed services.** System monitoring, Law 25 support, and a way to take the data back.

## Sign-in

Sign-in is for the tunnel and for sync. The network is a tunnel behind Cloudflare Access, or Tailscale, or the client's VPN.

## Documentation

| Document | What it is |
| --- | --- |
| [Français](README.md) | The same page in French |
| [Overview](docs/index.md) | What the software is |
| [Setup](docs/user-guide/SETUP_GUIDE.md) | Install the hub |
| [User guide](docs/user-guide/USER_GUIDE.md) | Use the hub |
| [Security](SECURITY.md) | Report a vulnerability |

Report a vulnerability in private: [GitHub security advisories](https://github.com/iacle-solutions/iacle-app/security/advisories).

## License

See [LICENSE](LICENSE).

For developers: [CONTRIBUTING.md](CONTRIBUTING.md).
