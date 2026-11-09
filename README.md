# IAClé

IAClé est un assistant IA local d'abord pour les entreprises du Québec. [English](README.en.md)

IAClé est basé sur PistisAI.

## Local d'abord

L'agent tourne sur un ordinateur chez le client. L'audit vérifie si son PC actuel peut l'héberger. Sinon, IAClé fournit un mini-PC dédié (standard : Beelink GTi15). Du matériel sur mesure, seulement quand l'audit le montre.

Il peut joindre un service infonuagique que le client utilise déjà, seulement si c'est sécuritaire, si le client consent, et si le fournisseur a été évalué selon la Loi 25 (évaluation des facteurs relatifs à la vie privée). On documente les flux qui sortent. On peut les retirer.

Dans le service, l'employé approuve les envois et les décisions importantes.

## Pour qui

Les PME du Québec. D'abord en Estrie, puis plus loin au Québec, surtout les PME réglementées : juridique, santé, finance.

## Ce que l'assistant fait

- Clavardage, voix et avatar.
- Lecture d'écran et OCR, avec la permission de la personne.
- Actions sur le poste, avec une permission à la fois.
- Compétences, sessions, tâches planifiées.
- Maillage privé entre les appareils du client.

Hermes est le moteur principal. OpenClaw et les passerelles compatibles fonctionnent aussi. Ollama et LM Studio servent à la mémoire et aux embeddings.

## Services

- **Audit de préparation.** Trois colonnes : ce que les outils font déjà, ce qui se fait encore à la main, ce qui reste à automatiser. On vérifie aussi si le PC actuel peut héberger l'agent.
- **Implantation.** Un parcours opérationnel, puis l'installation et le soutien. Exemples : tri des courriels, factures, réceptionniste bilingue, rapports, comptabilité.
- **Services gérés.** Suivi du système, aide pour la Loi 25, reprise des données.

## Connexion

La connexion sert au tunnel et à la synchro. Le réseau est un tunnel derrière Cloudflare Access, ou Tailscale, ou le VPN du client.

## Documentation

| Document | Contenu |
| --- | --- |
| [English](README.en.md) | La même page en anglais |
| [Vue d'ensemble](docs/index.md) | Définition du logiciel |
| [Installation](docs/user-guide/SETUP_GUIDE.md) | Installer le poste |
| [Utilisation](docs/user-guide/USER_GUIDE.md) | S'en servir |
| [Sécurité](SECURITY.md) | Signaler une faille |

Une faille se signale en privé : [avis de sécurité GitHub](https://github.com/iacle-solutions/iacle-app/security/advisories).

## Licence

Voir [LICENSE](LICENSE).

Pour les développeurs : [CONTRIBUTING.md](CONTRIBUTING.md).
