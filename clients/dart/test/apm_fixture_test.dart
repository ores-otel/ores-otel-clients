import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ores_otel_client/ores_otel_client.dart';
import 'package:test/test.dart';

void main() {
  test('canonical APM fixture decodes into deeply typed immutable models', () {
    final fixture = Platform.environment['ORES_APM_FIXTURE'];
    expect(fixture, isNotNull, reason: 'ORES_APM_FIXTURE must point to the pinned fixture');

    final body = Uint8List.fromList(File(fixture!).readAsBytesSync());
    final client = Client(const ClientConfig(
      baseUrl: 'https://example.invalid',
      maxResponseBytes: 2 * 1024 * 1024,
    ));
    final decoded = client.decodeApmSnapshot(body);

    expect(decoded, isA<ApmDecoded<ApmSnapshot>>());
    final snapshot = (decoded as ApmDecoded<ApmSnapshot>).value;
    expect(snapshot.schemaVersion, 1);
    expect(snapshot.serviceName, 'checkout-api');
    expect(snapshot.process.memoryUsageBytes, '268435456');
    expect(snapshot.process.diskReadBytes, '12582912');
    expect(snapshot.filesystems.single.target, 'data');
    expect(snapshot.runtime?.metrics.single.runtimeNamespace, 'tokio');
    expect(snapshot.service.latencySeconds.buckets, hasLength(14));
    expect(snapshot.service.latencySeconds.exemplars.single.traceId, hasLength(32));
    expect(snapshot.correlation?.traceFlags, 1);
    expect(snapshot.profiles.single.kind, ProfileKind.cpu);
    expect(snapshot.capabilities.processMetrics, ApmCapabilityStatus.native);
    expect(snapshot.capabilities.profiling, hasLength(6));
    expect(snapshot.metrics, hasLength(2));
    expect(snapshot.metrics.last.kind, MetricKind.histogram);
    expect(snapshot.metrics.last.attributes, hasLength(2));
    expect(snapshot.metrics.last.histogram?.buckets, hasLength(14));

    expect(
      () => snapshot.filesystems[0] = snapshot.filesystems.first,
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.metrics.last.attributes[0] =
          const Attribute(key: 'mutated', value: 'mutated'),
      throwsUnsupportedError,
    );
  });

  test('APM decode failures are explicit result values', () {
    final client = Client(const ClientConfig(
      baseUrl: 'https://example.invalid',
      maxResponseBytes: 1024,
    ));

    final invalidJson = client.decodeApmSnapshot(
      Uint8List.fromList(utf8.encode('{')),
    );
    expect(invalidJson, isA<ApmDecodeFailure<ApmSnapshot>>());
    expect((invalidJson as ApmDecodeFailure<ApmSnapshot>).code, 'invalid_json');

    final wrongSchema = client.decodeApmSnapshot(
      Uint8List.fromList(utf8.encode('{"schema_version":2}')),
    );
    expect(wrongSchema, isA<ApmDecodeFailure<ApmSnapshot>>());
    expect(
      (wrongSchema as ApmDecodeFailure<ApmSnapshot>).code,
      'invalid_apm_schema_version',
    );

    final bounded = Client(const ClientConfig(
      baseUrl: 'https://example.invalid',
      maxResponseBytes: 1,
    )).decodeApmSnapshot(Uint8List.fromList(utf8.encode('{}')));
    expect(bounded, isA<ApmDecodeFailure<ApmSnapshot>>());
    expect((bounded as ApmDecodeFailure<ApmSnapshot>).code, 'too_large');
  });
}
