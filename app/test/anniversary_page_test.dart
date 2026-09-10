import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/anniversary/anniversary.dart';
import 'package:lovespace_app/features/anniversary/anniversary_page.dart';
import 'package:lovespace_app/features/anniversary/anniversary_repository.dart';

void main() {
  testWidgets('anniversary list starts below a standard top app bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: AnniversaryPage(repository: _FakeAnniversaryRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '纪念日'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('anniversary-card-anniversary-1')),
          )
          .dy,
      greaterThan(kToolbarHeight),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeAnniversaryRepository extends AnniversaryRepository {
  _FakeAnniversaryRepository()
    : super(apiClient: ApiClient(tokenStore: TokenStore()));

  @override
  Future<List<Anniversary>> list() async => [
    Anniversary(
      id: 'anniversary-1',
      name: '我们的纪念日',
      date: DateTime(2024, 5, 20),
      type: 'together',
      note: '',
      isRepeat: true,
      isTop: true,
    ),
  ];
}
