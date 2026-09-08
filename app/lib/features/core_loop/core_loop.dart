class DailyQuestion {
  const DailyQuestion({
    required this.question,
    required this.category,
    required this.myAnswer,
    required this.partnerAnswer,
    required this.partnerAnswered,
    required this.bothAnswered,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) => DailyQuestion(
    question: json['question'] as String? ?? '',
    category: json['category'] as String? ?? '',
    myAnswer: json['myAnswer'] as String?,
    partnerAnswer: json['partnerAnswer'] as String?,
    partnerAnswered: json['partnerAnswered'] as bool? ?? false,
    bothAnswered: json['bothAnswered'] as bool? ?? false,
  );

  final String question;
  final String category;
  final String? myAnswer;
  final String? partnerAnswer;
  final bool partnerAnswered;
  final bool bothAnswered;
}

class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.type,
    required this.content,
    required this.visibility,
    required this.date,
    required this.isMine,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    type: json['moodType'] as String? ?? 'calm',
    content: json['content'] as String? ?? '',
    visibility: json['visibility'] as String? ?? 'both',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    isMine: json['isMine'] as bool? ?? false,
  );

  final String id;
  final String type;
  final String content;
  final String visibility;
  final DateTime date;
  final bool isMine;
}

class MomentEntry {
  const MomentEntry({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.eventDate,
    required this.createdAt,
  });

  factory MomentEntry.fromJson(Map<String, dynamic> json) => MomentEntry(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    authorId: json['author'] as String? ?? '',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    images: (json['images'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    tags: (json['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? ''),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'author': authorId,
    'title': title,
    'content': content,
    'images': images,
    'tags': tags,
    'eventDate': eventDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  final String id;
  final String authorId;
  final String title;
  final String content;
  final List<String> images;
  final List<String> tags;
  final DateTime? eventDate;
  final DateTime createdAt;
}

class MomentPageResult {
  const MomentPageResult({
    required this.items,
    required this.hasMore,
    this.fromCache = false,
  });
  final List<MomentEntry> items;
  final bool hasMore;
  final bool fromCache;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.relatedId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        relatedId: json['relatedId'] as String? ?? '',
        read: json['read'] as bool? ?? json['isRead'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String type;
  final String title;
  final String content;
  final String relatedId;
  final bool read;
  final DateTime createdAt;
}

class QuizQuestion {
  const QuizQuestion({required this.question, required this.options});
  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    question: json['question'] as String? ?? '',
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
  );
  final String question;
  final List<String> options;
}

class QuizEntry {
  const QuizEntry({
    required this.id,
    required this.question,
    required this.myAnswer,
    required this.partnerAnswer,
    required this.partnerAnswered,
    required this.bothAnswered,
    required this.matched,
  });
  factory QuizEntry.fromJson(Map<String, dynamic> json) => QuizEntry(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    question: json['question'] as String? ?? '',
    myAnswer: json['myAnswer'] as String? ?? '',
    partnerAnswer: json['partnerAnswer'] as String? ?? '',
    partnerAnswered: json['partnerAnswered'] as bool? ?? false,
    bothAnswered: json['bothAnswered'] as bool? ?? false,
    matched: json['isMatched'] as bool? ?? false,
  );
  final String id;
  final String question;
  final String myAnswer;
  final String partnerAnswer;
  final bool partnerAnswered;
  final bool bothAnswered;
  final bool matched;
}
