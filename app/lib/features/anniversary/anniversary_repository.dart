import '../../core/network/api_client.dart';
import 'anniversary.dart';

class AnniversaryRepository {
  const AnniversaryRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Anniversary>> list() async {
    final payload = await apiClient.post(
      '/api/v1/functions/anniversary',
      body: const {'action': 'list'},
    );
    final rawList = payload['list'] as List<dynamic>? ?? const [];
    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(Anniversary.fromJson)
        .toList();
    items.sort((a, b) {
      if (a.isTop != b.isTop) return a.isTop ? -1 : 1;
      return a.daysFrom().compareTo(b.daysFrom());
    });
    return items;
  }

  Future<void> add(AnniversaryDraft draft) async {
    await apiClient.post(
      '/api/v1/functions/anniversary',
      body: {'action': 'add', 'data': draft.toJson()},
    );
  }

  Future<void> update(String id, AnniversaryDraft draft) async {
    await apiClient.post(
      '/api/v1/functions/anniversary',
      body: {
        'action': 'update',
        'data': {'id': id, ...draft.toJson()},
      },
    );
  }

  Future<void> delete(String id) async {
    await apiClient.post(
      '/api/v1/functions/anniversary',
      body: {
        'action': 'delete',
        'data': {'id': id},
      },
    );
  }
}
