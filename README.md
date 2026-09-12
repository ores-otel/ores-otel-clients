# ores-otel-clients

Polyglot SDKs under `clients/`. Rust, TypeScript, and Dart are first-class and modular. Other languages expose the same `/v1/health` surface.

## Contract authority

Serialized ORES OTEL contracts use two independently authored peer authorities:
TypeSpec and JSON Schema Draft 2020-12. They live in `ores-otel/ores-interfaces`
and are admitted together with
`ORESoftware/typespec-json-schema-validator` (TJSV). Neither source has
precedence and neither may be regenerated from the other and treated as
canonical.

Client contract locks pin the exact authority commit plus both source paths.
Generated schemas/types, Contract IR, fixtures, reports, and receipts are
conformance evidence only. A language client is promoted to `conformant` only
after its exact head executes the pinned canonical fixture and the repository's
language-specific gates.
