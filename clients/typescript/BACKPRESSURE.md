# Browser/client backpressure telemetry

The TypeScript client exposes a small transport-neutral observer for request queues. It is intentionally separate from UI: fetch/RPC/WebSocket wrappers emit lifecycle events, while a later UI component can subscribe to the same state without changing transport semantics.

## Required lifecycle

For a request that remains local because the client is pacing against server quota/capacity metadata:

1. emit `queued` when the request enters the bounded local queue;
2. emit `delayed` when a pacing/retry timer is scheduled or extended;
3. emit `resumed` immediately before the actual fetch/RPC send;
4. emit `dropped` when queue age/bytes/count/cancellation policy removes it without sending;
5. emit `rejected` when the client receives a terminal quota/overload rejection that will not be retried.

A request can emit multiple `delayed` events if newer server metadata moves its eligible-send time later. Consumers should use queue/request state as the UI authority rather than counting telemetry events.

## Default browser behavior

`createBrowserBackpressureObserver()` defaults to a basic ores-otel console sink:

```text
[ores-otel] client backpressure { ...structured event... }
```

Queued/delayed/resumed events use `console.info`; dropped/rejected use `console.warn`. Applications can inject their normal ores-otel exporter instead. Telemetry failures are swallowed and recursive emission is suppressed so telemetry can never unblock, block, reorder, or recursively fill the application request queue.

## Safe fields

The event carries bounded metadata such as transport, phase/reason, queue age/depth/bytes, scheduled delay, retry delay, policy version, quota admission sequence/fence, limiting policy IDs, attempt and a stable operation identifier.

The API deliberately does **not** accept request/response bodies, JWTs, cookies, API keys, authorization headers, arbitrary headers, or full URLs. `operation` is restricted to a short safe identifier (for example `widgets.create`), so query strings and credential-bearing URLs are rejected rather than logged.

Quota sequence/fence values are represented as decimal strings. JavaScript numbers cannot exactly represent the full unsigned 64-bit range.

## Queue owner requirements

This observer does not own the queue. Fetch/RPC SDKs that use it must still enforce:

- bounded item count and serialized-byte count;
- maximum queue age / `queue_timeout_ms`;
- cancellation removal before send;
- idempotency-aware retries only;
- bounded jitter that never extends an item past its queue deadline;
- newest monotonic server quota metadata wins; stale/out-of-order metadata must not extend an exhausted policy or increase local credits;
- no alternate direct transport that bypasses backpressure when a shared worker/connection is congested.

The server remains authoritative; client pacing only reduces avoidable 429/503 responses and synchronized retry bursts.
