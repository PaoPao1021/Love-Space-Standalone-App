import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/features/album/album.dart';

void main() {
  test('parses an album returned by the compatibility gateway', () {
    final album = Album.fromJson({
      '_id': 'album-1',
      'name': '第一次旅行',
      'coverUrl': 'https://example.test/cover.jpg',
      'coverAssetId': 'asset://cover',
      'photoCount': 8,
      'isDefault': false,
      'createdAt': '2026-09-06T08:00:00Z',
    });

    expect(album.id, 'album-1');
    expect(album.name, '第一次旅行');
    expect(album.photoCount, 8);
    expect(album.coverAssetId, 'asset://cover');
    expect(album.createdAt, isNotNull);
  });

  test('prefers a thumbnail and preserves photo metadata', () {
    final photo = AlbumPhoto.fromJson({
      '_id': 'photo-1',
      'albumId': 'album-1',
      'fileId': 'https://example.test/photo.jpg',
      'fileAssetId': 'asset://photo',
      'thumbFileId': 'https://example.test/thumb.jpg',
      'description': '海边日落',
      'location': '厦门',
      'tags': ['旅行', '日落'],
      'isFavorite': true,
      'createdAt': '2026-09-06T08:00:00Z',
    });

    expect(photo.previewUrl, 'https://example.test/thumb.jpg');
    expect(photo.tags, ['旅行', '日落']);
    expect(photo.isFavorite, isTrue);
    expect(photo.copyWith(isFavorite: false).isFavorite, isFalse);
  });
}
