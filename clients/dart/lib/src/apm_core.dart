part of 'apm.dart';

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
    return ApmDecoded(
      Exemplar(
        traceId: traceId,
        spanId: spanId,
        value: value,
        timestampUnixNano: timestamp,
      ),
    );
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
    if (buckets is ApmDecodeFailure<List<HistogramBucket>>) {
      return buckets;
    }
    final exemplars = _decodeList(exemplarMaps.$2, Exemplar.decode);
    if (exemplars is ApmDecodeFailure<List<Exemplar>>) {
      return exemplars;
    }
    return ApmDecoded(
      HistogramPoint(
        count: count,
        sum: sum,
        min: min.$2,
        max: max.$2,
        buckets: (buckets as ApmDecoded<List<HistogramBucket>>).value,
        exemplars: (exemplars as ApmDecoded<List<Exemplar>>).value,
      ),
    );
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
    final histogram = _decodeOptionalHistogram(json);
    if (name == null ||
        unit == null ||
        kind == null ||
        timestamp == null ||
        !value.$1 ||
        !attributeMaps.$1 ||
        histogram is ApmDecodeFailure<HistogramPoint?>) {
      return ApmDecodeFailure(
        histogram is ApmDecodeFailure<HistogramPoint?>
            ? histogram.code
            : 'invalid_apm_metric',
      );
    }

    final attributes = _decodeList(attributeMaps.$2, Attribute.decode);
    if (attributes is ApmDecodeFailure<List<Attribute>>) {
      return attributes;
    }
    return ApmDecoded(
      MetricPoint(
        name: name,
        unit: unit,
        kind: kind,
        timestampUnixNano: timestamp,
        value: value.$2,
        histogram: (histogram as ApmDecoded<HistogramPoint?>).value,
        attributes: (attributes as ApmDecoded<List<Attribute>>).value,
      ),
    );
  }
}

ApmDecodeResult<HistogramPoint?> _decodeOptionalHistogram(
  Map<String, Object?> json,
) {
  if (!json.containsKey('histogram')) {
    return const ApmDecoded(null);
  }
  final histogramMap = _mapValue(json['histogram']);
  if (histogramMap == null) {
    return const ApmDecodeFailure('invalid_apm_metric_histogram');
  }
  final decoded = HistogramPoint.decode(histogramMap);
  return switch (decoded) {
    ApmDecoded<HistogramPoint>(value: final value) => ApmDecoded(value),
    ApmDecodeFailure<HistogramPoint>(code: final code) => ApmDecodeFailure(code),
  };
}

ApmDecodeResult<List<T>> _decodeList<T>(
  List<Map<String, Object?>> values,
  ApmDecodeResult<T> Function(Map<String, Object?>) decode,
) {
  final decoded = values.map(decode).toList(growable: false);
  for (final result in decoded) {
    if (result is ApmDecodeFailure<T>) {
      return ApmDecodeFailure(result.code);
    }
  }
  return ApmDecoded(
    List.unmodifiable(
      decoded.cast<ApmDecoded<T>>().map((result) => result.value),
    ),
  );
}

Map<String, Object?>? _mapValue(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    return null;
  }
  return Map.unmodifiable(
    value.map((key, nested) => MapEntry(key as String, nested)),
  );
}

List<Map<String, Object?>>? _requiredMapList(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    return null;
  }
  final maps = value.map(_mapValue).toList(growable: false);
  if (maps.any((map) => map == null)) {
    return null;
  }
  return List.unmodifiable(maps.cast<Map<String, Object?>>());
}

(bool, List<Map<String, Object?>>) _optionalMapList(
  Map<String, Object?> json,
  String key,
) {
  if (!json.containsKey(key)) {
    return (true, const []);
  }
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
  if (!json.containsKey(key)) {
    return (true, null);
  }
  final value = json[key];
  return value is String ? (true, value) : (false, null);
}

double? _requiredFiniteNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    return null;
  }
  final converted = value.toDouble();
  return converted.isFinite ? converted : null;
}

(bool, double?) _optionalFiniteNumber(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    return (true, null);
  }
  final value = json[key];
  if (value is! num) {
    return (false, null);
  }
  final converted = value.toDouble();
  return converted.isFinite ? (true, converted) : (false, null);
}

(bool, bool?) _optionalBool(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    return (true, null);
  }
  final value = json[key];
  return value is bool ? (true, value) : (false, null);
}

(bool, int?) _optionalInt(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    return (true, null);
  }
  final value = json[key];
  return value is int ? (true, value) : (false, null);
}
