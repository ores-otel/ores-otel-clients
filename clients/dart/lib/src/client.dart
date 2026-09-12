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
    if (body.length > config.maxResponseBytes) {
      throw const ClientException('too_large');
    }
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map<String, Object?>) {
      throw const ClientException('invalid_json');
    }
    return Health(ok: decoded['ok'] == true, service: '${decoded['service']}');
  }

  /// Decode an ORES APM snapshot obtained through caller-owned transport.
  ///
  /// The shared contract intentionally does not invent an HTTP route. New APM
  /// failures are returned as values so callers can handle them exhaustively
  /// without exception-style control flow.
  ApmDecodeResult<ApmSnapshot> decodeApmSnapshot(Uint8List body) {
    if (body.length > config.maxResponseBytes) {
      return const ApmDecodeFailure('too_large');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on FormatException {
      return const ApmDecodeFailure('invalid_json');
    }

    if (decoded is! Map) {
      return const ApmDecodeFailure('invalid_apm_root');
    }
    if (decoded.keys.any((key) => key is! String)) {
      return const ApmDecodeFailure('invalid_apm_root');
    }

    final root = Map<String, Object?>.unmodifiable(
      decoded.map((key, value) => MapEntry(key as String, value)),
    );
    return ApmSnapshot.decode(root);
  }
}
