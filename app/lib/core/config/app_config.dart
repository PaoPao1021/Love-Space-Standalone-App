import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return _configuredApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    return kIsWeb ? '' : 'http://10.0.2.2:8080';
  }
}
