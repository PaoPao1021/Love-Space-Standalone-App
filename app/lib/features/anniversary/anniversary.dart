class Anniversary {
  const Anniversary({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.note,
    required this.isRepeat,
    required this.isTop,
  });

  factory Anniversary.fromJson(Map<String, dynamic> json) {
    return Anniversary(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      type: json['type'] as String? ?? 'custom',
      note: json['note'] as String? ?? '',
      isRepeat: json['isRepeat'] as bool? ?? true,
      isTop: json['isTop'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final DateTime date;
  final String type;
  final String note;
  final bool isRepeat;
  final bool isTop;

  DateTime relevantDate([DateTime? from]) {
    final today = _dateOnly(from ?? DateTime.now());
    if (!isRepeat) return _dateOnly(date);
    var next = _safeAnnualDate(today.year);
    if (next.isBefore(today)) next = _safeAnnualDate(today.year + 1);
    return next;
  }

  int daysFrom([DateTime? from]) {
    final today = _dateOnly(from ?? DateTime.now());
    return relevantDate(today).difference(today).inDays;
  }

  int daysTogether([DateTime? from]) {
    final today = _dateOnly(from ?? DateTime.now());
    return today.difference(_dateOnly(date)).inDays.abs();
  }

  DateTime _safeAnnualDate(int year) {
    final lastDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(year, date.month, date.day.clamp(1, lastDay));
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class AnniversaryDraft {
  const AnniversaryDraft({
    required this.name,
    required this.date,
    required this.type,
    required this.note,
    required this.isRepeat,
  });

  final String name;
  final DateTime date;
  final String type;
  final String note;
  final bool isRepeat;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'date': _formatDate(date),
    'type': type,
    'note': note.trim(),
    'isRepeat': isRepeat,
    'remindDaysBefore': 3,
  };

  static String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
