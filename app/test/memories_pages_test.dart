import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/account_cache.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/capsules/capsules_page.dart';
import 'package:lovespace_app/features/memories/memories_models.dart';
import 'package:lovespace_app/features/memories/memories_repository.dart';
import 'package:lovespace_app/features/wishes/wishes_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('wishes page fits 375px and large text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cache = AccountCache()..scopeTo('user-a');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFFBE185D)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: WishesPage(repository: _FakeMemoriesRepository(), cache: cache),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一起看海'), findsOneWidget);
    expect(find.text('⭐'), findsOneWidget);
    await tester.tap(find.text('一起看海'));
    await tester.pumpAndSettle();
    expect(find.text('💫'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsules page fits phone landscape in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cache = AccountCache()..scopeTo('user-a');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: CapsulesPage(repository: _FakeMemoriesRepository(), cache: cache),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('写给明年的信'), findsOneWidget);
    expect(find.textContaining('开启'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('写一封胶囊'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('locked capsule model never invents hidden content', () {
    final item = TimeCapsule.fromJson({
      '_id': 'capsule-1',
      'title': '秘密',
      'unlockDate': '2099-01-01',
      'isUnlocked': false,
    });
    expect(item.content, isEmpty);
    expect(item.unlocked, isFalse);
  });
}

class _FakeMemoriesRepository extends MemoriesRepository {
  _FakeMemoriesRepository()
    : super(apiClient: ApiClient(tokenStore: TokenStore()));

  String wishStatus = 'todo';

  @override
  Future<List<WishEntry>> wishes() async => [
    WishEntry.fromJson({
      '_id': 'wish-1',
      'title': '一起看海',
      'description': '等天气暖和的时候出发',
      'status': wishStatus,
      'createdAt': '2026-09-07T10:00:00Z',
    }),
  ];

  @override
  Future<void> updateWish(
    String id, {
    String? title,
    String? description,
    String? status,
  }) async {
    if (status != null) wishStatus = status;
  }

  @override
  Future<CapsuleList> capsules() async => CapsuleList(
    locked: [
      TimeCapsule.fromJson({
        '_id': 'capsule-1',
        'title': '写给明年的信',
        'unlockDate': '2027-09-07',
        'isUnlocked': false,
      }),
    ],
    unlocked: const [],
  );
}
