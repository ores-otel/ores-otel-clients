import 'dart:collection';

class ProcessSnapshot {
  ProcessSnapshot({
    required this.cpuTimeSeconds,
    required this.cpuUtilization,
    required this.memoryUsageBytes,
    required this.memoryVirtualBytes,
    required this.diskReadBytes,
    required this.diskWriteBytes,
    required this.uptimeSeconds,
    this.memoryUtilization,
    this.diskReadOperations,
    this.diskWriteOperations,
    this.networkReceiveBytes,
    this.networkTransmitBytes,
    this.threadCount,
    this.fileDescriptorCount,
    this.handleCount,
    this.contextSwitches,
    this.pagingFaults,
  });

  final double cpuTimeSeconds;
  final double cpuUtilization;
  final String memoryUsageBytes;
  final String memoryVirtualBytes;
  final double? memoryUtilization;
  final String diskReadBytes;
  final String diskWriteBytes;
  final String? diskReadOperations;
  final String? diskWriteOperations;
  final String? networkReceiveBytes;
  final String? networkTransmitBytes;
  final String? threadCount;
  final String? fileDescriptorCount;
  final String? handleCount;
  final String? contextSwitches;
  final String? pagingFaults;
  final double uptimeSeconds;

  factory ProcessSnapshot.fromJson(Map<String, Object?> json) => ProcessSnapshot(
        cpuTimeSeconds: _number(json, 'cpu_time_seconds'),
        cpuUtilization: _number(json, 'cpu_utilization'),
        memoryUsageBytes: _string(json, 'memory_usage_bytes'),
        memoryVirtualBytes: _string(json, 'memory_virtual_bytes'),
        memoryUtilization: _optionalNumber(json, 'memory_utilization'),
        diskReadBytes: _string(json, 'disk_read_bytes'),
        diskWriteBytes: _string(json, 'disk_write_bytes'),
        diskReadOperations: _optionalString(json, 'disk_read_operations'),
        diskWriteOperations: _optionalString(json, 'disk_write_operations'),
        networkReceiveBytes: _optionalString(json, 'network_receive_bytes'),
        networkTransmitBytes: _optionalString(json, 'network_transmit_bytes'),
        threadCount: _optionalString(json, 'thread_count'),
        fileDescriptorCount: _optionalString(json, 'file_descriptor_count'),
        handleCount: _optionalString(json, 'handle_count'),
        contextSwitches: _optionalString(json, 'context_switches'),
        pagingFaults: _optionalString(json, 'paging_faults'),
        uptimeSeconds: _number(json, 'uptime_seconds'),
      );
}

class FilesystemSnapshot {
  FilesystemSnapshot({
    required this.target,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.availableBytes,
    required this.utilization,
    this.filesTotal,
    this.filesFree,
    this.readOnly,
  });

  final String target;
  final String totalBytes;
  final String usedBytes;
  final String freeBytes;
  final String availableBytes;
  final double utilization;
  final String? filesTotal;
  final String? filesFree;
  final bool? readOnly;

  factory FilesystemSnapshot.fromJson(Map<String, Object?> json) =>
      FilesystemSnapshot(
        target: _string(json, 'target'),
        totalBytes: _string(json, 'total_bytes'),
        usedBytes: _string(json, 'used_bytes'),
        freeBytes: _string(json, 'free_bytes'),
        availableBytes: _string(json, 'available_bytes'),
        utilization: _number(json, 'utilization'),
        filesTotal: _optionalString(json, 'files_total'),
        filesFree: _optionalString(json, 'files_free'),
        readOnly: json['read_only'] as bool?,
      );
}

class HistogramBucket {
  HistogramBucket({required this.upperBound, required this.count});
  final double upperBound;
  final String count;

  factory HistogramBucket.fromJson(Map<String, Object?> json) => HistogramBucket(
        upperBound: _number(json, 'upper_bound'),
        count: _string(json, 'count'),
      );
}

class Exemplar {
  Exemplar({
    required this.traceId,
    required this.spanId,
    required this.value,
    required this.timestampUnixNano,
  });

  final String traceId;
  final String spanId;
  final double value;
  final String timestampUnixNano;

  factory Exemplar.fromJson(Map<String, Object?> json) => Exemplar(
        traceId: _string(json, 'trace_id'),
        spanId: _string(json, 'span_id'),
        value: _number(json, 'value'),
        timestampUnixNano: _string(json, 'timestamp_unix_nano'),
      );
}

class HistogramPoint {
  HistogramPoint({
    required this.count,
    required this.sum,
    required List<HistogramBucket> buckets,
    List<Exemplar> exemplars = const [],
    this.min,
    this.max,
  })  : buckets = List.unmodifiable(buckets),
        exemplars = List.unmodifiable(exemplars);

  final String count;
  final double sum;
  final double? min;
  final double? max;
  final List<HistogramBucket> buckets;
  final List<Exemplar> exemplars;

  factory HistogramPoint.fromJson(Map<String, Object?> json) => HistogramPoint(
        count: _string(json, 'count'),
        sum: _number(json, 'sum'),
        min: _optionalNumber(json, 'min'),
        max: _optionalNumber(json, 'max'),
        buckets: _listOfMaps(json, 'buckets')
            .map(HistogramBucket.fromJson)
            .toList(growable: false),
        exemplars: _optionalListOfMaps(json, 'exemplars')
            .map(Exemplar.fromJson)
            .toList(growable: false),
      );
}

class ServicePerformanceSnapshot {
  ServicePerformanceSnapshot({
    required this.requestCount,
    required this.errorCount,
    required this.activeRequests,
    required this.latencySeconds,
    this.saturationRatio,
  });

  final String requestCount;
  final String errorCount;
  final String activeRequests;
  final HistogramPoint latencySeconds;
  final double? saturationRatio;

  factory ServicePerformanceSnapshot.fromJson(Map<String, Object?> json) =>
      ServicePerformanceSnapshot(
        requestCount: _string(json, 'request_count'),
        errorCount: _string(json, 'error_count'),
        activeRequests: _string(json, 'active_requests'),
        latencySeconds:
            HistogramPoint.fromJson(_map(json, 'latency_seconds')),
        saturationRatio: _optionalNumber(json, 'saturation_ratio'),
      );
}

class RuntimeMetric {
  RuntimeMetric({
    required this.runtimeNamespace,
    required this.name,
    required this.unit,
    required this.value,
  });

  final String runtimeNamespace;
  final String name;
  final String unit;
  final double value;

  factory RuntimeMetric.fromJson(Map<String, Object?> json) => RuntimeMetric(
        runtimeNamespace: _string(json, 'runtime_namespace'),
        name: _string(json, 'name'),
        unit: _string(json, 'unit'),
        value: _number(json, 'value'),
      );
}

class RuntimeSnapshot {
  RuntimeSnapshot({
    required this.runtimeName,
    required List<RuntimeMetric> metrics,
    this.runtimeVersion,
  }) : metrics = List.unmodifiable(metrics);

  final String runtimeName;
  final String? runtimeVersion;
  final List<RuntimeMetric> metrics;

  factory RuntimeSnapshot.fromJson(Map<String, Object?> json) => RuntimeSnapshot(
        runtimeName: _string(json, 'runtime_name'),
        runtimeVersion: _optionalString(json, 'runtime_version'),
        metrics: _listOfMaps(json, 'metrics')
            .map(RuntimeMetric.fromJson)
            .toList(growable: false),
      );
}

class ProfileCapability {
  ProfileCapability({required this.kind, required this.status});
  final String kind;
  final String status;

  factory ProfileCapability.fromJson(Map<String, Object?> json) =>
      ProfileCapability(
        kind: _string(json, 'kind'),
        status: _string(json, 'status'),
      );
}

class ApmCapabilitySet {
  ApmCapabilitySet({
    required this.processMetrics,
    required this.filesystemMetrics,
    required this.runtimeMetrics,
    required this.latencyHistograms,
    required this.exemplars,
    required this.traceCorrelation,
    required this.logCorrelation,
    required this.metricsExport,
    required this.tracesExport,
    required this.logsExport,
    required this.profilesExport,
    required this.errorTracking,
    required this.serviceTopology,
    required this.sloInputs,
    required List<ProfileCapability> profiling,
  }) : profiling = List.unmodifiable(profiling);

  final String processMetrics;
  final String filesystemMetrics;
  final String runtimeMetrics;
  final String latencyHistograms;
  final String exemplars;
  final String traceCorrelation;
  final String logCorrelation;
  final String metricsExport;
  final String tracesExport;
  final String logsExport;
  final String profilesExport;
  final String errorTracking;
  final String serviceTopology;
  final String sloInputs;
  final List<ProfileCapability> profiling;

  factory ApmCapabilitySet.fromJson(Map<String, Object?> json) => ApmCapabilitySet(
        processMetrics: _string(json, 'process_metrics'),
        filesystemMetrics: _string(json, 'filesystem_metrics'),
        runtimeMetrics: _string(json, 'runtime_metrics'),
        latencyHistograms: _string(json, 'latency_histograms'),
        exemplars: _string(json, 'exemplars'),
        traceCorrelation: _string(json, 'trace_correlation'),
        logCorrelation: _string(json, 'log_correlation'),
        metricsExport: _string(json, 'metrics_export'),
        tracesExport: _string(json, 'traces_export'),
        logsExport: _string(json, 'logs_export'),
        profilesExport: _string(json, 'profiles_export'),
        errorTracking: _string(json, 'error_tracking'),
        serviceTopology: _string(json, 'service_topology'),
        sloInputs: _string(json, 'slo_inputs'),
        profiling: _listOfMaps(json, 'profiling')
            .map(ProfileCapability.fromJson)
            .toList(growable: false),
      );
}

class ApmSnapshot {
  ApmSnapshot({
    required this.schemaVersion,
    required this.observedAtUnixNano,
    required this.serviceName,
    required this.serviceInstanceId,
    required this.process,
    required List<FilesystemSnapshot> filesystems,
    required this.service,
    required this.capabilities,
    this.runtime,
    Map<String, Object?>? correlation,
    List<Map<String, Object?>> profiles = const [],
    List<Map<String, Object?>> metrics = const [],
  })  : filesystems = List.unmodifiable(filesystems),
        correlation = correlation == null
            ? null
            : UnmodifiableMapView(Map<String, Object?>.from(correlation)),
        profiles = List.unmodifiable(
            profiles.map((item) => UnmodifiableMapView(Map<String, Object?>.from(item)))),
        metrics = List.unmodifiable(
            metrics.map((item) => UnmodifiableMapView(Map<String, Object?>.from(item))));

  final int schemaVersion;
  final String observedAtUnixNano;
  final String serviceName;
  final String serviceInstanceId;
  final ProcessSnapshot process;
  final List<FilesystemSnapshot> filesystems;
  final RuntimeSnapshot? runtime;
  final ServicePerformanceSnapshot service;
  final Map<String, Object?>? correlation;
  final List<Map<String, Object?>> profiles;
  final ApmCapabilitySet capabilities;
  final List<Map<String, Object?>> metrics;

  factory ApmSnapshot.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schema_version'];
    if (schemaVersion != 1) {
      throw const FormatException('invalid_apm_schema_version');
    }
    return ApmSnapshot(
      schemaVersion: 1,
      observedAtUnixNano: _string(json, 'observed_at_unix_nano'),
      serviceName: _string(json, 'service_name'),
      serviceInstanceId: _string(json, 'service_instance_id'),
      process: ProcessSnapshot.fromJson(_map(json, 'process')),
      filesystems: _listOfMaps(json, 'filesystems')
          .map(FilesystemSnapshot.fromJson)
          .toList(growable: false),
      runtime: json['runtime'] == null
          ? null
          : RuntimeSnapshot.fromJson(_map(json, 'runtime')),
      service: ServicePerformanceSnapshot.fromJson(_map(json, 'service')),
      correlation: json['correlation'] == null ? null : _map(json, 'correlation'),
      profiles: _optionalListOfMaps(json, 'profiles'),
      capabilities: ApmCapabilitySet.fromJson(_map(json, 'capabilities')),
      metrics: _optionalListOfMaps(json, 'metrics'),
    );
  }
}

Map<String, Object?> _map(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return Map<String, Object?>.from(value);
  throw FormatException('invalid_apm_$key');
}

List<Map<String, Object?>> _listOfMaps(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('invalid_apm_$key');
  return value.map((item) {
    if (item is Map<String, Object?>) return Map<String, Object?>.from(item);
    throw FormatException('invalid_apm_$key');
  }).toList(growable: false);
}

List<Map<String, Object?>> _optionalListOfMaps(
    Map<String, Object?> json, String key) {
  if (json[key] == null) return const [];
  return _listOfMaps(json, key);
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('invalid_apm_$key');
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('invalid_apm_$key');
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('invalid_apm_$key');
}

double? _optionalNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('invalid_apm_$key');
}
