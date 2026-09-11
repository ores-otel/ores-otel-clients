import 'dart:convert';
import 'dart:typed_data';

import 'apm.dart';
import 'config.dart';
import 'errors.dart';
import 'models.dart';

class Client {
  Client(this.config) {
    if (config.baseUrl.trim().isEmpty) {
      throw const ClientException('invalid_base');
    }
  }

  final ClientConfig config;

  String healthUrl() => '${config.baseUrl.replaceAll(RegExp(r'/$'), '')}/v1/health';

  Health decodeHealth(Uint8List body) {
    final decoded = _decodeBoundedJson(body);
    return Health(ok: decoded['ok'] == true, service: '${decoded['service']}');
  }

  /// Decode an ORES APM snapshot obtained through caller-owned transport.
  /// The serialized contract intentionally does not define an HTTP route.
  ApmSnapshot decodeApmSnapshot(Uint8List body) =>
      ApmSnapshot.fromJson(_decodeBoundedJson(body));

  Map<String, Object?> _decodeBoundedJson(Uint8List body) {
    if (body.length > config.maxResponseBytes) {
      throw const ClientException('too_large');
    }
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map<String, Object?>) {
      throw const ClientException('invalid_json');
    }
    // Copy the parsed map so the decoder never exposes the parser's mutable
    // root object directly to higher-level model constructors.
    return Map<String, Object?>.from(decoded);
  }
}
