import 'dart:typed_data';

import '../../core/network/api_client.dart';
import 'album.dart';

class AlbumRepository {
  const AlbumRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Album>> listAlbums() async {
    final payload = await apiClient.post(
      '/api/v1/functions/album',
      body: const {'action': 'listAlbums'},
    );
    return (payload['list'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Album.fromJson)
        .toList(growable: false);
  }

  Future<String> addAlbum(String name) async {
    final requestId = _requestId('album');
    final payload = await apiClient.post(
      '/api/v1/functions/album',
      body: {
        'action': 'addAlbum',
        'data': {'name': name.trim(), 'requestId': requestId},
      },
    );
    return payload['id'] as String? ?? '';
  }

  Future<void> deleteAlbum(String id) async {
    await apiClient.post(
      '/api/v1/functions/album',
      body: {
        'action': 'deleteAlbum',
        'data': {'id': id},
      },
    );
  }

  Future<void> renameAlbum(String id, String name) async {
    await apiClient.post(
      '/api/v1/functions/album',
      body: {
        'action': 'updateAlbum',
        'data': {'id': id, 'name': name.trim()},
      },
    );
  }

  Future<PhotoPage> listPhotos(
    String albumId, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final payload = await apiClient.post(
      '/api/v1/functions/album',
      body: {
        'action': 'listPhotos',
        'data': {'albumId': albumId, 'page': page, 'pageSize': pageSize},
      },
    );
    final items = (payload['list'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AlbumPhoto.fromJson)
        .toList(growable: false);
    return PhotoPage(
      items: items,
      total: (payload['total'] as num?)?.toInt() ?? items.length,
      hasMore: payload['hasMore'] as bool? ?? false,
    );
  }

  Future<void> uploadPhotos(
    String albumId,
    List<PendingPhoto> photos, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final requestId = _requestId('photos');
    final uploaded = <String>[];
    try {
      for (var index = 0; index < photos.length; index++) {
        final photo = photos[index];
        final result = await apiClient.uploadBytes(
          '/api/v1/files/images',
          bytes: photo.bytes,
          fileName: photo.fileName,
        );
        final assetId = result['fileID'] as String? ?? '';
        if (assetId.isEmpty) throw const ApiException('图片上传响应缺少文件 ID');
        uploaded.add(assetId);
        onProgress?.call(index + 1, photos.length);
      }

      final response = await apiClient.post(
        '/api/v1/functions/album',
        body: {
          'action': 'addPhotos',
          'data': {
            'albumId': albumId,
            'requestId': requestId,
            'photos': uploaded
                .map(
                  (assetId) => {
                    'fileId': assetId,
                    'thumbFileId': '',
                    'description': '',
                    'location': '',
                    'tags': <String>[],
                  },
                )
                .toList(growable: false),
          },
        },
      );
      if (response['duplicated'] == true) {
        for (final assetId in uploaded) {
          try {
            await apiClient.delete(
              '/api/v1/files?fileID=${Uri.encodeQueryComponent(assetId)}',
            );
          } catch (_) {}
        }
      }
    } catch (_) {
      for (final assetId in uploaded) {
        try {
          await apiClient.delete(
            '/api/v1/files?fileID=${Uri.encodeQueryComponent(assetId)}',
          );
        } catch (_) {
          // Best-effort cleanup; the server can remove remaining orphaned assets.
        }
      }
      rethrow;
    }
  }

  static String _requestId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> deletePhoto(String id) async {
    await apiClient.post(
      '/api/v1/functions/album',
      body: {
        'action': 'deletePhoto',
        'data': {'id': id},
      },
    );
  }

  Future<bool> toggleFavorite(String id) async {
    final payload = await apiClient.post(
      '/api/v1/functions/album',
      body: {
        'action': 'toggleFavorite',
        'data': {'id': id},
      },
    );
    return payload['isFavorite'] as bool? ?? false;
  }
}

class PendingPhoto {
  const PendingPhoto({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}
