import type { ClientConfig } from "./config";
import { ClientError } from "./errors";
import type {
  ApmDecodeError,
  ApmDecodeErrorCode,
  ApmSnapshot,
  Health,
  Result,
} from "./types";

const success = <T>(value: T): Result<T, ApmDecodeError> => ({ ok: true, value });

const failure = <T>(code: ApmDecodeErrorCode): Result<T, ApmDecodeError> => ({
  ok: false,
  error: { code },
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireRecord(
  value: unknown,
  code: ApmDecodeErrorCode,
): Result<Record<string, unknown>, ApmDecodeError> {
  return isRecord(value) ? success(value) : failure(code);
}

function requireString(
  record: Record<string, unknown>,
  field: string,
  code: ApmDecodeErrorCode,
): Result<string, ApmDecodeError> {
  const value = record[field];
  return typeof value === "string" && value.length > 0 ? success(value) : failure(code);
}

function requireNumber(
  record: Record<string, unknown>,
  field: string,
  code: ApmDecodeErrorCode,
): Result<number, ApmDecodeError> {
  const value = record[field];
  return typeof value === "number" && Number.isFinite(value) ? success(value) : failure(code);
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

function decodeApmSnapshotValue(value: unknown): Result<ApmSnapshot, ApmDecodeError> {
  const rootResult = requireRecord(value, "invalid_apm_root");
  if (!rootResult.ok) return rootResult;
  const root = rootResult.value;
  if (root.schema_version !== 1) return failure("invalid_apm_schema_version");

  const observedAt = requireString(
    root,
    "observed_at_unix_nano",
    "invalid_apm_observed_at_unix_nano",
  );
  if (!observedAt.ok) return observedAt;
  const serviceName = requireString(root, "service_name", "invalid_apm_service_name");
  if (!serviceName.ok) return serviceName;
  const serviceInstanceId = requireString(
    root,
    "service_instance_id",
    "invalid_apm_service_instance_id",
  );
  if (!serviceInstanceId.ok) return serviceInstanceId;

  const processResult = requireRecord(root.process, "invalid_apm_process");
  if (!processResult.ok) return processResult;
  const process = processResult.value;
  const cpuTime = requireNumber(process, "cpu_time_seconds", "invalid_apm_cpu_time_seconds");
  if (!cpuTime.ok) return cpuTime;
  const cpuUtilization = requireNumber(
    process,
    "cpu_utilization",
    "invalid_apm_cpu_utilization",
  );
  if (!cpuUtilization.ok) return cpuUtilization;
  const memoryUsage = requireString(
    process,
    "memory_usage_bytes",
    "invalid_apm_memory_usage_bytes",
  );
  if (!memoryUsage.ok) return memoryUsage;
  const memoryVirtual = requireString(
    process,
    "memory_virtual_bytes",
    "invalid_apm_memory_virtual_bytes",
  );
  if (!memoryVirtual.ok) return memoryVirtual;
  const diskRead = requireString(process, "disk_read_bytes", "invalid_apm_disk_read_bytes");
  if (!diskRead.ok) return diskRead;
  const diskWrite = requireString(process, "disk_write_bytes", "invalid_apm_disk_write_bytes");
  if (!diskWrite.ok) return diskWrite;
  const uptime = requireNumber(process, "uptime_seconds", "invalid_apm_uptime_seconds");
  if (!uptime.ok) return uptime;

  if (!Array.isArray(root.filesystems)) return failure("invalid_apm_filesystems");

  const serviceResult = requireRecord(root.service, "invalid_apm_service");
  if (!serviceResult.ok) return serviceResult;
  const service = serviceResult.value;
  const requestCount = requireString(service, "request_count", "invalid_apm_request_count");
  if (!requestCount.ok) return requestCount;
  const errorCount = requireString(service, "error_count", "invalid_apm_error_count");
  if (!errorCount.ok) return errorCount;
  const activeRequests = requireString(
    service,
    "active_requests",
    "invalid_apm_active_requests",
  );
  if (!activeRequests.ok) return activeRequests;
  const latency = requireRecord(service.latency_seconds, "invalid_apm_latency_seconds");
  if (!latency.ok) return latency;
  const capabilities = requireRecord(root.capabilities, "invalid_apm_capabilities");
  if (!capabilities.ok) return capabilities;

  return success(deepFreeze(root as unknown as ApmSnapshot));
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
    if (body.byteLength > this.config.maxResponseBytes) {
      throw new ClientError("too_large");
    }
    try {
      return JSON.parse(new TextDecoder().decode(body)) as Health;
    } catch {
      throw new ClientError("invalid_json");
    }
  }

  /**
   * Decode a serialized ORES APM snapshot obtained through caller-owned transport.
   * The shared contract intentionally does not define an HTTP route, so this client
   * does not invent one. New APM validation failures stay explicit in the return type.
   */
  decodeApmSnapshot(body: Uint8Array): Result<ApmSnapshot, ApmDecodeError> {
    if (body.byteLength > this.config.maxResponseBytes) {
      return failure("too_large");
    }
    try {
      return decodeApmSnapshotValue(JSON.parse(new TextDecoder().decode(body)) as unknown);
    } catch {
      return failure("invalid_json");
    }
  }
}
