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

const baseline = JSON.parse(body.toString("utf8")) as Record<string, any>;
const mutate = (label: string, expectedCode: string, transform: (value: Record<string, any>) => void): void => {
  const input = structuredClone(baseline);
  transform(input);
  const result = client.decodeApmSnapshot(
    new TextEncoder().encode(JSON.stringify(input)),
  );
  assert.deepEqual(result, { ok: false, error: { code: expectedCode } }, label);
};

mutate("identity must be a nonempty string", "invalid_apm_service_name", (value) => {
  value.service_name = "";
});
mutate("service instance identity must not be coerced", "invalid_apm_service_instance_id", (value) => {
  value.service_instance_id = 404;
});
mutate("observed timestamp must be a string", "invalid_apm_observed_at_unix_nano", (value) => {
  value.observed_at_unix_nano = null;
});
mutate("process must be a record", "invalid_apm_process", (value) => {
  value.process = [];
});
mutate("CPU time must be a finite number", "invalid_apm_cpu_time_seconds", (value) => {
  value.process.cpu_time_seconds = "0";
});
mutate("CPU utilization must be a number", "invalid_apm_cpu_utilization", (value) => {
  value.process.cpu_utilization = null;
});
mutate("memory usage cannot be a JSON integer", "invalid_apm_memory_usage_bytes", (value) => {
  value.process.memory_usage_bytes = 1234;
});
mutate("disk writes must be string encoded", "invalid_apm_disk_write_bytes", (value) => {
  value.process.disk_write_bytes = false;
});
mutate("filesystems must be an array", "invalid_apm_filesystems", (value) => {
  value.filesystems = {};
});
mutate("service counters cannot be coerced", "invalid_apm_request_count", (value) => {
  value.service.request_count = 0;
});
mutate("latency must be an object", "invalid_apm_latency_seconds", (value) => {
  value.service.latency_seconds = [];
});
mutate("capabilities must be an object", "invalid_apm_capabilities", (value) => {
  value.capabilities = null;
});

const exactLimit = new Client({
  baseUrl: "https://example.invalid",
  maxResponseBytes: body.byteLength,
});
assert.equal(exactLimit.decodeApmSnapshot(body).ok, true);
assert.deepEqual(new Client({
  baseUrl: "https://example.invalid",
  maxResponseBytes: body.byteLength - 1,
}).decodeApmSnapshot(body), { ok: false, error: { code: "too_large" } });

assert.ok(Object.isFrozen(snapshot.service));
assert.ok(Object.isFrozen(snapshot.service.latency_seconds));
assert.ok(Object.isFrozen(snapshot.capabilities));
assert.ok(Object.isFrozen(snapshot.capabilities.profiling));
assert.throws(() => {
  (snapshot.process as unknown as { cpu_time_seconds: number }).cpu_time_seconds = 999;
}, TypeError);
