# Governance

This directory binds the client-language implementation surface to the repository's existing contract and conformance authorities.

- `clients/support-matrix.toml` declares the supported language set and APM status.
- `contracts/ores-apm.lock.json` pins the upstream APM contract source.
- `contract-admission/contract-ir-consumer.json` declares the TypeSpec/JSON Schema admission policy.
- `conformance/` remains the implementation-neutral behavior/evidence boundary.

Run `node governance/check.mjs` before promotion. The gate fails closed on unregistered client directories, stale/missing language entries, authority-lock drift, unsafe status values, and validator-pin disagreement.
