class Album {
  const Album({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.coverAssetId,
    required this.photoCount,
    required this.isDefault,
    required this.createdAt,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      coverAssetId: json['coverAssetId'] as String? ?? '',
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  final String id;
  final String name;
  final String coverUrl;
  final String coverAssetId;
  final int photoCount;
  final bool isDefault;
  final DateTime? createdAt;
}

class AlbumPhoto {
  const AlbumPhoto({
    required this.id,
    required this.albumId,
    required this.url,
    required this.assetId,
    required this.thumbnailUrl,
    required this.description,
    required this.location,
    required this.tags,
    required this.isFavorite,
    required this.createdAt,
  });

  factory AlbumPhoto.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    return AlbumPhoto(
      id: json['_id'] as String? ?? '',
      albumId: json['albumId'] as String? ?? '',
      url: json['fileId'] as String? ?? '',
      assetId: json['fileAssetId'] as String? ?? '',
      thumbnailUrl: json['thumbFileId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      tags: rawTags.whereType<String>().toList(growable: false),
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  final String id;
  final String albumId;
  final String url;
  final String assetId;
  final String thumbnailUrl;
  final String description;
  final String location;
  final List<String> tags;
  final bool isFavorite;
  final DateTime? createdAt;

  String get previewUrl => thumbnailUrl.isNotEmpty ? thumbnailUrl : url;

  AlbumPhoto copyWith({bool? isFavorite}) {
    return AlbumPhoto(
      id: id,
      albumId: albumId,
      url: url,
      assetId: assetId,
      thumbnailUrl: thumbnailUrl,
      description: description,
      location: location,
      tags: tags,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }
}

class PhotoPage {
  const PhotoPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<AlbumPhoto> items;
  final int total;
  final bool hasMore;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
