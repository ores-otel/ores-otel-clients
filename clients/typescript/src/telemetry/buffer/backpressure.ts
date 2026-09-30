export type BackpressureTransport = "fetch" | "rpc" | "websocket" | "sse" | "other";

export type BackpressurePhase =
  | "queued"
  | "delayed"
  | "resumed"
  | "dropped"
  | "rejected";

export type BackpressureReason =
  | "local_pacing"
  | "server_retry_after"
  | "rate_limit"
  | "concurrency"
  | "queue_full"
  | "queue_timeout"
  | "transport_backpressure"
  | "service_overload"
  | "cancelled";

export interface BrowserBackpressureEvent {
  readonly schema_version: 1;
  readonly event_name: "ores.client.backpressure";
  readonly phase: BackpressurePhase;
  readonly transport: BackpressureTransport;
  readonly reason: BackpressureReason;
  readonly observed_at_unix_ms: number;
  readonly queued_at_unix_ms?: number;
  readonly queue_age_ms: number;
  readonly scheduled_delay_ms: number;
  readonly queue_depth?: number;
  readonly queue_bytes?: number;
  readonly retry_after_ms?: number;
  readonly recommended_next_request_after_ms?: number;
  readonly policy_version?: string;
  /**
   * Keep the server-provided quota fence as a decimal string. JavaScript
   * numbers cannot exactly represent the full unsigned 64-bit range.
   */
  readonly quota_fence?: string;
  readonly limiting_policy_ids?: readonly string[];
  readonly attempt?: number;
  readonly operation?: string;
  readonly idempotent?: boolean;
}

export interface BrowserBackpressureInput {
  readonly phase: BackpressurePhase;
  readonly transport: BackpressureTransport;
  readonly reason: BackpressureReason;
  readonly observed_at_unix_ms?: number;
  readonly queued_at_unix_ms?: number;
  readonly queue_age_ms?: number;
  readonly scheduled_delay_ms?: number;
  readonly queue_depth?: number;
  readonly queue_bytes?: number;
  readonly retry_after_ms?: number;
  readonly recommended_next_request_after_ms?: number;
  readonly policy_version?: string;
  readonly quota_fence?: string;
  readonly limiting_policy_ids?: readonly string[];
  readonly attempt?: number;
  /**
   * Stable operation identifier such as an RPC method name. Never pass a full
   * URL, request body, bearer token, cookie, API key, or other payload data.
   */
  readonly operation?: string;
  readonly idempotent?: boolean;
}

export type BrowserBackpressureSink = (event: BrowserBackpressureEvent) => void;

export interface BrowserBackpressureObserver {
  readonly emit: (input: BrowserBackpressureInput) => void;
  readonly queued: (input: Omit<BrowserBackpressureInput, "phase">) => void;
  readonly delayed: (input: Omit<BrowserBackpressureInput, "phase">) => void;
  readonly resumed: (input: Omit<BrowserBackpressureInput, "phase">) => void;
  readonly dropped: (input: Omit<BrowserBackpressureInput, "phase">) => void;
  readonly rejected: (input: Omit<BrowserBackpressureInput, "phase">) => void;
}

const MAX_SAFE = Number.MAX_SAFE_INTEGER;
const IDENTIFIER_RE = /^[A-Za-z0-9_.:/-]{1,128}$/;
const DECIMAL_U64_RE = /^(0|[1-9][0-9]{0,19})$/;

function boundedInteger(value: number | undefined): number | undefined {
  if (value === undefined || !Number.isFinite(value)) return undefined;
  return Math.min(MAX_SAFE, Math.max(0, Math.trunc(value)));
}

function safeIdentifier(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  return IDENTIFIER_RE.test(value) ? value : undefined;
}

function safeFence(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  return DECIMAL_U64_RE.test(value) ? value : undefined;
}

function safePolicyIds(values: readonly string[] | undefined): readonly string[] | undefined {
  if (values === undefined) return undefined;
  const unique = [...new Set(values.filter((value) => IDENTIFIER_RE.test(value)))].slice(0, 8);
  return unique.length === 0 ? undefined : Object.freeze(unique);
}

export function buildBrowserBackpressureEvent(
  input: BrowserBackpressureInput,
): BrowserBackpressureEvent {
  const observedAt = boundedInteger(input.observed_at_unix_ms) ?? Date.now();
  const queuedAt = boundedInteger(input.queued_at_unix_ms);
  const explicitQueueAge = boundedInteger(input.queue_age_ms);
  const queueAge =
    explicitQueueAge ?? (queuedAt === undefined ? 0 : Math.max(0, observedAt - queuedAt));

  return Object.freeze({
    schema_version: 1,
    event_name: "ores.client.backpressure",
    phase: input.phase,
    transport: input.transport,
    reason: input.reason,
    observed_at_unix_ms: observedAt,
    queued_at_unix_ms: queuedAt,
    queue_age_ms: queueAge,
    scheduled_delay_ms: boundedInteger(input.scheduled_delay_ms) ?? 0,
    queue_depth: boundedInteger(input.queue_depth),
    queue_bytes: boundedInteger(input.queue_bytes),
    retry_after_ms: boundedInteger(input.retry_after_ms),
    recommended_next_request_after_ms: boundedInteger(
      input.recommended_next_request_after_ms,
    ),
    policy_version: safeIdentifier(input.policy_version),
    quota_fence: safeFence(input.quota_fence),
    limiting_policy_ids: safePolicyIds(input.limiting_policy_ids),
    attempt: boundedInteger(input.attempt),
    operation: safeIdentifier(input.operation),
    idempotent: input.idempotent,
  });
}

/**
 * Minimal browser-visible ores-otel sink. This is intentionally console based:
 * applications can replace the sink with their normal ores-otel exporter while
 * preserving the exact same event shape. The console object is injected so the
 * helper remains testable and does not require a DOM.
 */
export function createConsoleBackpressureSink(
  logger: Pick<Console, "info" | "warn"> = console,
): BrowserBackpressureSink {
  return (event) => {
    if (event.phase === "dropped" || event.phase === "rejected") {
      logger.warn("[ores-otel] client backpressure", event);
      return;
    }
    logger.info("[ores-otel] client backpressure", event);
  };
}

/**
 * Creates a bounded, recursion-safe observer for client request queues.
 *
 * The queue/transport owner should emit `queued` when a message remains local,
 * `delayed` when a pacing/retry timer is scheduled, `resumed` immediately before
 * the fetch/RPC send, and `dropped`/`rejected` when the message will not be sent.
 * No request/response payload is accepted by this API, which prevents accidental
 * body/token logging at this boundary.
 */
export function createBrowserBackpressureObserver(
  sink: BrowserBackpressureSink = createConsoleBackpressureSink(),
): BrowserBackpressureObserver {
  // This module is deliberately under telemetry/buffer: it owns the tiny
  // stateful recursion guard at the outward telemetry boundary.
  let emitting = false;

  const emit = (input: BrowserBackpressureInput): void => {
    if (emitting) return;
    const event = buildBrowserBackpressureEvent(input);
    emitting = true;
    try {
      sink(event);
    } catch {
      // Telemetry must never break, unblock, or re-order the application queue.
    } finally {
      emitting = false;
    }
  };

  const withPhase =
    (phase: BackpressurePhase) =>
    (input: Omit<BrowserBackpressureInput, "phase">): void =>
      emit({ ...input, phase });

  return Object.freeze({
    emit,
    queued: withPhase("queued"),
    delayed: withPhase("delayed"),
    resumed: withPhase("resumed"),
    dropped: withPhase("dropped"),
    rejected: withPhase("rejected"),
  });
}
