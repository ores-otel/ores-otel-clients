#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Health {
    pub ok: bool,
    pub service: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ResourceEnvelope {
    pub id: String,
    pub revision: String,
    #[serde(default)]
    pub payload: Value,
}

impl ResourceEnvelope {
    pub const RESOURCE: &'static str = "TelemetryRecord";
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum ApmCapabilityStatus {
    Unsupported,
    ModelOnly,
    ExternalAdapter,
    Native,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum MetricKind {
    Gauge,
    Counter,
    UpDownCounter,
    Histogram,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum ProfileKind {
    Cpu,
    Wall,
    Allocation,
    Heap,
    Lock,
    Blocking,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Attribute {
    pub key: String,
    pub value: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Exemplar {
    pub trace_id: String,
    pub span_id: String,
    pub value: f64,
    pub timestamp_unix_nano: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HistogramBucket {
    pub upper_bound: f64,
    pub count: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HistogramPoint {
    pub count: String,
    pub sum: f64,
    #[serde(default)]
    pub min: Option<f64>,
    #[serde(default)]
    pub max: Option<f64>,
    pub buckets: Vec<HistogramBucket>,
    #[serde(default)]
    pub exemplars: Vec<Exemplar>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct MetricPoint {
    pub name: String,
    pub unit: String,
    pub kind: MetricKind,
    pub timestamp_unix_nano: String,
    #[serde(default)]
    pub value: Option<f64>,
    #[serde(default)]
    pub histogram: Option<HistogramPoint>,
    #[serde(default)]
    pub attributes: Vec<Attribute>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ProcessSnapshot {
    pub cpu_time_seconds: f64,
    pub cpu_utilization: f64,
    pub memory_usage_bytes: String,
    pub memory_virtual_bytes: String,
    #[serde(default)]
    pub memory_utilization: Option<f64>,
    pub disk_read_bytes: String,
    pub disk_write_bytes: String,
    #[serde(default)]
    pub disk_read_operations: Option<String>,
    #[serde(default)]
    pub disk_write_operations: Option<String>,
    #[serde(default)]
    pub network_receive_bytes: Option<String>,
    #[serde(default)]
    pub network_transmit_bytes: Option<String>,
    #[serde(default)]
    pub thread_count: Option<String>,
    #[serde(default)]
    pub file_descriptor_count: Option<String>,
    #[serde(default)]
    pub handle_count: Option<String>,
    #[serde(default)]
    pub context_switches: Option<String>,
    #[serde(default)]
    pub paging_faults: Option<String>,
    pub uptime_seconds: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct FilesystemSnapshot {
    pub target: String,
    pub total_bytes: String,
    pub used_bytes: String,
    pub free_bytes: String,
    pub available_bytes: String,
    pub utilization: f64,
    #[serde(default)]
    pub files_total: Option<String>,
    #[serde(default)]
    pub files_free: Option<String>,
    #[serde(default)]
    pub read_only: Option<bool>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct RuntimeMetric {
    pub runtime_namespace: String,
    pub name: String,
    pub unit: String,
    pub value: f64,
    #[serde(default)]
    pub attributes: Vec<Attribute>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct RuntimeSnapshot {
    pub runtime_name: String,
    #[serde(default)]
    pub runtime_version: Option<String>,
    pub metrics: Vec<RuntimeMetric>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ServicePerformanceSnapshot {
    pub request_count: String,
    pub error_count: String,
    pub active_requests: String,
    pub latency_seconds: HistogramPoint,
    #[serde(default)]
    pub saturation_ratio: Option<f64>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProfileCapability {
    pub kind: ProfileKind,
    pub status: ApmCapabilityStatus,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProfileSummary {
    pub profile_id: String,
    pub kind: ProfileKind,
    pub start_unix_nano: String,
    pub end_unix_nano: String,
    pub sample_count: String,
    pub dropped_sample_count: String,
    pub format: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CorrelationContext {
    #[serde(default)]
    pub trace_id: Option<String>,
    #[serde(default)]
    pub span_id: Option<String>,
    #[serde(default)]
    pub trace_flags: Option<u8>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ApmCapabilitySet {
    pub process_metrics: ApmCapabilityStatus,
    pub filesystem_metrics: ApmCapabilityStatus,
    pub runtime_metrics: ApmCapabilityStatus,
    pub latency_histograms: ApmCapabilityStatus,
    pub exemplars: ApmCapabilityStatus,
    pub trace_correlation: ApmCapabilityStatus,
    pub log_correlation: ApmCapabilityStatus,
    pub metrics_export: ApmCapabilityStatus,
    pub traces_export: ApmCapabilityStatus,
    pub logs_export: ApmCapabilityStatus,
    pub profiles_export: ApmCapabilityStatus,
    pub error_tracking: ApmCapabilityStatus,
    pub service_topology: ApmCapabilityStatus,
    pub slo_inputs: ApmCapabilityStatus,
    pub profiling: Vec<ProfileCapability>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ApmSnapshot {
    pub schema_version: u8,
    pub observed_at_unix_nano: String,
    pub service_name: String,
    pub service_instance_id: String,
    pub process: ProcessSnapshot,
    pub filesystems: Vec<FilesystemSnapshot>,
    #[serde(default)]
    pub runtime: Option<RuntimeSnapshot>,
    pub service: ServicePerformanceSnapshot,
    #[serde(default)]
    pub correlation: Option<CorrelationContext>,
    #[serde(default)]
    pub profiles: Vec<ProfileSummary>,
    pub capabilities: ApmCapabilitySet,
    #[serde(default)]
    pub metrics: Vec<MetricPoint>,
}
