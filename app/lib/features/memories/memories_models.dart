import 'dart:typed_data';

class WishEntry {
  const WishEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.createdBy,
    required this.status,
    required this.completedAt,
    required this.createdAt,
  });

  factory WishEntry.fromJson(Map<String, dynamic> json) => WishEntry(
    id: _id(json),
    title: _text(json['title']),
    description: _text(json['description']),
    imageUrl: _text(json['imageUrl']),
    createdBy: _text(json['createdBy']),
    status: _text(json['status'], 'todo'),
    completedAt: _date(json['completedAt']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
  );

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String createdBy;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;
}

class TimeCapsule {
  const TimeCapsule({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.images,
    required this.unlockDate,
    required this.unlocked,
    required this.createdAt,
  });

  factory TimeCapsule.fromJson(Map<String, dynamic> json) => TimeCapsule(
    id: _id(json),
    authorId: _text(json['author']),
    title: _text(json['title']),
    content: _text(json['content']),
    images: (json['images'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false),
    unlockDate: _date(json['unlockDate']) ?? DateTime.now(),
    unlocked: json['isUnlocked'] as bool? ?? false,
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
  );

  final String id;
  final String authorId;
  final String title;
  final String content;
  final List<String> images;
  final DateTime unlockDate;
  final bool unlocked;
  final DateTime createdAt;

  int daysUntil(DateTime now) {
    final days = DateTime(
      unlockDate.year,
      unlockDate.month,
      unlockDate.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return days < 0 ? 0 : days;
  }
}

class CapsuleList {
  const CapsuleList({required this.locked, required this.unlocked});
  final List<TimeCapsule> locked;
  final List<TimeCapsule> unlocked;
}

class MemoryUploadImage {
  const MemoryUploadImage({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

String _id(Map<String, dynamic> json) {
  final underscore = _text(json['_id']);
  return underscore.isNotEmpty ? underscore : _text(json['id']);
}

String _text(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();
DateTime? _date(Object? value) => DateTime.tryParse(_text(value));
