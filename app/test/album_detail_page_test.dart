import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/album/album_detail_page.dart';
import 'package:lovespace_app/features/album/album_repository.dart';
import 'package:lovespace_app/theme/lovespace_theme.dart';

void main() {
  testWidgets('empty album remains usable in dark landscape with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(667, 375);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final repository = AlbumRepository(
      apiClient: ApiClient(
        tokenStore: _MemoryTokenStore(),
        client: _EmptyAlbumClient(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: LoveSpaceTheme.light,
        darkTheme: LoveSpaceTheme.dark,
        themeMode: ThemeMode.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(667, 375),
            textScaler: TextScaler.linear(1.6),
          ),
          child: AlbumDetailPage(
            repository: repository,
            albumId: 'album-1',
            albumName: '第一次旅行',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一次旅行'), findsOneWidget);
    expect(find.text('相册还是空的'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '选择照片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryTokenStore extends TokenStore {
  @override
  Future<String?> readAccessToken() async => 'access-token';
}

class _EmptyAlbumClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().drain<void>();
    final response = jsonEncode({
      'code': 0,
      'list': <Object>[],
      'total': 0,
      'hasMore': false,
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(response)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
