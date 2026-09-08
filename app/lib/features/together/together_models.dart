class CoupleTask {
  const CoupleTask({
    required this.id,
    required this.title,
    required this.description,
    required this.assignee,
    required this.rewardPoints,
    required this.createdBy,
    required this.status,
    required this.completedBy,
    required this.dueDate,
    required this.createdAt,
  });

  factory CoupleTask.fromJson(Map<String, dynamic> json) => CoupleTask(
    id: _id(json),
    title: _text(json['title']),
    description: _text(json['description']),
    assignee: _text(json['assignee'], 'both'),
    rewardPoints: _integer(json['rewardPoints']),
    createdBy: _text(json['createdBy']),
    status: _text(json['status'], 'pending'),
    completedBy: _text(json['completedBy']),
    dueDate: _date(json['dueDate']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
  );

  final String id;
  final String title;
  final String description;
  final String assignee;
  final int rewardPoints;
  final String createdBy;
  final String status;
  final String completedBy;
  final DateTime? dueDate;
  final DateTime createdAt;

  bool get completed => status == 'completed';
  bool canComplete(String userId) =>
      !completed &&
      (assignee == 'both' ||
          (assignee == 'me' && createdBy == userId) ||
          (assignee == 'partner' && createdBy != userId));
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.imageAssetId,
    required this.tags,
    required this.rating,
    required this.location,
    required this.note,
    required this.price,
    required this.description,
    required this.available,
    required this.lastEatenAt,
    required this.specs,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
    id: _id(json),
    name: _text(json['name']),
    category: _text(json['category'], '主食'),
    imageUrl: _text(json['imageUrl']),
    imageAssetId: _text(json['imageAssetId']),
    tags: _strings(json['tags']),
    rating: _number(json['rating'], 5),
    location: _text(json['location']),
    note: _text(json['note']),
    price: _number(json['price'], 0),
    description: _text(json['description']),
    available: json['isAvailable'] as bool? ?? true,
    lastEatenAt: _date(json['lastEatenAt']),
    specs: (json['specs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DishSpecGroup.fromJson)
        .toList(growable: false),
  );

  final String id;
  final String name;
  final String category;
  final String imageUrl;
  final String imageAssetId;
  final List<String> tags;
  final double rating;
  final String location;
  final String note;
  final double price;
  final String description;
  final bool available;
  final DateTime? lastEatenAt;
  final List<DishSpecGroup> specs;
}

class DishSpecGroup {
  const DishSpecGroup({required this.name, required this.options});
  factory DishSpecGroup.fromJson(Map<String, dynamic> json) => DishSpecGroup(
    name: _text(json['name']),
    options: (json['options'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DishSpecOption.fromJson)
        .toList(growable: false),
  );
  final String name;
  final List<DishSpecOption> options;

  Map<String, dynamic> toJson() => {
    'name': name,
    'options': options.map((option) => option.toJson()).toList(),
  };
}

class DishSpecOption {
  const DishSpecOption({required this.name, required this.priceAdd});
  factory DishSpecOption.fromJson(Map<String, dynamic> json) => DishSpecOption(
    name: _text(json['name']),
    priceAdd: _number(json['priceAdd']),
  );
  final String name;
  final double priceAdd;

  Map<String, dynamic> toJson() => {'name': name, 'priceAdd': priceAdd};
}

class DishOrderDraft {
  const DishOrderDraft({
    required this.dishId,
    required this.quantity,
    this.selectedSpecs = const {},
  });
  final String dishId;
  final int quantity;
  final Map<String, String> selectedSpecs;

  DishOrderDraft copyWith({int? quantity}) => DishOrderDraft(
    dishId: dishId,
    quantity: quantity ?? this.quantity,
    selectedSpecs: selectedSpecs,
  );
}

class MenuOrder {
  const MenuOrder({
    required this.id,
    required this.items,
    required this.totalPrice,
    required this.note,
    required this.orderedBy,
    required this.createdAt,
  });

  factory MenuOrder.fromJson(Map<String, dynamic> json) => MenuOrder(
    id: _id(json),
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OrderLine.fromJson)
        .toList(growable: false),
    totalPrice: _number(json['totalPrice'], 0),
    note: _text(json['note']),
    orderedBy: _text(json['orderedBy']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
  );

  final String id;
  final List<OrderLine> items;
  final double totalPrice;
  final String note;
  final String orderedBy;
  final DateTime createdAt;
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name});
  factory MenuCategory.fromJson(Map<String, dynamic> json) =>
      MenuCategory(id: _id(json), name: _text(json['name']));
  final String id;
  final String name;
}

class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.price,
    required this.specText,
  });
  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    name: _text(json['name']),
    quantity: _integer(json['quantity'], 1),
    price: _number(json['price'], 0) + _number(json['specPriceAdd'], 0),
    specText: _text(json['specText']),
  );
  final String name;
  final int quantity;
  final double price;
  final String specText;
}

class PointScore {
  const PointScore({required this.mine, required this.partner});
  factory PointScore.fromJson(Map<String, dynamic> json) => PointScore(
    mine: _integer(json['myScore']),
    partner: _integer(json['partnerScore']),
  );
  final int mine;
  final int partner;
}

class PointLevel {
  const PointLevel({
    required this.name,
    required this.minimum,
    required this.score,
    required this.nextName,
    required this.nextMinimum,
  });
  factory PointLevel.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? const {};
    final next = json['next'] as Map<String, dynamic>?;
    return PointLevel(
      name: _text(current['name'], '新手情侣'),
      minimum: _integer(current['min']),
      score: _integer(json['score']),
      nextName: _text(next?['name']),
      nextMinimum: _integer(next?['min']),
    );
  }
  final String name;
  final int minimum;
  final int score;
  final String nextName;
  final int nextMinimum;

  double get progress {
    if (nextMinimum <= minimum) return 1;
    return ((score - minimum) / (nextMinimum - minimum)).clamp(0, 1);
  }
}

class PointRecord {
  const PointRecord({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.reason,
    required this.note,
    required this.createdAt,
  });
  factory PointRecord.fromJson(Map<String, dynamic> json) => PointRecord(
    id: _id(json),
    fromUser: _text(json['fromUser']),
    toUser: _text(json['toUser']),
    amount: _integer(json['amount']),
    reason: _text(json['reason']),
    note: _text(json['note']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
  );
  final String id;
  final String fromUser;
  final String toUser;
  final int amount;
  final String reason;
  final String note;
  final DateTime createdAt;
}

class ExchangeOption {
  const ExchangeOption({
    required this.id,
    required this.name,
    required this.cost,
    required this.builtIn,
    required this.createdBy,
  });
  factory ExchangeOption.fromJson(Map<String, dynamic> json) => ExchangeOption(
    id: _id(json),
    name: _text(json['name']),
    cost: _integer(json['cost']),
    builtIn: json['builtIn'] as bool? ?? false,
    createdBy: _text(json['createdBy']),
  );
  final String id;
  final String name;
  final int cost;
  final bool builtIn;
  final String createdBy;
}

class ExchangeRecord {
  const ExchangeRecord({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.cost,
    required this.createdAt,
  });
  factory ExchangeRecord.fromJson(Map<String, dynamic> json) => ExchangeRecord(
    id: _id(json),
    userId: _text(json['userId']),
    itemName: _text(json['itemName']),
    cost: _integer(json['cost']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
  );
  final String id;
  final String userId;
  final String itemName;
  final int cost;
  final DateTime createdAt;
}

String _id(Map<String, dynamic> json) =>
    _text(json['_id']).isNotEmpty ? _text(json['_id']) : _text(json['id']);
String _text(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();
int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;
double _number(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse(_text(value)) ?? fallback;
DateTime? _date(Object? value) => DateTime.tryParse(_text(value));
List<String> _strings(Object? value) => (value as List<dynamic>? ?? const [])
    .map((item) => item.toString())
    .where((item) => item.isNotEmpty)
    .toList(growable: false);
