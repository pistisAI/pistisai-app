# PistisAI et IAClé

PistisAI est la pile d'outils : un bureau (hub) construit autour de l'agent Hermes, plus des compétences (skills). IAClé est l'entreprise québécoise de Christopher Maltais et la marque qui livre cette même pile aux clients du Québec. Une seule pile, une seule entreprise. IAClé n'est pas une application distincte.

Les nouvelles fonctions s'ajoutent comme des compétences dans cette pile.

English page: [Product](PRODUCT.md).

## Où ça tourne

L'agent tourne sur l'ordinateur du client. Aucun matériel spécial n'est requis.

L'application de bureau est le hub. Le web, le mobile et les autres ordinateurs passent par ce hub. Hermes garde ses propres adaptateurs de messagerie (Telegram, Slack, et les autres). Ils ne passent pas par l'application.

La pile peut utiliser les services infonuagiques que le client a déjà, et des modèles en ligne pour le travail lourd, seulement lorsque c'est sécurisé, que le client y consent, et que c'est conforme à la Loi 25. Les flux sortants se limitent à ce que le client a autorisé.

Les actions sur le bureau restent sur l'ordinateur qui les a permises. Dans un mandat IAClé, une personne reste l'approbateur des messages sortants et des décisions critiques.

## Connexion

La connexion sert au tunnel et à la synchronisation. L'usage local du bureau ne demande pas de compte.

| Offre | Réseau |
| --- | --- |
| Gratuit | Tunnel pistisai.app sur `api.pistisai.app`, protégé par Cloudflare Access |
| Affaires | Tailscale ou VPN du client (`PISTISAI_TUNNEL_AUTH=customer`) |
| Entreprise | Tailscale ou VPN du client (`PISTISAI_TUNNEL_AUTH=customer`) |

## Adresses publiques

- Application web : [https://app.pistisai.app](https://app.pistisai.app)
- API et tunnel : [https://api.pistisai.app](https://api.pistisai.app)

## À qui ça s'adresse

IAClé sert les PME du Québec, en français, y compris les cabinets et les pratiques réglementées qui doivent savoir où vont les renseignements personnels. L'expansion suivante reste au Québec et va plus loin auprès de ces PME réglementées.
