# ADR-0001: Retrieval-first; no fine-tuning in Phases 0–2

| | |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-11-25 |
| **Deciders** | James (+ TBC) |
| **Related** | [ADR-0002](ADR-0002-third-party-knowledge-intake.md), [knowledge sources](../knowledge-sources.md) |

## Context

The agents need security domain knowledge: frameworks, vulnerability data, internal standards and past reviews. There are two broad ways to provide it:

1. **Fine-tune** a model on security corpora, e.g. instruction datasets such as `Vyber07/cyber-security`.
2. **Retrieve** from a curated, versioned knowledge base at run time and have the agent cite what it used.

Our outputs feed security decisions, so traceability and the ability to correct knowledge matter more than fluency.

## Decision

Use **retrieval over a curated knowledge base** (framework graph + vector index) with general-purpose frontier models. **Do not fine-tune** in Phases 0–2. Revisit after Phase 2 against evidence.

## Rationale

| Criterion | Retrieval | Fine-tuning |
|-----------|-----------|-------------|
| Traceability (cite source and version) | ✅ Native | ❌ Knowledge is opaque in weights |
| Correcting or removing bad knowledge | ✅ Re-index, new snapshot | ❌ Retrain; hard to prove removal |
| Freshness (KEV, NVD, ATT&CK releases) | ✅ Continuous | ❌ Stale between training runs |
| Internal confidential data | ✅ Stays in our store, with entitlement filters | ⚠️ Baked into weights; entitlement impossible |
| Poisoning blast radius | ⚠️ Contained to chunks; detectable | ❌ Diffuse; hard to detect |
| Cost and skills | ✅ Lower | ❌ Higher (GPU, MLOps, evals) |
| Output style / format consistency | ⚠️ Prompting + templates | ✅ Stronger |

## Consequences

- We invest in the intake pipeline, chunking, labelling and retrieval quality.
- Format consistency comes from templates, output validators and few-shot examples, not training.
- Fine-tuning stays an option later for **narrow style tasks** (e.g. house-style rewriting), trained only on T0 data that has passed intake, never on T3.
