import { strict as assert } from "node:assert";

import {
  buildBrowserBackpressureEvent,
  createBrowserBackpressureObserver,
} from "./src/telemetry/buffer/backpressure.ts";

const events: unknown[] = [];
const observer = createBrowserBackpressureObserver((event) => {
  events.push(event);
});

observer.queued({
  transport: "fetch",
  reason: "local_pacing",
  observed_at_unix_ms: 1_100,
  queued_at_unix_ms: 1_000,
  scheduled_delay_ms: 250,
  queue_depth: 3,
  queue_bytes: 512,
  policy_version: "free.v1",
  quota_fence: "18446744073709551615",
  limiting_policy_ids: ["minute", "minute", "hour"],
  operation: "widgets.create",
  idempotent: true,
});

assert.equal(events.length, 1);
const queued = events[0] as ReturnType<typeof buildBrowserBackpressureEvent>;
assert.equal(queued.event_name, "ores.client.backpressure");
assert.equal(queued.phase, "queued");
assert.equal(queued.queue_age_ms, 100);
assert.equal(queued.scheduled_delay_ms, 250);
assert.equal(queued.quota_fence, "18446744073709551615");
assert.deepEqual(queued.limiting_policy_ids, ["minute", "hour"]);
assert.ok(Object.isFrozen(queued));
assert.ok(Object.isFrozen(queued.limiting_policy_ids));

observer.delayed({
  transport: "rpc",
  reason: "server_retry_after",
  retry_after_ms: 1_000,
  scheduled_delay_ms: 1_137,
  queue_depth: 1,
});
observer.resumed({
  transport: "rpc",
  reason: "server_retry_after",
  queue_age_ms: 1_137,
});
observer.dropped({
  transport: "rpc",
  reason: "queue_timeout",
  queue_age_ms: 5_000,
});
assert.equal(events.length, 4);

const sanitized = buildBrowserBackpressureEvent({
  phase: "delayed",
  transport: "fetch",
  reason: "rate_limit",
  observed_at_unix_ms: Number.POSITIVE_INFINITY,
  queue_depth: -5,
  queue_bytes: Number.POSITIVE_INFINITY,
  operation: "https://example.test/private?token=secret",
  policy_version: "bad policy with spaces",
  quota_fence: "90071992547409931234567890",
  limiting_policy_ids: ["ok", "not safe value"],
});
assert.equal(sanitized.queue_depth, 0);
assert.equal(sanitized.queue_bytes, undefined);
assert.equal(sanitized.operation, undefined);
assert.equal(sanitized.policy_version, undefined);
assert.equal(sanitized.quota_fence, undefined);
assert.deepEqual(sanitized.limiting_policy_ids, ["ok"]);

let recursiveCount = 0;
let recursiveObserver: ReturnType<typeof createBrowserBackpressureObserver>;
recursiveObserver = createBrowserBackpressureObserver(() => {
  recursiveCount += 1;
  recursiveObserver.delayed({
    transport: "fetch",
    reason: "transport_backpressure",
  });
});
recursiveObserver.queued({
  transport: "fetch",
  reason: "local_pacing",
});
assert.equal(recursiveCount, 1);

const throwingObserver = createBrowserBackpressureObserver(() => {
  throw new Error("telemetry transport failed");
});
assert.doesNotThrow(() => {
  throwingObserver.queued({
    transport: "fetch",
    reason: "local_pacing",
  });
});
