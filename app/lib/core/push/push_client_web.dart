import 'dart:convert';
import 'dart:js_interop';

import 'push_client.dart';

@JS('loveSpacePush.status')
external JSPromise<JSString> _pushStatus();

@JS('loveSpacePush.subscribe')
external JSPromise<JSString> _subscribe(JSString vapidPublicKey);

PushClient platformPushClient() => WebPushClient();

class WebPushClient implements PushClient {
  static const _vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');

  @override
  Stream<String> get deepLinks => const Stream.empty();

  @override
  Future<void> startIfConsented() async {}

  @override
  Future<PushStatus> status() async {
    final json =
        jsonDecode((await _pushStatus().toDart).toDart) as Map<String, dynamic>;
    return PushStatus(
      supported: json['supported'] as bool? ?? false,
      enabled: json['permission'] == 'granted',
      installed: json['installed'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  @override
  Future<PushRegistration> enable() async {
    if (_vapidPublicKey.isEmpty) throw StateError('构建未注入 VAPID_PUBLIC_KEY');
    final json =
        jsonDecode((await _subscribe(_vapidPublicKey.toJS).toDart).toDart)
            as Map<String, dynamic>;
    return PushRegistration(
      deviceId: json['deviceId'] as String,
      platform: 'web',
      provider: 'webpush',
      endpoint: json['endpoint'] as String,
      publicKey: json['publicKey'] as String,
      authSecret: json['authSecret'] as String,
    );
  }
}
