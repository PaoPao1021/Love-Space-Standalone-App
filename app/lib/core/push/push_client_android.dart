import 'dart:async';

import 'package:getuiflut/getuiflut.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_client.dart';

PushClient platformPushClient() => AndroidPushClient();

class AndroidPushClient implements PushClient {
  static const _consentKey = 'push.getui.privacy-consented';
  final Getuiflut _sdk = Getuiflut();
  final StreamController<String> _deepLinks = StreamController.broadcast();
  bool _initialized = false;
  bool _handlersAdded = false;

  @override
  Stream<String> get deepLinks => _deepLinks.stream;

  @override
  Future<void> startIfConsented() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_consentKey) == true) _initialize();
  }

  @override
  Future<PushStatus> status() async {
    await startIfConsented();
    final permission = await Permission.notification.status;
    return PushStatus(
      supported: true,
      enabled: permission.isGranted && _initialized,
      installed: true,
      message: permission.isPermanentlyDenied
          ? '通知权限已被拒绝，请在系统设置中开启'
          : _initialized
          ? '个推已登记；最终送达仍受 ColorOS 后台策略影响'
          : '尚未开启通知',
    );
  }

  @override
  Future<PushRegistration> enable() async {
    final permission = await Permission.notification.request();
    if (!permission.isGranted) {
      throw StateError('请先允许 LoveSpace 发送通知');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_consentKey, true);
    _initialize();
    final cid = Completer<String>();
    _sdk.addEventHandler(
      onReceiveClientId: (value) async {
        if (!cid.isCompleted && value.isNotEmpty) cid.complete(value);
      },
      onNotificationMessageArrived: (_) async {},
      onNotificationMessageClicked: (message) async {
        _emitDeepLink(message);
      },
      onTransmitUserMessageReceive: (_) async {},
      onReceiveOnlineState: (_) async {},
      onRegisterDeviceToken: (_) async {},
      onReceivePayload: (message) async {
        _emitDeepLink(message);
      },
      onReceiveNotificationResponse: (_) async {},
      onAppLinkPayload: (value) async {
        _emitValue(value);
      },
      onPushModeResult: (_) async {},
      onSetTagResult: (_) async {},
      onAliasResult: (_) async {},
      onQueryTagResult: (_) async {},
      onWillPresentNotification: (_) async {},
      onOpenSettingsForNotification: (_) async {},
      onGrantAuthorization: (_) async {},
      onLiveActivityResult: (_) async {},
      onRegisterPushToStartTokenResult: (_) async {},
    );
    String value = await _sdk.getClientId;
    if (value.isEmpty) {
      value = await cid.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => '',
      );
    }
    if (value.isEmpty) throw StateError('暂时未取得个推 CID，请稍后重试');
    return PushRegistration(
      deviceId: 'android-${_safe(value)}',
      platform: 'android',
      provider: 'getui',
      endpoint: value,
    );
  }

  static String _safe(String value) {
    final safe = value.replaceAll(RegExp('[^A-Za-z0-9._:-]'), '');
    return safe.length <= 56 ? safe : safe.substring(0, 56);
  }

  void _initialize() {
    if (_initialized) return;
    _addPersistentHandlers();
    _sdk.initGetuiSdk;
    _initialized = true;
  }

  void _addPersistentHandlers() {
    if (_handlersAdded) return;
    _handlersAdded = true;
    _sdk.addEventHandler(
      onReceiveClientId: (_) async {},
      onNotificationMessageArrived: (_) async {},
      onNotificationMessageClicked: (message) async => _emitDeepLink(message),
      onTransmitUserMessageReceive: (_) async {},
      onReceiveOnlineState: (_) async {},
      onRegisterDeviceToken: (_) async {},
      onReceivePayload: (message) async => _emitDeepLink(message),
      onReceiveNotificationResponse: (_) async {},
      onAppLinkPayload: (value) async => _emitValue(value),
      onPushModeResult: (_) async {},
      onSetTagResult: (_) async {},
      onAliasResult: (_) async {},
      onQueryTagResult: (_) async {},
      onWillPresentNotification: (_) async {},
      onOpenSettingsForNotification: (_) async {},
      onGrantAuthorization: (_) async {},
      onLiveActivityResult: (_) async {},
      onRegisterPushToStartTokenResult: (_) async {},
    );
  }

  void _emitDeepLink(Map<String, dynamic> message) {
    for (final key in const ['payload', 'path', 'message']) {
      final value = message[key];
      if (_emitValue(value)) return;
    }
  }

  bool _emitValue(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.startsWith('/')) return false;
    _deepLinks.add(text);
    return true;
  }
}
