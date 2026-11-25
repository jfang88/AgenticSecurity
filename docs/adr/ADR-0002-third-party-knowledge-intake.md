# ADR-0002: Third-party knowledge is an untrusted supply-chain artefact

| | |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-11-25 |
| **Deciders** | James (+ TBC) |
| **Related** | [ADR-0001](ADR-0001-retrieval-first.md), [knowledge sources §3](../knowledge-sources.md#3-intake-pipeline), [platform threat model PT-01](../platform-threat-model.md) |

## Context

Public security datasets are tempting shortcuts. One example is `Vyber07/cyber-security` on Hugging Face: popular, gated, labelled Apache 2.0, with unclear upstream provenance and inconsistent metadata. Loading such content into an agent's knowledge base creates:

- **Integrity risk:** wrong or generated content leads to false assurance (PT-05).
- **Security risk:** embedded instructions lead to indirect prompt injection and tool misuse (PT-01, PT-02).
- **Legal risk:** redistributed third-party content under a licence the publisher may not be entitled to grant.

Our software supply chain design already solves the same problem for packages and binaries.

## Decision

All external knowledge sources go through the **knowledge intake pipeline** before any agent can use them:

1. Registered in `knowledge/register.yaml` with an owner and purpose.
2. Provenance and licence reviewed; commercial use confirmed.
3. **Pinned** to a version / commit SHA with file hashes. Never track `latest`.
4. Pulled via the internal proxy, not directly from the internet.
5. Scanned (malware, secrets, injection heuristics).
6. Validated mechanically (schema, IDs, rule compilation, dedupe) plus a sampled human review.
7. Labelled with tier, classification, licence and source on every chunk.
8. Included only in a **signed KB snapshot**; agent outputs record the snapshot ID.
9. Rechecked on a schedule; withdrawn content is revoked and evals re-run.

Unverified (T3) sources are **never cited as authority**, even after they pass intake.

## Consequences

- Slower onboarding of new sources, in exchange for traceable and revocable knowledge.
- `Vyber07/cyber-security` is **on hold**: sample 2–3 domains in Phase 0 and decide per domain.
- The same pipeline later serves A5 when AI models and datasets are requested for other teams.
