import 'dart:typed_data';

import '../../core/network/api_client.dart';
import 'together_models.dart';

class TogetherRepository {
  const TogetherRepository({required this.apiClient});
  final ApiClient apiClient;

  Future<List<CoupleTask>> tasks({String status = ''}) async {
    final payload = await _call('task', 'list', {
      if (status.isNotEmpty) 'status': status,
    });
    return _list(payload, CoupleTask.fromJson);
  }

  Future<CoupleTask> task(String id) async {
    final payload = await _call('task', 'detail', {'id': id});
    return CoupleTask.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<void> createTask({
    required String requestId,
    required String title,
    required String description,
    required String assignee,
    required int reward,
    DateTime? dueDate,
  }) => _call('task', 'add', {
    'requestId': requestId,
    'title': title.trim(),
    'description': description.trim(),
    'assignee': assignee,
    'rewardPoints': reward,
    if (dueDate != null) 'dueDate': _date(dueDate),
  });

  Future<void> completeTask(String id) => _call('task', 'complete', {'id': id});
  Future<void> deleteTask(String id) => _call('task', 'delete', {'id': id});

  Future<List<Dish>> dishes({String keyword = '', String category = ''}) async {
    final payload = await _call('menu', 'list', {
      if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      if (category.isNotEmpty) 'category': category,
    });
    return _list(payload, Dish.fromJson);
  }

  Future<List<Dish>> recommendations() async =>
      _list(await _call('menu', 'recommend'), Dish.fromJson);

  Future<bool> addDish({
    required String requestId,
    required String name,
    required String category,
    required double price,
    required int rating,
    required String description,
    required String tags,
    String note = '',
    String location = '',
    bool available = true,
    String imageAssetId = '',
    List<DishSpecGroup> specs = const [],
  }) async {
    final payload = await _call('menu', 'add', {
      'requestId': requestId,
      'name': name.trim(),
      'category': category.trim(),
      'price': price,
      'rating': rating,
      'description': description.trim(),
      'note': note.trim(),
      'location': location.trim(),
      'isAvailable': available,
      if (imageAssetId.isNotEmpty) 'imageUrl': imageAssetId,
      'specs': specs.map((group) => group.toJson()).toList(),
      'tags': tags
          .split(RegExp(r'[\s,，]+'))
          .where((value) => value.isNotEmpty)
          .take(10)
          .toList(),
    });
    return payload['duplicated'] as bool? ?? false;
  }

  Future<void> updateDish({
    required String id,
    required String name,
    required String category,
    required double price,
    required int rating,
    required String description,
    required String tags,
    String note = '',
    String location = '',
    bool available = true,
    String? imageAssetId,
    List<DishSpecGroup> specs = const [],
  }) => _call('menu', 'update', {
    'id': id,
    'name': name.trim(),
    'category': category.trim(),
    'price': price,
    'rating': rating,
    'description': description.trim(),
    'note': note.trim(),
    'location': location.trim(),
    'isAvailable': available,
    'imageUrl': ?imageAssetId,
    'specs': specs.map((group) => group.toJson()).toList(),
    'tags': tags
        .split(RegExp(r'[\s,，]+'))
        .where((value) => value.isNotEmpty)
        .take(10)
        .toList(),
  });

  Future<List<MenuCategory>> categories() async =>
      _list(await _call('menu', 'listCategories'), MenuCategory.fromJson);

  Future<void> addCategory(String name) =>
      _call('menu', 'addCategory', {'name': name.trim(), 'icon': ''});

  Future<void> deleteCategory(String id) =>
      _call('menu', 'deleteCategory', {'id': id});

  Future<void> deleteDish(String id) => _call('menu', 'delete', {'id': id});

  Future<String> uploadDishImage(Uint8List bytes, String fileName) async {
    final payload = await apiClient.uploadBytes(
      '/api/v1/files/images',
      bytes: bytes,
      fileName: fileName,
    );
    final id = payload['fileID'] as String? ?? '';
    if (id.isEmpty) throw const ApiException('图片上传响应缺少文件 ID');
    return id;
  }

  Future<void> deleteAsset(String assetId) => apiClient.delete(
    '/api/v1/files?fileID=${Uri.encodeQueryComponent(assetId)}',
  );
  Future<void> markDishEaten(String id) =>
      _call('menu', 'markEaten', {'id': id});

  Future<void> placeOrder(
    List<DishOrderDraft> items,
    String note, {
    required String requestId,
  }) async {
    await _call('menu', 'addOrder', {
      'requestId': requestId,
      'items': items
          .where((item) => item.quantity > 0)
          .map(
            (item) => {
              'dishId': item.dishId,
              'quantity': item.quantity,
              'selectedSpecs': item.selectedSpecs,
            },
          )
          .toList(),
      'note': note.trim(),
    });
  }

  Future<List<MenuOrder>> orders() async =>
      _list(await _call('menu', 'listOrders'), MenuOrder.fromJson);

  Future<PointScore> score() async =>
      PointScore.fromJson(await _call('points', 'getScore'));

  Future<PointLevel> pointLevel() async =>
      PointLevel.fromJson(await _call('points', 'getLevel'));

  Future<List<PointRecord>> pointRecords() async => _list(
    await _call('points', 'list', {'page': 1, 'pageSize': 50}),
    PointRecord.fromJson,
  );

  Future<void> givePoints({
    required int amount,
    required String reason,
    required String note,
  }) => _call('points', 'add', {
    'requestId': requestId('point'),
    'amount': amount,
    'reason': reason.trim(),
    'note': note.trim(),
  });

  Future<List<ExchangeOption>> exchangeOptions() async => _list(
    await _call('points', 'listExchangeOptions'),
    ExchangeOption.fromJson,
  );

  Future<void> redeem(ExchangeOption option, String note) =>
      _call('points', 'exchange', {
        'requestId': requestId('redeem'),
        if (option.id.isNotEmpty) 'exchangeId': option.id,
        if (option.id.isEmpty) 'item': option.name,
        if (option.id.isEmpty) 'amount': option.cost,
        'note': note.trim(),
      });

  Future<void> addExchange(String name, int cost) =>
      _call('points', 'addExchange', {'name': name.trim(), 'cost': cost});

  Future<void> deleteExchange(String id) =>
      _call('points', 'deleteExchange', {'id': id});

  Future<List<ExchangeRecord>> exchangeHistory() async => _list(
    await _call('points', 'listExchangeHistory'),
    ExchangeRecord.fromJson,
  );

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
  ) => (payload['list'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(convert)
      .toList(growable: false);

  static String requestId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
