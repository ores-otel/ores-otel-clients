import { readFileSync } from "node:fs";
import { strict as assert } from "node:assert";

import { Client } from "./src/client.ts";

const fixture = process.argv[2];
if (!fixture) {
  throw new Error("usage: apm-fixture.test.ts <fixture.json>");
}

const body = readFileSync(fixture);
const client = new Client({
  baseUrl: "https://example.invalid",
  maxResponseBytes: 2 * 1024 * 1024,
});
const decoded = client.decodeApmSnapshot(body);
assert.equal(decoded.ok, true);
if (!decoded.ok) {
  throw new Error(decoded.error.code);
}
const snapshot = decoded.value;

assert.equal(snapshot.schema_version, 1);
assert.ok(snapshot.service_name.length > 0);
assert.ok(snapshot.service_instance_id.length > 0);
assert.ok(snapshot.process.memory_usage_bytes.length > 0);
assert.ok(snapshot.process.disk_read_bytes.length > 0);
assert.ok(snapshot.filesystems.length > 0);
assert.ok(snapshot.service.latency_seconds.buckets.length > 0);
assert.ok(snapshot.capabilities.profiling.length > 0);
assert.ok(Object.isFrozen(snapshot));
assert.ok(Object.isFrozen(snapshot.process));
assert.ok(Object.isFrozen(snapshot.filesystems));

const invalidJson = client.decodeApmSnapshot(new TextEncoder().encode("{"));
assert.deepEqual(invalidJson, { ok: false, error: { code: "invalid_json" } });

const invalidSchema = client.decodeApmSnapshot(
  new TextEncoder().encode(JSON.stringify({ schema_version: 2 })),
);
assert.deepEqual(invalidSchema, {
  ok: false,
  error: { code: "invalid_apm_schema_version" },
});

const boundedClient = new Client({
  baseUrl: "https://example.invalid",
  maxResponseBytes: 1,
});
const tooLarge = boundedClient.decodeApmSnapshot(body);
assert.deepEqual(tooLarge, { ok: false, error: { code: "too_large" } });
