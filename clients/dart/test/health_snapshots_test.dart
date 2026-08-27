import 'dart:convert';
import 'dart:typed_data';

import 'package:ores_otel_client/ores_otel_client.dart';
import 'package:ores_otel_client/ores_otel_health_snapshots.dart';
import 'package:test/test.dart';

void main() {
  test('decodeHealth is a pure in/out transform', () {
    final client = Client(const ClientConfig(baseUrl: 'https://otel.example'));
    final body = Uint8List.fromList(
      utf8.encode('{"ok":true,"service":"ores-otel"}'),
    );

    expect(
      client.decodeHealth(body),
      const Health(ok: true, service: 'ores-otel'),
    );
    expect(
      client.decodeHealth(body),
      const Health(ok: true, service: 'ores-otel'),
    );
  });

  test('duplicate Health snapshots collapse', () async {
    const seed = Health(ok: false, service: 'ores-otel');
    final bus = HealthSnapshots(seed: seed);
    final seen = <Health>[];
    final sub = bus.snapshots.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    bus.publish(seed);
    bus.publish(const Health(ok: false, service: 'ores-otel'));
    bus.publish(const Health(ok: true, service: 'ores-otel'));
    await Future<void>.delayed(Duration.zero);

    expect(seen, const [
      seed,
      Health(ok: true, service: 'ores-otel'),
    ]);
    await sub.cancel();
    bus.close();
  });
}
