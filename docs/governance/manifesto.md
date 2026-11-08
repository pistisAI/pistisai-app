# The Pistisai Manifesto — Technology That Keeps Its Word

Πίστις (Pistis) is the Greek word the New Testament uses for *faith* — not belief
as opinion, but trust as weight-bearing conviction: "the assurance of things hoped
for" (Hebrews 11:1). The word also carries the older Greek face — the spirit of
trust and good faith who fled Pandora's box and returned to Olympus.

Pistisai sits on that seam deliberately. The Bible gives the word its meaning;
the mythology gives it a face. Athens and Jerusalem answering the same question:
**what does it take to be trustworthy?**

## Why we exist

Most AI hides where data goes. PistisAI keeps its word: the agent runs on a local machine at the client's site, actions are permissioned, and cloud services or online models are used when the client agrees. For Quebec clients, that path has to fit Law 25. IAClé is the company that delivers this same stack. The product page is [docs/PRODUCT.md](../PRODUCT.md).

## The Four Pillars

The framework is built on four pillars. Each pairs a biblical virtue with a
Greek-architecture archetype, and each maps to concrete product behavior — not
decoration, structure. They hold the roof up.

- **Aiman (face)** — identity and honesty. The agent knows who it is and does not
  pretend otherwise; it tells the truth plainly and treats every user with dignity.
  *"Therefore each of you must put off falsehood and speak truthfully."* (Eph 4:25)
- **Aigent (engine)** — capability bounded by wisdom. Tools act only within
  consent; irreversible acts require a human yes. Capability without wisdom is
  just speed toward trouble. *"The wise man built his house upon the rock."* (Mt 7:24)
- **Aimotions (heart)** — fruit over performance. Follow-through beats theatrics;
  no engagement hooks, no dark patterns, no manufactured urgency. *"The fruit of
  the Spirit is… faithfulness."* (Gal 5:22)
- **Aidration (flow)** — order and right timing. "Let all things be done decently
  and in order" (1 Cor 14:40). Scheduled maintenance, self-healing, restoration
  rather than punishment when a component fails — order out of chaos, as in the
  creation account.

The pillars themselves are the shared image: the church as "pillars of the truth"
(1 Timothy 3:15), the stoa where Greeks did public philosophy. Virtue isn't
decoration — it is structure.

## What this means in the code

These are engineering constraints, not values posters:

- The agent runs on the client's computer. Cloud services and online models are used with explicit consent, and for Quebec clients under Law 25.
- Every privileged action permissioned, auditable, and reversible where possible.
- No dark patterns, no attention capture, no data resale — the product is built
  on faithfulness, not engagement.
- Honest error handling: failures surface truthfully and are restored, not hidden.
