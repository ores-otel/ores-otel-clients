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

const canonical = JSON.parse(body.toString("utf8")) as Record<string, any>;
const cases: Array<{
  label: string;
  mutate: (snapshot: Record<string, any>) => void;
  code: string;
}> = [
  { label:"observed timestamp type", mutate:s=>{s.observed_at_unix_nano=42;}, code:"invalid_apm_observed_at_unix_nano" },
  { label:"empty service identity", mutate:s=>{s.service_name="";}, code:"invalid_apm_service_name" },
  { label:"instance identity null", mutate:s=>{s.service_instance_id=null;}, code:"invalid_apm_service_instance_id" },
  { label:"array instead of process", mutate:s=>{s.process=[];}, code:"invalid_apm_process" },
  { label:"CPU time wrong type", mutate:s=>{s.process.cpu_time_seconds="3";}, code:"invalid_apm_cpu_time_seconds" },
  { label:"CPU utilization nonnumeric", mutate:s=>{s.process.cpu_utilization=null;}, code:"invalid_apm_cpu_utilization" },
  { label:"memory as number", mutate:s=>{s.process.memory_usage_bytes=1;}, code:"invalid_apm_memory_usage_bytes" },
  { label:"disk bytes as number", mutate:s=>{s.process.disk_read_bytes=2;}, code:"invalid_apm_disk_read_bytes" },
  { label:"filesystems object", mutate:s=>{s.filesystems={};}, code:"invalid_apm_filesystems" },
  { label:"service missing", mutate:s=>{delete s.service;}, code:"invalid_apm_service" },
  { label:"request count numeric", mutate:s=>{s.service.request_count=123;}, code:"invalid_apm_request_count" },
  { label:"service latency missing", mutate:s=>{delete s.service.latency_seconds;}, code:"invalid_apm_latency_seconds" },
  { label:"capabilities array", mutate:s=>{s.capabilities=[];}, code:"invalid_apm_capabilities" },
];
for (const sample of cases) {
  const mutated=structuredClone(canonical);
  sample.mutate(mutated);
  const actual=client.decodeApmSnapshot(new TextEncoder().encode(JSON.stringify(mutated)));
  assert.deepEqual(actual,{ok:false,error:{code:sample.code}},sample.label);
}
// Exact size admission and deep immutable snapshots from the actual production SDK.
const exact = new Client({baseUrl:"https://example.invalid",maxResponseBytes:body.byteLength});
const boundary=exact.decodeApmSnapshot(body);
assert.equal(boundary.ok,true);
const oneByteShort = new Client({baseUrl:"https://example.invalid",maxResponseBytes:body.byteLength-1});
assert.deepEqual(oneByteShort.decodeApmSnapshot(body),{ok:false,error:{code:"too_large"}});
if (boundary.ok) {
  assert.ok(Object.isFrozen(boundary.value.service));
  assert.ok(Object.isFrozen(boundary.value.capabilities));
  assert.ok(Object.isFrozen(boundary.value.service.latency_seconds));
  assert.ok(Object.isFrozen(boundary.value.filesystems[0]));
}
const replay=client.decodeApmSnapshot(body);
assert.deepEqual(replay,decoded,"identical immutable decode must remain deterministic");
