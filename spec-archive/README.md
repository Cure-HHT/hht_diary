# Formal Requirements System

## Intent

This repository uses a formal requirements system to define, implement, and verify the system specification, design, implementation and verification.

Requirements are written so they can be directly verified, traced one-way from implementation to obligation, audited without manual cross-referencing, and maintained without redundancy.

Use **`requirements-spec.md`** for the authoritative rules and grammar

---

## Directory Purpose

The `spec/` directory contains **formal requirements only**.

- **spec/**: Normative obligations defining what must be true of the system
- **spec/roadmap/**: Not part of the formal process. Future features.
- **docs/**: Explanatory documentation, ADRs, guides, and examples

If it defines *what must be true*, it belongs in `spec/`.
If it explains *how to do something*, it belongs in `docs/`.



