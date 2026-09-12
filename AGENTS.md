# ores-otel — clients

Canonical `clients` repository for [`ores-otel`](https://github.com/ores-otel).

- Internal runtimes: Rust, TypeScript, Dart.
- Contracts: independently authored TypeSpec and JSON Schema Draft 2020-12 are peer authorities in `ores-otel/ores-interfaces`; neither has precedence or fallback authority. Admit convergence with `ORESoftware/typespec-json-schema-validator` (TJSV). Generated schemas, types, Contract IR, fixtures, reports, and receipts are evidence/projections only and must never overwrite either authored authority.
- A client contract lock must pin the exact authority repository/revision and both authored source paths (`typespec` and `jsonSchema`) before a language client can claim conformance.
- Auth: github.com/shared-auth.
- Sync: github.com/opto-sync.
- Telemetry: github.com/ores-otel.
- Flags: github.com/flags-2-env.
- Packages: github.com/zed-pkg.
- Never use React/JSX or webviews.
- Resolve git conflicts semantically; never rebase, stash, or reset.

Keep language clients as libraries, not CLIs.

## Functional programming conformance

This repository carries an FP conformance ratchet. Before you land a change:

```sh
python3 tools/fp-conformance/fp_conformance.py .
```

CI compares your findings against `tools/fp-conformance/budget.json` and fails
only when a rule's count *increases*. Do not raise the budget to get green — fix
the new violations. When you clear a class of violation, lower the budget in the
same commit with `--write-budget`.

Prefer value-returning APIs and deeply detached published values over caller-owned
mutable output parameters. Mutation inside an exclusively owned implementation
detail is acceptable on a measured or obviously allocation-sensitive hot path,
but the reason must be documented next to that mutation and the public boundary
should remain value-oriented where practical.

The principles, the rule codes and the remedy for each are in `FP-GUIDELINES.md`.
