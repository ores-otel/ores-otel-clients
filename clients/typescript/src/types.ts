export interface Health {
  readonly ok: boolean;
  readonly service: string;
}

export interface ResourceEnvelope {
  readonly id: string;
  readonly revision: string;
  readonly payload: Readonly<Record<string, unknown>>;
}

export const RESOURCE = "TelemetryRecord" as const;

export type DecodeErrorCode =
  | "too_large"
  | "invalid_json"
  | "invalid_apm_root"
  | "invalid_apm_schema_version"
  | "invalid_apm_required_field"
  | "invalid_apm_process"
  | "invalid_apm_filesystems"
  | "invalid_apm_service"
  | "invalid_apm_capabilities";

export type DecodeResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: DecodeErrorCode };

export type ApmCapabilityStatus =
  | "unsupported"
  | "model-only"
  | "external-adapter"
  | "native";

export type MetricKind = "gauge" | "counter" | "up-down-counter" | "histogram";
export type ProfileKind = "cpu" | "wall" | "allocation" | "heap" | "lock" | "blocking";

export interface Attribute {
  readonly key: string;
  readonly value: string;
}

export interface Exemplar {
  readonly trace_id: string;
  readonly span_id: string;
  readonly value: number;
  readonly timestamp_unix_nano: string;
}

export interface HistogramBucket {
  readonly upper_bound: number;
  readonly count: string;
}

export interface HistogramPoint {
  readonly count: string;
  readonly sum: number;
  readonly min?: number;
  readonly max?: number;
  readonly buckets: readonly HistogramBucket[];
  readonly exemplars?: readonly Exemplar[];
}

export interface MetricPoint {
  readonly name: string;
  readonly unit: string;
  readonly kind: MetricKind;
  readonly timestamp_unix_nano: string;
  readonly value?: number;
  readonly histogram?: HistogramPoint;
  readonly attributes?: readonly Attribute[];
}

export interface ProcessSnapshot {
  readonly cpu_time_seconds: number;
  readonly cpu_utilization: number;
  readonly memory_usage_bytes: string;
  readonly memory_virtual_bytes: string;
  readonly memory_utilization?: number;
  readonly disk_read_bytes: string;
  readonly disk_write_bytes: string;
  readonly disk_read_operations?: string;
  readonly disk_write_operations?: string;
  readonly network_receive_bytes?: string;
  readonly network_transmit_bytes?: string;
  readonly thread_count?: string;
  readonly file_descriptor_count?: string;
  readonly handle_count?: string;
  readonly context_switches?: string;
  readonly paging_faults?: string;
  readonly uptime_seconds: number;
}

export interface FilesystemSnapshot {
  readonly target: string;
  readonly total_bytes: string;
  readonly used_bytes: string;
  readonly free_bytes: string;
  readonly available_bytes: string;
  readonly utilization: number;
  readonly files_total?: string;
  readonly files_free?: string;
  readonly read_only?: boolean;
}

export interface RuntimeMetric {
  readonly runtime_namespace: string;
  readonly name: string;
  readonly unit: string;
  readonly value: number;
  readonly attributes?: readonly Attribute[];
}

export interface RuntimeSnapshot {
  readonly runtime_name: string;
  readonly runtime_version?: string;
  readonly metrics: readonly RuntimeMetric[];
}

export interface ServicePerformanceSnapshot {
  readonly request_count: string;
  readonly error_count: string;
  readonly active_requests: string;
  readonly latency_seconds: HistogramPoint;
  readonly saturation_ratio?: number;
}

export interface ProfileCapability {
  readonly kind: ProfileKind;
  readonly status: ApmCapabilityStatus;
}

export interface ProfileSummary {
  readonly profile_id: string;
  readonly kind: ProfileKind;
  readonly start_unix_nano: string;
  readonly end_unix_nano: string;
  readonly sample_count: string;
  readonly dropped_sample_count: string;
  readonly format: string;
}

export interface CorrelationContext {
  readonly trace_id?: string;
  readonly span_id?: string;
  readonly trace_flags?: number;
}

export interface ApmCapabilitySet {
  readonly process_metrics: ApmCapabilityStatus;
  readonly filesystem_metrics: ApmCapabilityStatus;
  readonly runtime_metrics: ApmCapabilityStatus;
  readonly latency_histograms: ApmCapabilityStatus;
  readonly exemplars: ApmCapabilityStatus;
  readonly trace_correlation: ApmCapabilityStatus;
  readonly log_correlation: ApmCapabilityStatus;
  readonly metrics_export: ApmCapabilityStatus;
  readonly traces_export: ApmCapabilityStatus;
  readonly logs_export: ApmCapabilityStatus;
  readonly profiles_export: ApmCapabilityStatus;
  readonly error_tracking: ApmCapabilityStatus;
  readonly service_topology: ApmCapabilityStatus;
  readonly slo_inputs: ApmCapabilityStatus;
  readonly profiling: readonly ProfileCapability[];
}

export interface ApmSnapshot {
  readonly schema_version: 1;
  readonly observed_at_unix_nano: string;
  readonly service_name: string;
  readonly service_instance_id: string;
  readonly process: ProcessSnapshot;
  readonly filesystems: readonly FilesystemSnapshot[];
  readonly runtime?: RuntimeSnapshot;
  readonly service: ServicePerformanceSnapshot;
  readonly correlation?: CorrelationContext;
  readonly profiles?: readonly ProfileSummary[];
  readonly capabilities: ApmCapabilitySet;
  readonly metrics?: readonly MetricPoint[];
}
