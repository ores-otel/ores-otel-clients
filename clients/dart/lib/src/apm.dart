enum ApmCapabilityStatus {
  unsupported('unsupported'),
  modelOnly('model-only'),
  externalAdapter('external-adapter'),
  native('native');

  const ApmCapabilityStatus(this.wireValue);
  final String wireValue;

  static ApmCapabilityStatus? parse(Object? value) => switch (value) {
        'unsupported' => ApmCapabilityStatus.unsupported,
        'model-only' => ApmCapabilityStatus.modelOnly,
        'external-adapter' => ApmCapabilityStatus.externalAdapter,
        'native' => ApmCapabilityStatus.native,
        _ => null,
      };
}

enum MetricKind {
  gauge('gauge'),
  counter('counter'),
  upDownCounter('up-down-counter'),
  histogram('histogram');

  const MetricKind(this.wireValue);
  final String wireValue;

  static MetricKind? parse(Object? value) => switch (value) {
        'gauge' => MetricKind.gauge,
        'counter' => MetricKind.counter,
        'up-down-counter' => MetricKind.upDownCounter,
        'histogram' => MetricKind.histogram,
        _ => null,
      };
}

enum ProfileKind {
  cpu('cpu'),
  wall('wall'),
  allocation('allocation'),
  heap('heap'),
  lock('lock'),
  blocking('blocking');

  const ProfileKind(this.wireValue);
  final String wireValue;

  static ProfileKind? parse(Object? value) => switch (value) {
        'cpu' => ProfileKind.cpu,
        'wall' => ProfileKind.wall,
        'allocation' => ProfileKind.allocation,
        'heap' => ProfileKind.heap,
        'lock' => ProfileKind.lock,
        'blocking' => ProfileKind.blocking,
        _ => null,
      };
}

sealed class ApmDecodeResult<T> {
  const ApmDecodeResult();

  bool get isSuccess => this is ApmDecoded<T>;
}

final class ApmDecoded<T> extends ApmDecodeResult<T> {
  const ApmDecoded(this.value);
  final T value;
}

final class ApmDecodeFailure<T> extends ApmDecodeResult<T> {
  const ApmDecodeFailure(this.code);
  final String code;
}

class Attribute {
  const Attribute({required this.key, required this.value});

  final String key;
  final String value;

  static ApmDecodeResult<Attribute> decode(Map<String, Object?> json) {
    final key = _requiredString(json, 'key');
    final value = _requiredStringAllowEmpty(json, 'value');
    if (key == null || value == null) {
      return const ApmDecodeFailure('invalid_apm_attribute');
    }
    return ApmDecoded(Attribute(key: key, value: value));
  }
}

class Exemplar {
  const Exemplar({
    required this.traceId,
    required this.spanId,
    required this.value,
    required this.timestampUnixNano,
  });

  final String traceId;
  final String spanId;
  final double value;
  final String timestampUnixNano;

  static ApmDecodeResult<Exemplar> decode(Map<String, Object?> json) {
    final traceId = _requiredString(json, 'trace_id');
    final spanId = _requiredString(json, 'span_id');
    final value = _requiredFiniteNumber(json, 'value');
    final timestamp = _requiredString(json, 'timestamp_unix_nano');
    if (traceId == null || spanId == null || value == null || timestamp == null) {
      return const ApmDecodeFailure('invalid_apm_exemplar');
    }
    return ApmDecoded(Exemplar(
      traceId: traceId,
      spanId: spanId,
      value: value,
      timestampUnixNano: timestamp,
    ));
  }
}

class HistogramBucket {
  const HistogramBucket({required this.upperBound, required this.count});

  final double upperBound;
  final String count;

  static ApmDecodeResult<HistogramBucket> decode(Map<String, Object?> json) {
    final upperBound = _requiredFiniteNumber(json, 'upper_bound');
    final count = _requiredString(json, 'count');
    if (upperBound == null || count == null) {
      return const ApmDecodeFailure('invalid_apm_histogram_bucket');
    }
    return ApmDecoded(HistogramBucket(upperBound: upperBound, count: count));
  }
}

class HistogramPoint {
  HistogramPoint({
    required this.count,
    required this.sum,
    required List<HistogramBucket> buckets,
    required List<Exemplar> exemplars,
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

  static ApmDecodeResult<HistogramPoint> decode(Map<String, Object?> json) {
    final count = _requiredString(json, 'count');
    final sum = _requiredFiniteNumber(json, 'sum');
    final min = _optionalFiniteNumber(json, 'min');
    final max = _optionalFiniteNumber(json, 'max');
    final bucketMaps = _requiredMapList(json, 'buckets');
    final exemplarMaps = _optionalMapList(json, 'exemplars');
    if (count == null ||
        sum == null ||
        !min.$1 ||
        !max.$1 ||
        bucketMaps == null ||
        !exemplarMaps.$1) {
      return const ApmDecodeFailure('invalid_apm_histogram');
    }
    final buckets = _decodeList(bucketMaps, HistogramBucket.decode);
    if (buckets is ApmDecodeFailure<List<HistogramBucket>>) return buckets;
    final exemplars = _decodeList(exemplarMaps.$2, Exemplar.decode);
    if (exemplars is ApmDecodeFailure<List<Exemplar>>) return exemplars;
    return ApmDecoded(HistogramPoint(
      count: count,
      sum: sum,
      min: min.$2,
      max: max.$2,
      buckets: (buckets as ApmDecoded<List<HistogramBucket>>).value,
      exemplars: (exemplars as ApmDecoded<List<Exemplar>>).value,
    ));
  }
}

class MetricPoint {
  MetricPoint({
    required this.name,
    required this.unit,
    required this.kind,
    required this.timestampUnixNano,
    required List<Attribute> attributes,
    this.value,
    this.histogram,
  }) : attributes = List.unmodifiable(attributes);

  final String name;
  final String unit;
  final MetricKind kind;
  final String timestampUnixNano;
  final double? value;
  final HistogramPoint? histogram;
  final List<Attribute> attributes;

  static ApmDecodeResult<MetricPoint> decode(Map<String, Object?> json) {
    final name = _requiredString(json, 'name');
    final unit = _requiredString(json, 'unit');
    final kind = MetricKind.parse(json['kind']);
    final timestamp = _requiredString(json, 'timestamp_unix_nano');
    final value = _optionalFiniteNumber(json, 'value');
    final attributeMaps = _optionalMapList(json, 'attributes');
    if (name == null ||
        unit == null ||
        kind == null ||
        timestamp == null ||
        !value.$1 ||
        !attributeMaps.$1) {
      return const ApmDecodeFailure('invalid_apm_metric');
    }

    HistogramPoint? histogram;
    if (json['histogram'] != null) {
      final histogramMap = _mapValue(json['histogram']);
      if (histogramMap == null) {
        return const ApmDecodeFailure('invalid_apm_metric_histogram');
      }
      final decodedHistogram = HistogramPoint.decode(histogramMap);
      if (decodedHistogram is ApmDecodeFailure<HistogramPoint>) {
        return ApmDecodeFailure(decodedHistogram.code);
      }
      histogram = (decodedHistogram as ApmDecoded<HistogramPoint>).value;
    }

    final attributes = _decodeList(attributeMaps.$2, Attribute.decode);
    if (attributes is ApmDecodeFailure<List<Attribute>>) return attributes;
    return ApmDecoded(MetricPoint(
      name: name,
      unit: unit,
      kind: kind,
      timestampUnixNano: timestamp,
      value: value.$2,
      histogram: histogram,
      attributes: (attributes as ApmDecoded<List<Attribute>>).value,
    ));
  }
}

class ProcessSnapshot {
  const ProcessSnapshot({
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

  static ApmDecodeResult<ProcessSnapshot> decode(Map<String, Object?> json) {
    final cpuTime = _requiredFiniteNumber(json, 'cpu_time_seconds');
    final cpuUtilization = _requiredFiniteNumber(json, 'cpu_utilization');
    final memoryUsage = _requiredString(json, 'memory_usage_bytes');
    final memoryVirtual = _requiredString(json, 'memory_virtual_bytes');
    final memoryUtilization = _optionalFiniteNumber(json, 'memory_utilization');
    final diskRead = _requiredString(json, 'disk_read_bytes');
    final diskWrite = _requiredString(json, 'disk_write_bytes');
    final diskReadOps = _optionalString(json, 'disk_read_operations');
    final diskWriteOps = _optionalString(json, 'disk_write_operations');
    final networkReceive = _optionalString(json, 'network_receive_bytes');
    final networkTransmit = _optionalString(json, 'network_transmit_bytes');
    final threadCount = _optionalString(json, 'thread_count');
    final fdCount = _optionalString(json, 'file_descriptor_count');
    final handleCount = _optionalString(json, 'handle_count');
    final contextSwitches = _optionalString(json, 'context_switches');
    final pagingFaults = _optionalString(json, 'paging_faults');
    final uptime = _requiredFiniteNumber(json, 'uptime_seconds');
    final optionalsValid = memoryUtilization.$1 &&
        diskReadOps.$1 &&
        diskWriteOps.$1 &&
        networkReceive.$1 &&
        networkTransmit.$1 &&
        threadCount.$1 &&
        fdCount.$1 &&
        handleCount.$1 &&
        contextSwitches.$1 &&
        pagingFaults.$1;
    if (cpuTime == null ||
        cpuUtilization == null ||
        memoryUsage == null ||
        memoryVirtual == null ||
        diskRead == null ||
        diskWrite == null ||
        uptime == null ||
        !optionalsValid) {
      return const ApmDecodeFailure('invalid_apm_process');
    }
    return ApmDecoded(ProcessSnapshot(
      cpuTimeSeconds: cpuTime,
      cpuUtilization: cpuUtilization,
      memoryUsageBytes: memoryUsage,
      memoryVirtualBytes: memoryVirtual,
      memoryUtilization: memoryUtilization.$2,
      diskReadBytes: diskRead,
      diskWriteBytes: diskWrite,
      diskReadOperations: diskReadOps.$2,
      diskWriteOperations: diskWriteOps.$2,
      networkReceiveBytes: networkReceive.$2,
      networkTransmitBytes: networkTransmit.$2,
      threadCount: threadCount.$2,
      fileDescriptorCount: fdCount.$2,
      handleCount: handleCount.$2,
      contextSwitches: contextSwitches.$2,
      pagingFaults: pagingFaults.$2,
      uptimeSeconds: uptime,
    ));
  }
}

class FilesystemSnapshot {
  const FilesystemSnapshot({
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

  static ApmDecodeResult<FilesystemSnapshot> decode(Map<String, Object?> json) {
    final target = _requiredString(json, 'target');
    final total = _requiredString(json, 'total_bytes');
    final used = _requiredString(json, 'used_bytes');
    final free = _requiredString(json, 'free_bytes');
    final available = _requiredString(json, 'available_bytes');
    final utilization = _requiredFiniteNumber(json, 'utilization');
    final filesTotal = _optionalString(json, 'files_total');
    final filesFree = _optionalString(json, 'files_free');
    final readOnly = _optionalBool(json, 'read_only');
    if (target == null ||
        total == null ||
        used == null ||
        free == null ||
        available == null ||
        utilization == null ||
        !filesTotal.$1 ||
        !filesFree.$1 ||
        !readOnly.$1) {
      return const ApmDecodeFailure('invalid_apm_filesystem');
    }
    return ApmDecoded(FilesystemSnapshot(
      target: target,
      totalBytes: total,
      usedBytes: used,
      freeBytes: free,
      availableBytes: available,
      utilization: utilization,
      filesTotal: filesTotal.$2,
      filesFree: filesFree.$2,
      readOnly: readOnly.$2,
    ));
  }
}

class RuntimeMetric {
  RuntimeMetric({
    required this.runtimeNamespace,
    required this.name,
    required this.unit,
    required this.value,
    required List<Attribute> attributes,
  }) : attributes = List.unmodifiable(attributes);

  final String runtimeNamespace;
  final String name;
  final String unit;
  final double value;
  final List<Attribute> attributes;

  static ApmDecodeResult<RuntimeMetric> decode(Map<String, Object?> json) {
    final namespace = _requiredString(json, 'runtime_namespace');
    final name = _requiredString(json, 'name');
    final unit = _requiredString(json, 'unit');
    final value = _requiredFiniteNumber(json, 'value');
    final attributeMaps = _optionalMapList(json, 'attributes');
    if (namespace == null || name == null || unit == null || value == null || !attributeMaps.$1) {
      return const ApmDecodeFailure('invalid_apm_runtime_metric');
    }
    final attributes = _decodeList(attributeMaps.$2, Attribute.decode);
    if (attributes is ApmDecodeFailure<List<Attribute>>) return attributes;
    return ApmDecoded(RuntimeMetric(
      runtimeNamespace: namespace,
      name: name,
      unit: unit,
      value: value,
      attributes: (attributes as ApmDecoded<List<Attribute>>).value,
    ));
  }
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

  static ApmDecodeResult<RuntimeSnapshot> decode(Map<String, Object?> json) {
    final name = _requiredString(json, 'runtime_name');
    final version = _optionalString(json, 'runtime_version');
    final metricMaps = _requiredMapList(json, 'metrics');
    if (name == null || !version.$1 || metricMaps == null) {
      return const ApmDecodeFailure('invalid_apm_runtime');
    }
    final metrics = _decodeList(metricMaps, RuntimeMetric.decode);
    if (metrics is ApmDecodeFailure<List<RuntimeMetric>>) return metrics;
    return ApmDecoded(RuntimeSnapshot(
      runtimeName: name,
      runtimeVersion: version.$2,
      metrics: (metrics as ApmDecoded<List<RuntimeMetric>>).value,
    ));
  }
}

class ServicePerformanceSnapshot {
  const ServicePerformanceSnapshot({
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

  static ApmDecodeResult<ServicePerformanceSnapshot> decode(Map<String, Object?> json) {
    final requestCount = _requiredString(json, 'request_count');
    final errorCount = _requiredString(json, 'error_count');
    final activeRequests = _requiredString(json, 'active_requests');
    final latencyMap = _mapValue(json['latency_seconds']);
    final saturation = _optionalFiniteNumber(json, 'saturation_ratio');
    if (requestCount == null ||
        errorCount == null ||
        activeRequests == null ||
        latencyMap == null ||
        !saturation.$1) {
      return const ApmDecodeFailure('invalid_apm_service');
    }
    final latency = HistogramPoint.decode(latencyMap);
    if (latency is ApmDecodeFailure<HistogramPoint>) return ApmDecodeFailure(latency.code);
    return ApmDecoded(ServicePerformanceSnapshot(
      requestCount: requestCount,
      errorCount: errorCount,
      activeRequests: activeRequests,
      latencySeconds: (latency as ApmDecoded<HistogramPoint>).value,
      saturationRatio: saturation.$2,
    ));
  }
}

class ProfileCapability {
  const ProfileCapability({required this.kind, required this.status});

  final ProfileKind kind;
  final ApmCapabilityStatus status;

  static ApmDecodeResult<ProfileCapability> decode(Map<String, Object?> json) {
    final kind = ProfileKind.parse(json['kind']);
    final status = ApmCapabilityStatus.parse(json['status']);
    return kind == null || status == null
        ? const ApmDecodeFailure('invalid_apm_profile_capability')
        : ApmDecoded(ProfileCapability(kind: kind, status: status));
  }
}

class ProfileSummary {
  const ProfileSummary({
    required this.profileId,
    required this.kind,
    required this.startUnixNano,
    required this.endUnixNano,
    required this.sampleCount,
    required this.droppedSampleCount,
    required this.format,
  });

  final String profileId;
  final ProfileKind kind;
  final String startUnixNano;
  final String endUnixNano;
  final String sampleCount;
  final String droppedSampleCount;
  final String format;

  static ApmDecodeResult<ProfileSummary> decode(Map<String, Object?> json) {
    final profileId = _requiredString(json, 'profile_id');
    final kind = ProfileKind.parse(json['kind']);
    final start = _requiredString(json, 'start_unix_nano');
    final end = _requiredString(json, 'end_unix_nano');
    final sampleCount = _requiredString(json, 'sample_count');
    final dropped = _requiredString(json, 'dropped_sample_count');
    final format = _requiredString(json, 'format');
    if (profileId == null ||
        kind == null ||
        start == null ||
        end == null ||
        sampleCount == null ||
        dropped == null ||
        format == null) {
      return const ApmDecodeFailure('invalid_apm_profile');
    }
    return ApmDecoded(ProfileSummary(
      profileId: profileId,
      kind: kind,
      startUnixNano: start,
      endUnixNano: end,
      sampleCount: sampleCount,
      droppedSampleCount: dropped,
      format: format,
    ));
  }
}

class CorrelationContext {
  const CorrelationContext({this.traceId, this.spanId, this.traceFlags});

  final String? traceId;
  final String? spanId;
  final int? traceFlags;

  static ApmDecodeResult<CorrelationContext> decode(Map<String, Object?> json) {
    final traceId = _optionalString(json, 'trace_id');
    final spanId = _optionalString(json, 'span_id');
    final traceFlags = _optionalInt(json, 'trace_flags');
    if (!traceId.$1 || !spanId.$1 || !traceFlags.$1) {
      return const ApmDecodeFailure('invalid_apm_correlation');
    }
    return ApmDecoded(CorrelationContext(
      traceId: traceId.$2,
      spanId: spanId.$2,
      traceFlags: traceFlags.$2,
    ));
  }
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

  final ApmCapabilityStatus processMetrics;
  final ApmCapabilityStatus filesystemMetrics;
  final ApmCapabilityStatus runtimeMetrics;
  final ApmCapabilityStatus latencyHistograms;
  final ApmCapabilityStatus exemplars;
  final ApmCapabilityStatus traceCorrelation;
  final ApmCapabilityStatus logCorrelation;
  final ApmCapabilityStatus metricsExport;
  final ApmCapabilityStatus tracesExport;
  final ApmCapabilityStatus logsExport;
  final ApmCapabilityStatus profilesExport;
  final ApmCapabilityStatus errorTracking;
  final ApmCapabilityStatus serviceTopology;
  final ApmCapabilityStatus sloInputs;
  final List<ProfileCapability> profiling;

  static ApmDecodeResult<ApmCapabilitySet> decode(Map<String, Object?> json) {
    final process = ApmCapabilityStatus.parse(json['process_metrics']);
    final filesystem = ApmCapabilityStatus.parse(json['filesystem_metrics']);
    final runtime = ApmCapabilityStatus.parse(json['runtime_metrics']);
    final latency = ApmCapabilityStatus.parse(json['latency_histograms']);
    final exemplars = ApmCapabilityStatus.parse(json['exemplars']);
    final trace = ApmCapabilityStatus.parse(json['trace_correlation']);
    final log = ApmCapabilityStatus.parse(json['log_correlation']);
    final metrics = ApmCapabilityStatus.parse(json['metrics_export']);
    final traces = ApmCapabilityStatus.parse(json['traces_export']);
    final logs = ApmCapabilityStatus.parse(json['logs_export']);
    final profiles = ApmCapabilityStatus.parse(json['profiles_export']);
    final errorTracking = ApmCapabilityStatus.parse(json['error_tracking']);
    final topology = ApmCapabilityStatus.parse(json['service_topology']);
    final slo = ApmCapabilityStatus.parse(json['slo_inputs']);
    final profileMaps = _requiredMapList(json, 'profiling');
    if ([
          process,
          filesystem,
          runtime,
          latency,
          exemplars,
          trace,
          log,
          metrics,
          traces,
          logs,
          profiles,
          errorTracking,
          topology,
          slo,
        ].any((value) => value == null) ||
        profileMaps == null) {
      return const ApmDecodeFailure('invalid_apm_capabilities');
    }
    final profiling = _decodeList(profileMaps, ProfileCapability.decode);
    if (profiling is ApmDecodeFailure<List<ProfileCapability>>) return profiling;
    return ApmDecoded(ApmCapabilitySet(
      processMetrics: process!,
      filesystemMetrics: filesystem!,
      runtimeMetrics: runtime!,
      latencyHistograms: latency!,
      exemplars: exemplars!,
      traceCorrelation: trace!,
      logCorrelation: log!,
      metricsExport: metrics!,
      tracesExport: traces!,
      logsExport: logs!,
      profilesExport: profiles!,
      errorTracking: errorTracking!,
      serviceTopology: topology!,
      sloInputs: slo!,
      profiling: (profiling as ApmDecoded<List<ProfileCapability>>).value,
    ));
  }
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
    required List<ProfileSummary> profiles,
    required List<MetricPoint> metrics,
    this.runtime,
    this.correlation,
  })  : filesystems = List.unmodifiable(filesystems),
        profiles = List.unmodifiable(profiles),
        metrics = List.unmodifiable(metrics);

  final int schemaVersion;
  final String observedAtUnixNano;
  final String serviceName;
  final String serviceInstanceId;
  final ProcessSnapshot process;
  final List<FilesystemSnapshot> filesystems;
  final RuntimeSnapshot? runtime;
  final ServicePerformanceSnapshot service;
  final CorrelationContext? correlation;
  final List<ProfileSummary> profiles;
  final ApmCapabilitySet capabilities;
  final List<MetricPoint> metrics;

  static ApmDecodeResult<ApmSnapshot> decode(Map<String, Object?> json) {
    if (json['schema_version'] != 1) {
      return const ApmDecodeFailure('invalid_apm_schema_version');
    }
    final observedAt = _requiredString(json, 'observed_at_unix_nano');
    final serviceName = _requiredString(json, 'service_name');
    final serviceInstanceId = _requiredString(json, 'service_instance_id');
    final processMap = _mapValue(json['process']);
    final filesystemMaps = _requiredMapList(json, 'filesystems');
    final serviceMap = _mapValue(json['service']);
    final capabilityMap = _mapValue(json['capabilities']);
    final profileMaps = _optionalMapList(json, 'profiles');
    final metricMaps = _optionalMapList(json, 'metrics');
    if (observedAt == null ||
        serviceName == null ||
        serviceInstanceId == null ||
        processMap == null ||
        filesystemMaps == null ||
        serviceMap == null ||
        capabilityMap == null ||
        !profileMaps.$1 ||
        !metricMaps.$1) {
      return const ApmDecodeFailure('invalid_apm_snapshot');
    }

    final process = ProcessSnapshot.decode(processMap);
    if (process is ApmDecodeFailure<ProcessSnapshot>) return ApmDecodeFailure(process.code);
    final filesystems = _decodeList(filesystemMaps, FilesystemSnapshot.decode);
    if (filesystems is ApmDecodeFailure<List<FilesystemSnapshot>>) return filesystems;
    final service = ServicePerformanceSnapshot.decode(serviceMap);
    if (service is ApmDecodeFailure<ServicePerformanceSnapshot>) return ApmDecodeFailure(service.code);
    final capabilities = ApmCapabilitySet.decode(capabilityMap);
    if (capabilities is ApmDecodeFailure<ApmCapabilitySet>) return ApmDecodeFailure(capabilities.code);
    final profiles = _decodeList(profileMaps.$2, ProfileSummary.decode);
    if (profiles is ApmDecodeFailure<List<ProfileSummary>>) return profiles;
    final metrics = _decodeList(metricMaps.$2, MetricPoint.decode);
    if (metrics is ApmDecodeFailure<List<MetricPoint>>) return metrics;

    RuntimeSnapshot? runtime;
    if (json['runtime'] != null) {
      final runtimeMap = _mapValue(json['runtime']);
      if (runtimeMap == null) return const ApmDecodeFailure('invalid_apm_runtime');
      final decodedRuntime = RuntimeSnapshot.decode(runtimeMap);
      if (decodedRuntime is ApmDecodeFailure<RuntimeSnapshot>) {
        return ApmDecodeFailure(decodedRuntime.code);
      }
      runtime = (decodedRuntime as ApmDecoded<RuntimeSnapshot>).value;
    }

    CorrelationContext? correlation;
    if (json['correlation'] != null) {
      final correlationMap = _mapValue(json['correlation']);
      if (correlationMap == null) return const ApmDecodeFailure('invalid_apm_correlation');
      final decodedCorrelation = CorrelationContext.decode(correlationMap);
      if (decodedCorrelation is ApmDecodeFailure<CorrelationContext>) {
        return ApmDecodeFailure(decodedCorrelation.code);
      }
      correlation = (decodedCorrelation as ApmDecoded<CorrelationContext>).value;
    }

    return ApmDecoded(ApmSnapshot(
      schemaVersion: 1,
      observedAtUnixNano: observedAt,
      serviceName: serviceName,
      serviceInstanceId: serviceInstanceId,
      process: (process as ApmDecoded<ProcessSnapshot>).value,
      filesystems: (filesystems as ApmDecoded<List<FilesystemSnapshot>>).value,
      runtime: runtime,
      service: (service as ApmDecoded<ServicePerformanceSnapshot>).value,
      correlation: correlation,
      profiles: (profiles as ApmDecoded<List<ProfileSummary>>).value,
      capabilities: (capabilities as ApmDecoded<ApmCapabilitySet>).value,
      metrics: (metrics as ApmDecoded<List<MetricPoint>>).value,
    ));
  }
}

ApmDecodeResult<List<T>> _decodeList<T>(
  List<Map<String, Object?>> values,
  ApmDecodeResult<T> Function(Map<String, Object?>) decode,
) {
  final output = <T>[];
  for (final value in values) {
    final decoded = decode(value);
    if (decoded is ApmDecodeFailure<T>) return ApmDecodeFailure(decoded.code);
    output.add((decoded as ApmDecoded<T>).value);
  }
  return ApmDecoded(List.unmodifiable(output));
}

Map<String, Object?>? _mapValue(Object? value) {
  if (value is! Map) return null;
  final entries = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    entries[entry.key as String] = entry.value;
  }
  return Map.unmodifiable(entries);
}

List<Map<String, Object?>>? _requiredMapList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) return null;
  final maps = <Map<String, Object?>>[];
  for (final item in value) {
    final map = _mapValue(item);
    if (map == null) return null;
    maps.add(map);
  }
  return List.unmodifiable(maps);
}

(bool, List<Map<String, Object?>>) _optionalMapList(
  Map<String, Object?> json,
  String key,
) {
  if (!json.containsKey(key) || json[key] == null) return (true, const []);
  final values = _requiredMapList(json, key);
  return values == null ? (false, const []) : (true, values);
}

String? _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

String? _requiredStringAllowEmpty(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

(bool, String?) _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (!json.containsKey(key) || value == null) return (true, null);
  return value is String ? (true, value) : (false, null);
}

double? _requiredFiniteNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) return null;
  final converted = value.toDouble();
  return converted.isFinite ? converted : null;
}

(bool, double?) _optionalFiniteNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (!json.containsKey(key) || value == null) return (true, null);
  if (value is! num) return (false, null);
  final converted = value.toDouble();
  return converted.isFinite ? (true, converted) : (false, null);
}

(bool, bool?) _optionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (!json.containsKey(key) || value == null) return (true, null);
  return value is bool ? (true, value) : (false, null);
}

(bool, int?) _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (!json.containsKey(key) || value == null) return (true, null);
  return value is int ? (true, value) : (false, null);
}
