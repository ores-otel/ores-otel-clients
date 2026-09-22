# Governance

This directory binds the polyglot client implementation surface to the repository's existing contract and conformance authorities.

- `clients/support-matrix.toml` declares the supported language set, tiers, and APM conformance state.
- `.zpkg.toml` declares the package/release surface for those same client directories.
- `contracts/ores-apm.lock.json` pins the upstream APM authority in `ores-otel/ores-interfaces`.
- `contract-admission/contract-ir-consumer.json` declares TypeSpec/JSON Schema admission policy and the immutable validator revision.
- `conformance/` remains the shared behavior/evidence boundary; generated receipts are evidence, not authority.

Run `node governance/check.mjs` before promotion. The gate fails closed on unregistered or stale client directories, Zed target drift, unsafe/missing support-matrix states, APM authority-lock drift, and validator-pin disagreement.
