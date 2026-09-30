export { Client } from "./client";
export { configFromEnv } from "./config";
export type { ClientConfig } from "./config";
export { ClientError } from "./errors";
export {
  buildBrowserBackpressureEvent,
  createBrowserBackpressureObserver,
  createConsoleBackpressureSink,
} from "./backpressure";
export type {
  BackpressurePhase,
  BackpressureReason,
  BackpressureTransport,
  BrowserBackpressureEvent,
  BrowserBackpressureInput,
  BrowserBackpressureObserver,
  BrowserBackpressureSink,
} from "./backpressure";
export type {
  ApmCapabilitySet,
  ApmCapabilityStatus,
  ApmDecodeError,
  ApmDecodeErrorCode,
  ApmSnapshot,
  Attribute,
  CorrelationContext,
  Exemplar,
  FilesystemSnapshot,
  Health,
  HistogramBucket,
  HistogramPoint,
  MetricKind,
  MetricPoint,
  ProcessSnapshot,
  ProfileCapability,
  ProfileKind,
  ProfileSummary,
  ResourceEnvelope,
  Result,
  RuntimeMetric,
  RuntimeSnapshot,
  ServicePerformanceSnapshot,
} from "./types";
export { RESOURCE } from "./types";
