import 'push_client.dart';

PushClient platformPushClient() => _UnsupportedPushClient();

class _UnsupportedPushClient implements PushClient {
  @override
  Stream<String> get deepLinks => const Stream.empty();
  @override
  Future<void> startIfConsented() async {}
  @override
  Future<PushRegistration> enable() =>
      Future.error(UnsupportedError('当前平台不支持系统推送'));
  @override
  Future<PushStatus> status() async => const PushStatus(
    supported: false,
    enabled: false,
    installed: false,
    message: '当前平台不支持系统推送',
  );
}
