import 'package:rxdart/rxdart.dart';

import 'models.dart';

/// Last-known [Health] at the client effect boundary.
///
/// [Client.decodeHealth] stays a pure in/out transform. Callers that need to
/// observe health without a module-level cache publish into this subject.
/// Duplicate values are collapsed with [distinct].
class HealthSnapshots {
  HealthSnapshots({
    this.seed = const Health(ok: false, service: 'ores-otel'),
  }) : _subject = BehaviorSubject.seeded(seed);

  final Health seed;
  final BehaviorSubject<Health> _subject;

  Stream<Health> get snapshots => _subject.stream.distinct();

  Health get value => _subject.value;

  void publish(Health next) => _subject.add(next);

  void close() => _subject.close();
}
