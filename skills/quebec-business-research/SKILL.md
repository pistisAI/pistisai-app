---
name: quebec-business-research
description: "Use for Quebec business or market research with sources."
version: 0.1.0
author: Zoid Maltek
license: MIT
metadata:
  hermes:
    tags: [Quebec, Business-Research, Prospects, Market-Research, Marketing, Sources]
    category: research
    related_skills: [grounded-citations, competitor-news-monitor, document-to-action-items]
---

# Quebec Business Research

Research Quebec businesses and markets from public sources only. Output is cited facts, labelled gaps, and labelled estimates. Never a guessed number.

## When to Use

- "Research this business / prospect in Sherbrooke / Estrie / Quebec."
- Headcount, size, sector, location, ownership, marketing presence for a prospect.
- Market sizing for a niche (body shops, garages, property management, legal, depanneurs).
- Competitor scans for a local niche.

Don't use for: one-off single-fact lookups (just cite one web_search answer), or private data about individuals beyond business role.

## Procedure

### 1. Freeze the question
Write one line: entity (or niche and region), the fields needed (headcount, sector, address, status, marketing presence), and the date. Done when each field has a defined source type.

### 2. Use Quebec-specific sources, in this order

1. Registre des entreprises du Quebec (REQ) via registreentreprises.gouv.qc.ca: legal name, status, address, registration date, directors. Authoritative for existence and status.
2. Official company site, team page, contact page: staff clues, named people, services.
3. Job Bank (jobbank.gc.ca) employer profiles and Guichet-Emplois postings: posting volume is a weak signal of size; postings show the trade or profession.
4. The Org (theorg.com), LinkedIn company and people pages: headcount ranges. Mark unverified (self-declared or scraped).
5. Google Business Profile and PagesJaunes: address, hours, category, reviews. Good for existence and activity.
6. Statistique Canada / ISDE / Institut de la statistique du Quebec: sector-level and regional averages (market sizing, not per-business counts).
7. AMDEQ, ACQ, OEAQ and sector associations: sector averages and member counts.
8. Local press (La Tribune, Sherbrooke.info, Radio-Canada Estrie): dated events, openings, closures, expansions.

Do not use: scraped contact-data sites, paid people-search, or any source that requires login bypass.

### 3. Register every source at retrieval time
Use grounded-citations: `sources.py add <url> --title ...` before writing claims. Record the retrieval date.

### 4. Record each field with its status
- Sourced: value + source URL + date retrieved.
- Self-declared / unverified: value + source + "unverified" label (e.g. The Org range).
- User-confirmed: value + "confirmed by the user" + date. Never upgrade it to sourced without a public source.
- Estimate: value + method + assumptions. Keep separate from sourced data.
- Unknown: write "unknown" with what was searched. Never fill from memory.

### 5. Marketing and presence signals (Quebec)
Check: website language (FR/EN), Google reviews count and rating, Facebook/Instagram last post date, Google Business hours, PagesJaunes presence, job postings, press mentions. Report as signals, not proof of size or revenue.

### 6. Cross-check
At least two independent sources for any headcount or size claim. If they disagree, show both with their sources; do not pick one silently.

### 7. Report
One block per entity: sourced facts, unverified facts, user-confirmed facts, estimates, unknowns, next source to try. Keep French business terms as the user uses them.

## Pitfalls
- Treating a LinkedIn or The Org range as an audited headcount.
- Using a provincial average as if it were the local business's count (say so when used as a proxy).
- Confusing a person with a same-name business owner (verify the company link on the source page).
- Counting job postings as headcount.
- Writing a figure into a plan or CRM without its source and status.

## Verification
- [ ] Every number has a source URL and retrieval date, or is labelled estimate/unknown/user-confirmed.
- [ ] Ledger ids in the report match the sources registered.
- [ ] No claim was taken from memory.
- [ ] Unknowns are listed, not filled.