import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/menu/menu_page.dart';
import 'package:lovespace_app/features/memories/memories_models.dart';
import 'package:lovespace_app/features/memories/memories_repository.dart';
import 'package:lovespace_app/features/points/points_page.dart';
import 'package:lovespace_app/features/together/together_hub_page.dart';
import 'package:lovespace_app/features/together/together_models.dart';
import 'package:lovespace_app/features/together/together_repository.dart';
import 'package:lovespace_app/features/wellness/wellness_repository.dart';

void main() {
  testWidgets('together hub remains usable at 375px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFFBE185D)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: TogetherHubPage(
          repository: _FakeTogetherRepository(),
          memoriesRepository: _FakeMemoriesRepository(),
          wellnessRepository: _FakeWellnessRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('共同任务'), findsOneWidget);
    expect(find.text('今天吃什么'), findsOneWidget);
    expect(find.text('甜蜜积分'), findsOneWidget);
    expect(find.text('我们的愿望'), findsOneWidget);
    expect(find.text('时光胶囊'), findsOneWidget);
    expect(find.text('一起变好'), findsOneWidget);
    expect(find.text('我们的月报'), findsOneWidget);
    expect(find.text('默契测试'), findsOneWidget);
    expect(find.text('感谢墙'), findsOneWidget);
    expect(find.text('回忆时间轴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('task assignment determines who may complete it', () {
    final base = {
      '_id': 'task-1',
      'title': '带早餐',
      'createdBy': 'user-a',
      'status': 'pending',
    };
    final mine = CoupleTask.fromJson({...base, 'assignee': 'me'});
    final partner = CoupleTask.fromJson({...base, 'assignee': 'partner'});

    expect(mine.canComplete('user-a'), isTrue);
    expect(mine.canComplete('user-b'), isFalse);
    expect(partner.canComplete('user-a'), isFalse);
    expect(partner.canComplete('user-b'), isTrue);
  });

  testWidgets('menu fits a small dark phone with large text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: MenuPage(repository: _FakeTogetherRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('番茄炒蛋'), findsOneWidget);
    expect(find.text('订单记录'), findsOneWidget);
    await tester.tap(find.text('想吃什么？点TA做'));
    await tester.pumpAndSettle();
    expect(find.text('选择菜品后下单'), findsOneWidget);
    expect(find.text('番茄炒蛋'), findsWidgets);
    await tester.tap(find.text('番茄炒蛋').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('选择 番茄炒蛋 的规格'), findsOneWidget);
    await tester.tap(find.text('加入菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('增加数量'));
    await tester.pumpAndSettle();
    expect(find.text('选择 番茄炒蛋 的规格'), findsOneWidget);
    expect(find.textContaining('少糖'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('points fits phone landscape', (tester) async {
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFFBE185D)),
        home: PointsPage(
          repository: _FakeTogetherRepository(),
          userId: 'user-a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的积分'), findsOneWidget);
    expect(find.text('TA的积分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeMemoriesRepository extends MemoriesRepository {
  _FakeMemoriesRepository()
    : super(apiClient: ApiClient(tokenStore: TokenStore()));

  @override
  Future<List<WishEntry>> wishes() async => [
    WishEntry.fromJson({'_id': 'wish-1', 'title': '一起看海', 'status': 'todo'}),
  ];

  @override
  Future<CapsuleList> capsules() async => CapsuleList(
    locked: [
      TimeCapsule.fromJson({
        '_id': 'capsule-1',
        'title': '明年的信',
        'unlockDate': '2027-09-07',
        'isUnlocked': false,
      }),
    ],
    unlocked: const [],
  );
}

class _FakeWellnessRepository extends WellnessRepository {
  _FakeWellnessRepository()
    : super(apiClient: ApiClient(tokenStore: TokenStore()));
}

class _FakeTogetherRepository extends TogetherRepository {
  _FakeTogetherRepository()
    : super(apiClient: ApiClient(tokenStore: TokenStore()));

  @override
  Future<List<CoupleTask>> tasks({String status = ''}) async => [
    CoupleTask.fromJson({
      '_id': 'task-1',
      'title': '散步',
      'createdBy': 'user-a',
      'status': 'pending',
      'assignee': 'both',
    }),
  ];

  @override
  Future<List<Dish>> dishes({
    String keyword = '',
    String category = '',
  }) async => [
    Dish.fromJson({
      '_id': 'dish-1',
      'name': '番茄炒蛋',
      'category': '家常菜',
      'price': 18,
      'rating': 5,
      'description': '两个人都喜欢的味道',
      'specs': [
        {
          'name': '口味',
          'options': [
            {'name': '正常', 'priceAdd': 0},
            {'name': '少糖', 'priceAdd': 2},
          ],
        },
      ],
    }),
  ];

  @override
  Future<PointScore> score() async => const PointScore(mine: 42, partner: 30);

  @override
  Future<PointLevel> pointLevel() async => const PointLevel(
    name: '新手情侣',
    minimum: 0,
    score: 42,
    nextName: '甜蜜搭子',
    nextMinimum: 100,
  );

  @override
  Future<List<MenuOrder>> orders() async => const [];

  @override
  Future<List<PointRecord>> pointRecords() async => const [];

  @override
  Future<List<ExchangeOption>> exchangeOptions() async => const [];

  @override
  Future<List<ExchangeRecord>> exchangeHistory() async => const [];
}
