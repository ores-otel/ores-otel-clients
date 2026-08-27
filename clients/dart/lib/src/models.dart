class Health {
  const Health({required this.ok, required this.service});
  final bool ok;
  final String service;

  @override
  bool operator ==(Object other) =>
      other is Health && ok == other.ok && service == other.service;

  @override
  int get hashCode => Object.hash(ok, service);
}

class ResourceEnvelope {
  const ResourceEnvelope(
      {required this.id, required this.revision, required this.payload});
  final String id;
  final String revision;
  final Map<String, Object?> payload;
  static const resource = 'TelemetryRecord';
}
