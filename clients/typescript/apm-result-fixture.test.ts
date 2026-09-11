import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";

import { Client } from "./src/client.ts";

const fixture = process.argv[2];
assert.ok(fixture, "usage: apm-result-fixture.test.ts <fixture.json>");

const client = new Client({
  baseUrl: "https://example.invalid",
  maxResponseBytes: 2 * 1024 * 1024,
});
const result = client.decodeApmSnapshot(readFileSync(fixture));
assert.equal(result.ok, true);
if (result.ok) {
  const snapshot = result.value;
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
}

const malformed = new TextEncoder().encode(JSON.stringify({ schema_version: 1 }));
assert.deepEqual(client.decodeApmSnapshot(malformed), {
  ok: false,
  error: "invalid_apm_required_field",
});

const invalidJson = new TextEncoder().encode("{");
assert.deepEqual(client.decodeApmSnapshot(invalidJson), {
  ok: false,
  error: "invalid_json",
});
