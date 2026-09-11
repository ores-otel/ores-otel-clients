import type { ClientConfig } from "./config";
import { ClientError } from "./errors";
import type { ApmSnapshot, Health } from "./types";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireRecord(value: unknown, field: string): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new ClientError(`invalid_apm_${field}`);
  }
  return value;
}

function requireString(record: Record<string, unknown>, field: string): string {
  const value = record[field];
  if (typeof value !== "string" || value.length === 0) {
    throw new ClientError(`invalid_apm_${field}`);
  }
  return value;
}

function requireNumber(record: Record<string, unknown>, field: string): number {
  const value = record[field];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new ClientError(`invalid_apm_${field}`);
  }
  return value;
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

function decodeApmSnapshotValue(value: unknown): ApmSnapshot {
  const root = requireRecord(value, "root");
  if (root.schema_version !== 1) {
    throw new ClientError("invalid_apm_schema_version");
  }
  requireString(root, "observed_at_unix_nano");
  requireString(root, "service_name");
  requireString(root, "service_instance_id");

  const process = requireRecord(root.process, "process");
  requireNumber(process, "cpu_time_seconds");
  requireNumber(process, "cpu_utilization");
  requireString(process, "memory_usage_bytes");
  requireString(process, "memory_virtual_bytes");
  requireString(process, "disk_read_bytes");
  requireString(process, "disk_write_bytes");
  requireNumber(process, "uptime_seconds");

  if (!Array.isArray(root.filesystems)) {
    throw new ClientError("invalid_apm_filesystems");
  }
  const service = requireRecord(root.service, "service");
  requireString(service, "request_count");
  requireString(service, "error_count");
  requireString(service, "active_requests");
  requireRecord(service.latency_seconds, "latency_seconds");
  requireRecord(root.capabilities, "capabilities");

  // JSON.parse creates a new object graph; deepFreeze makes the transport result
  // immutable at runtime rather than exposing a mutable shared object to callers.
  return deepFreeze(root as unknown as ApmSnapshot);
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
    return this.decodeBoundedJson(body) as Health;
  }

  /**
   * Decode a serialized ORES APM snapshot obtained through caller-owned transport.
   * The shared contract intentionally does not define an HTTP route, so this client
   * does not invent one.
   */
  decodeApmSnapshot(body: Uint8Array): ApmSnapshot {
    return decodeApmSnapshotValue(this.decodeBoundedJson(body));
  }

  private decodeBoundedJson(body: Uint8Array): unknown {
    if (body.byteLength > this.config.maxResponseBytes) {
      throw new ClientError("too_large");
    }
    try {
      return JSON.parse(new TextDecoder().decode(body)) as unknown;
    } catch {
      throw new ClientError("invalid_json");
    }
  }
}
