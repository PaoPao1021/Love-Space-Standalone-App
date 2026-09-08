import '../../core/network/api_client.dart';
import 'memories_models.dart';

class MemoriesRepository {
  const MemoriesRepository({required this.apiClient});
  final ApiClient apiClient;

  Future<List<WishEntry>> wishes() async =>
      _list(await _call('wish', 'list'), WishEntry.fromJson);

  Future<String> createWish({
    required String requestId,
    required String title,
    required String description,
    MemoryUploadImage? image,
  }) async {
    String asset = '';
    if (image != null) asset = await _upload(image);
    final payload = await _call('wish', 'add', {
      'requestId': requestId,
      'title': title.trim(),
      'description': description.trim(),
      if (asset.isNotEmpty) 'imageUrl': asset,
    });
    if (payload['duplicated'] == true && asset.isNotEmpty) {
      await _deleteQuietly(asset);
    }
    return payload['id'] as String? ?? '';
  }

  Future<void> updateWish(
    String id, {
    String? title,
    String? description,
    String? status,
  }) => _call('wish', 'update', {
    'id': id,
    if (title != null) 'title': title.trim(),
    if (description != null) 'description': description.trim(),
    'status': ?status,
  });

  Future<void> deleteWish(String id) => _call('wish', 'delete', {'id': id});

  Future<CapsuleList> capsules() async {
    final payload = await _call('capsule', 'list');
    return CapsuleList(
      locked: _items(payload['locked'], TimeCapsule.fromJson),
      unlocked: _items(payload['unlocked'], TimeCapsule.fromJson),
    );
  }

  Future<TimeCapsule> capsule(String id) async {
    final payload = await _call('capsule', 'get', {'id': id});
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('时光胶囊不存在');
    }
    return TimeCapsule.fromJson(data);
  }

  Future<String> createCapsule({
    required String requestId,
    required String title,
    required String content,
    required DateTime unlockDate,
    required List<MemoryUploadImage> images,
  }) async {
    final assets = <String>[];
    for (final image in images.take(9)) {
      assets.add(await _upload(image));
    }
    final payload = await _call('capsule', 'add', {
      'requestId': requestId,
      'title': title.trim(),
      'content': content.trim(),
      'unlockDate': _date(unlockDate),
      'imageAssetIds': assets,
    });
    if (payload['duplicated'] == true) {
      for (final asset in assets) {
        await _deleteQuietly(asset);
      }
    }
    return payload['id'] as String? ?? '';
  }

  Future<String> _upload(MemoryUploadImage image) async {
    final payload = await apiClient.uploadBytes(
      '/api/v1/files/images',
      bytes: image.bytes,
      fileName: image.fileName,
    );
    final id = payload['fileID'] as String? ?? '';
    if (id.isEmpty) throw const ApiException('图片上传响应缺少文件 ID');
    return id;
  }

  Future<void> _deleteQuietly(String asset) async {
    try {
      await apiClient.delete(
        '/api/v1/files?fileID=${Uri.encodeQueryComponent(asset)}',
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _call(
    String function,
    String action, [
    Map<String, Object?> data = const {},
  ]) => apiClient.post(
    '/api/v1/functions/$function',
    body: {'action': action, 'data': data},
  );

  static List<T> _list<T>(
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic>) convert,
  ) => _items(payload['list'], convert);

  static List<T> _items<T>(
    Object? source,
    T Function(Map<String, dynamic>) convert,
  ) => (source as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(convert)
      .toList(growable: false);

  static String requestId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
