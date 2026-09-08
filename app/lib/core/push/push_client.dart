import 'dart:async';

import 'push_client_stub.dart'
    if (dart.library.io) 'push_client_android.dart'
    if (dart.library.js_interop) 'push_client_web.dart';

abstract interface class PushClient {
  Stream<String> get deepLinks;
  Future<void> startIfConsented();
  Future<PushStatus> status();
  Future<PushRegistration> enable();
}

class PushStatus {
  const PushStatus({
    required this.supported,
    required this.enabled,
    required this.installed,
    required this.message,
  });
  final bool supported;
  final bool enabled;
  final bool installed;
  final String message;
}

class PushRegistration {
  const PushRegistration({
    required this.deviceId,
    required this.platform,
    required this.provider,
    required this.endpoint,
    this.publicKey = '',
    this.authSecret = '',
  });
  final String deviceId;
  final String platform;
  final String provider;
  final String endpoint;
  final String publicKey;
  final String authSecret;
}

PushClient createPushClient() => platformPushClient();
