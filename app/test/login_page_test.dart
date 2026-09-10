import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lovespace_app/core/auth/auth_controller.dart';
import 'package:lovespace_app/core/auth/auth_repository.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/auth/login_page.dart';
import 'package:lovespace_app/theme/lovespace_theme.dart';

void main() {
  testWidgets('login stays usable on a small portrait phone', (tester) async {
    await _setSurface(tester, const Size(375, 667));
    await tester.pumpWidget(_testApp(textScale: 1));

    expect(find.text('先告诉我你是谁~'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, '开始使用'), findsOneWidget);
  });

  testWidgets('login reflows in phone landscape', (tester) async {
    await _setSurface(tester, const Size(667, 375));
    await tester.pumpWidget(_testApp(textScale: 1));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('LoveSpace'), findsOneWidget);
  });

  testWidgets('login supports large text and dark mode', (tester) async {
    await _setSurface(tester, const Size(375, 667));
    await tester.pumpWidget(_testApp(textScale: 2, dark: true));

    expect(find.text('先告诉我你是谁~'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _testApp({required double textScale, bool dark = false}) {
  final store = TokenStore();
  final controller = AuthController(
    repository: AuthRepository(
      apiClient: ApiClient(tokenStore: store, client: http.Client()),
      tokenStore: store,
    ),
  );
  return MaterialApp(
    theme: LoveSpaceTheme.light,
    darkTheme: LoveSpaceTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: LoginPage(controller: controller),
        );
      },
    ),
  );
}
