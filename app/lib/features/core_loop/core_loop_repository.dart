import 'dart:typed_data';

import '../../core/network/api_client.dart';
import '../../core/storage/account_cache.dart';
import 'core_loop.dart';

class CoreLoopRepository {
  const CoreLoopRepository({required this.apiClient, required this.cache});

  final ApiClient apiClient;
  final AccountCache cache;

  Future<DailyQuestion> getDailyQuestion() async {
    final payload = await apiClient.post(
      '/api/v1/functions/daily-question',
      body: const {'action': 'getToday'},
    );
    return DailyQuestion.fromJson(payload);
  }

  Future<DailyQuestion> submitDailyAnswer(String answer) async {
    final payload = await apiClient.post(
      '/api/v1/functions/daily-question',
      body: {
        'action': 'submit',
        'data': {'answer': answer.trim()},
      },
    );
    return DailyQuestion.fromJson(payload);
  }

  Future<MoodEntry?> getMyMood() => _getMood('getToday');
  Future<MoodEntry?> getPartnerMood() => _getMood('getPartner');

  Future<MoodEntry?> _getMood(String action) async {
    final payload = await apiClient.post(
      '/api/v1/functions/mood',
      body: {'action': action},
    );
    final data = payload['data'];
    return data is Map<String, dynamic> ? MoodEntry.fromJson(data) : null;
  }

  Future<void> saveMood({
    required String type,
    required String content,
    required bool private,
  }) async {
    await apiClient.post(
      '/api/v1/functions/mood',
      body: {
        'action': 'add',
        'data': {
          'moodType': type,
          'moodEmoji': '',
          'content': content.trim(),
          'visibility': private ? 'self' : 'both',
          'images': <String>[],
        },
      },
    );
  }

  Future<List<MoodEntry>> moodCalendar(DateTime month) async {
    final payload = await apiClient.post(
      '/api/v1/functions/mood',
      body: {
        'action': 'getCalendar',
        'data': {'year': month.year, 'month': month.month},
      },
    );
    return (payload['list'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MoodEntry.fromJson)
        .toList(growable: false);
  }

  Future<MomentPageResult> moments({int page = 1, String tag = ''}) async {
    final cacheKey = tag.isEmpty ? 'moments.page1' : 'moments.$tag.page1';
    try {
      final payload = await apiClient.post(
        '/api/v1/functions/moments',
        body: {
          'action': 'list',
          'data': {
            'page': page,
            'pageSize': 20,
            if (tag.isNotEmpty) 'tag': tag,
          },
        },
      );
      final items = (payload['list'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MomentEntry.fromJson)
          .toList(growable: false);
      if (page == 1) {
        await cache.writeJson(cacheKey, {
          'items': items.map((item) => item.toJson()).toList(),
        });
      }
      return MomentPageResult(
        items: items,
        hasMore: payload['hasMore'] as bool? ?? false,
      );
    } catch (_) {
      if (page != 1) rethrow;
      final saved = await cache.readJson(cacheKey);
      final items = (saved?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MomentEntry.fromJson)
          .toList(growable: false);
      if (items.isEmpty) rethrow;
      return MomentPageResult(items: items, hasMore: false, fromCache: true);
    }
  }

  Future<MomentEntry?> randomMoment() async {
    final payload = await apiClient.post(
      '/api/v1/functions/moments',
      body: const {'action': 'random'},
    );
    final data = payload['data'];
    return data is Map<String, dynamic> ? MomentEntry.fromJson(data) : null;
  }

  Future<void> addThanks(String content, {required String requestId}) async {
    await apiClient.post(
      '/api/v1/functions/moments',
      body: {
        'action': 'add',
        'data': {
          'requestId': requestId,
          'content': content.trim(),
          'tags': const ['感动'],
        },
      },
    );
  }

  Future<List<QuizQuestion>> quizQuestions() async {
    final payload = await apiClient.post(
      '/api/v1/functions/quiz',
      body: const {'action': 'questions'},
    );
    return (payload['list'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestion.fromJson)
        .toList(growable: false);
  }

  Future<List<QuizEntry>> quizzes() async {
    final payload = await apiClient.post(
      '/api/v1/functions/quiz',
      body: const {'action': 'list'},
    );
    return (payload['list'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(QuizEntry.fromJson)
        .toList(growable: false);
  }

  Future<void> submitQuiz(String question, String answer) async {
    await apiClient.post(
      '/api/v1/functions/quiz',
      body: {
        'action': 'submit',
        'data': {'question': question, 'answer': answer},
      },
    );
  }

  Future<MomentEntry> moment(String id) async {
    final payload = await apiClient.post(
      '/api/v1/functions/moments',
      body: {
        'action': 'get',
        'data': {'id': id},
      },
    );
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('点滴不存在或已删除');
    }
    return MomentEntry.fromJson(data);
  }

  Future<String> publishMoment({
    required String requestId,
    required String title,
    required String content,
    required DateTime date,
    required List<String> tags,
    required List<UploadImage> images,
  }) async {
    final assets = <String>[];
    for (final image in images.take(9)) {
      final uploaded = await apiClient.uploadBytes(
        '/api/v1/files/images',
        bytes: image.bytes,
        fileName: image.fileName,
      );
      final id = uploaded['fileID'] as String? ?? '';
      if (id.isEmpty) throw const ApiException('图片上传响应缺少文件 ID');
      assets.add(id);
    }
    final payload = await apiClient.post(
      '/api/v1/functions/moments',
      body: {
        'action': 'add',
        'data': {
          'requestId': requestId,
          'title': title.trim(),
          'content': content.trim(),
          'eventDate': _date(date),
          'tags': tags,
          'imageAssetIds': assets,
        },
      },
    );
    if (payload['duplicated'] == true) {
      for (final asset in assets) {
        try {
          await apiClient.delete(
            '/api/v1/files?fileID=${Uri.encodeQueryComponent(asset)}',
          );
        } catch (_) {}
      }
    }
    return payload['id'] as String? ?? '';
  }

  Future<void> updateMoment(
    MomentEntry item, {
    required String title,
    required String content,
    required List<String> tags,
  }) async {
    await apiClient.post(
      '/api/v1/functions/moments',
      body: {
        'action': 'update',
        'data': {
          'id': item.id,
          'title': title.trim(),
          'content': content.trim(),
          'tags': tags,
        },
      },
    );
  }

  Future<void> deleteMoment(String id) async {
    await apiClient.post(
      '/api/v1/functions/moments',
      body: {
        'action': 'delete',
        'data': {'id': id},
      },
    );
  }

  Future<({List<AppNotification> items, int unread})> notifications() async {
    final payload = await apiClient.post(
      '/api/v1/functions/notification',
      body: const {'action': 'list'},
    );
    final items = (payload['list'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
    return (
      items: items,
      unread: (payload['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> unreadCount() async {
    final payload = await apiClient.post(
      '/api/v1/functions/notification',
      body: const {'action': 'unreadCount'},
    );
    return (payload['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) => apiClient.post(
    '/api/v1/functions/notification',
    body: {
      'action': 'read',
      'data': {'id': id},
    },
  );

  Future<void> readAll() => apiClient.post(
    '/api/v1/functions/notification',
    body: const {'action': 'readAll'},
  );

  Future<void> updateProfile({
    required String nickname,
    String? avatarAssetId,
  }) async {
    await apiClient.post(
      '/api/v1/functions/user',
      body: {
        'action': 'updateProfile',
        'data': {'nickName': nickname.trim(), 'avatarUrl': ?avatarAssetId},
      },
    );
  }

  Future<void> registerPush({
    required String deviceId,
    required String platform,
    required String provider,
    required String endpoint,
    String publicKey = '',
    String authSecret = '',
  }) => apiClient.put(
    '/api/v1/push/subscriptions/$deviceId',
    body: {
      'platform': platform,
      'provider': provider,
      'endpoint': endpoint,
      'publicKey': publicKey,
      'authSecret': authSecret,
    },
  );

  Future<AppReleaseInfo> latestAndroidRelease() async {
    final payload = await apiClient.get(
      '/releases/android.json',
      authenticated: false,
    );
    return AppReleaseInfo(
      version: payload['version'] as String? ?? '',
      buildNumber: (payload['buildNumber'] as num?)?.toInt() ?? 0,
      downloadUrl: payload['downloadUrl'] as String? ?? '',
      sha256: payload['sha256'] as String? ?? '',
      notes: payload['notes'] as String? ?? '',
    );
  }

  static String newRequestId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class UploadImage {
  const UploadImage({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.sha256,
    required this.notes,
  });
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String sha256;
  final String notes;
}
