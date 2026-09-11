import 'dart:io';
import 'dart:typed_data';

import 'package:ores_otel_client/ores_otel_client.dart';
import 'package:test/test.dart';

void main() {
  test('canonical APM fixture decodes into immutable owned models', () {
    final fixture = Platform.environment['ORES_APM_FIXTURE'];
    expect(fixture, isNotNull, reason: 'ORES_APM_FIXTURE must point to the pinned fixture');

    final body = Uint8List.fromList(File(fixture!).readAsBytesSync());
    final client = Client(const ClientConfig(
      baseUrl: 'https://example.invalid',
      maxResponseBytes: 2 * 1024 * 1024,
    ));
    final snapshot = client.decodeApmSnapshot(body);

    expect(snapshot.schemaVersion, 1);
    expect(snapshot.serviceName, isNotEmpty);
    expect(snapshot.serviceInstanceId, isNotEmpty);
    expect(snapshot.process.memoryUsageBytes, isNotEmpty);
    expect(snapshot.process.diskReadBytes, isNotEmpty);
    expect(snapshot.filesystems, isNotEmpty);
    expect(snapshot.service.latencySeconds.buckets, isNotEmpty);
    expect(snapshot.capabilities.profiling, isNotEmpty);
    expect(() => snapshot.filesystems.add(snapshot.filesystems.first), throwsUnsupportedError);
    expect(() => snapshot.capabilities.profiling.clear(), throwsUnsupportedError);
  });
}
