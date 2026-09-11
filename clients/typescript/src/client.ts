import type { ClientConfig } from "./config";
import { ClientError } from "./errors";
import type { ApmSnapshot, DecodeResult, Health } from "./types";

type JsonDecodeError = "too_large" | "invalid_json";
type JsonDecodeResult =
  | { readonly ok: true; readonly value: unknown }
  | { readonly ok: false; readonly error: JsonDecodeError };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.length > 0;
}

function finiteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function deepFreeze<T>(value: T): T {
  if (typeof value !== "object" || value === null || Object.isFrozen(value)) {
    return value;
  }
  for (const child of Object.values(value as Record<string, unknown>)) {
    deepFreeze(child);
  }
  return Object.freeze(value);
}

function decodeApmSnapshotValue(value: unknown): DecodeResult<ApmSnapshot> {
  if (!isRecord(value)) return { ok: false, error: "invalid_apm_root" };
  if (value.schema_version !== 1) {
    return { ok: false, error: "invalid_apm_schema_version" };
  }
  if (
    !nonEmptyString(value.observed_at_unix_nano)
    || !nonEmptyString(value.service_name)
    || !nonEmptyString(value.service_instance_id)
  ) {
    return { ok: false, error: "invalid_apm_required_field" };
  }

  const process = value.process;
  if (
    !isRecord(process)
    || !finiteNumber(process.cpu_time_seconds)
    || !finiteNumber(process.cpu_utilization)
    || !nonEmptyString(process.memory_usage_bytes)
    || !nonEmptyString(process.memory_virtual_bytes)
    || !nonEmptyString(process.disk_read_bytes)
    || !nonEmptyString(process.disk_write_bytes)
    || !finiteNumber(process.uptime_seconds)
  ) {
    return { ok: false, error: "invalid_apm_process" };
  }
  if (!Array.isArray(value.filesystems)) {
    return { ok: false, error: "invalid_apm_filesystems" };
  }

  const service = value.service;
  if (
    !isRecord(service)
    || !nonEmptyString(service.request_count)
    || !nonEmptyString(service.error_count)
    || !nonEmptyString(service.active_requests)
    || !isRecord(service.latency_seconds)
  ) {
    return { ok: false, error: "invalid_apm_service" };
  }
  if (!isRecord(value.capabilities)) {
    return { ok: false, error: "invalid_apm_capabilities" };
  }

  // JSON.parse produced this object graph exclusively for the caller. Freezing it
  // recursively creates an immutable transport snapshot without mutating caller-owned
  // state or introducing a shared mutable cache.
  return { ok: true, value: deepFreeze(value as unknown as ApmSnapshot) };
}

export class Client {
  constructor(private readonly config: ClientConfig) {
    if (!config.baseUrl.trim()) {
      throw new ClientError("invalid_base");
    }
  }

  healthUrl(): string {
    return `${this.config.baseUrl.replace(/\/$/, "")}/v1/health`;
  }

  decodeHealth(body: Uint8Array): Health {
    const decoded = this.decodeBoundedJson(body);
    if (!decoded.ok) throw new ClientError(decoded.error);
    return decoded.value as Health;
  }

  /**
   * Decode an ORES APM snapshot obtained through caller-owned transport.
   *
   * The APM contract currently defines the serialized snapshot, not an HTTP route.
   * Failure is returned as a discriminated value rather than thrown, keeping the new
   * cross-runtime boundary explicit and composable.
   */
  decodeApmSnapshot(body: Uint8Array): DecodeResult<ApmSnapshot> {
    const decoded = this.decodeBoundedJson(body);
    return decoded.ok ? decodeApmSnapshotValue(decoded.value) : decoded;
  }

  private decodeBoundedJson(body: Uint8Array): JsonDecodeResult {
    if (body.byteLength > this.config.maxResponseBytes) {
      return { ok: false, error: "too_large" };
    }
    try {
      return { ok: true, value: JSON.parse(new TextDecoder().decode(body)) as unknown };
    } catch {
      return { ok: false, error: "invalid_json" };
    }
  }
}
