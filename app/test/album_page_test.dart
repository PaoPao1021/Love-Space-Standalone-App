import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/album/album_page.dart';
import 'package:lovespace_app/features/album/album_repository.dart';
import 'package:lovespace_app/theme/lovespace_theme.dart';

void main() {
  testWidgets('album list stays usable on a small phone with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final repository = AlbumRepository(
      apiClient: ApiClient(
        tokenStore: _MemoryTokenStore(),
        client: _AlbumClient(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: LoveSpaceTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 667),
              textScaler: TextScaler.linear(1.6),
            ),
            child: AlbumPage(repository: repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我们的相册'), findsOneWidget);
    expect(find.text('第一次旅行'), findsOneWidget);
    expect(find.text('8 张照片'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新建相册'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryTokenStore extends TokenStore {
  @override
  Future<String?> readAccessToken() async => 'access-token';
}

class _AlbumClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = utf8.decode(await request.finalize().toBytes());
    expect(body, contains('listAlbums'));
    final response = jsonEncode({
      'code': 0,
      'list': [
        {
          '_id': 'album-1',
          'name': '第一次旅行',
          'coverUrl': '',
          'coverAssetId': '',
          'photoCount': 8,
          'isDefault': false,
          'createdAt': '2026-09-06T08:00:00Z',
        },
      ],
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(response)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
