import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';

void main() {
  test('uploads bytes as an authenticated multipart image', () async {
    final client = _RecordingClient();
    final api = ApiClient(tokenStore: _MemoryTokenStore(), client: client);

    final response = await api.uploadBytes(
      '/api/v1/files/images',
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      fileName: 'memory.jpg',
    );

    expect(response['fileID'], 'asset://photo');
    final request = client.lastRequest;
    expect(request, isA<http.MultipartRequest>());
    expect(request!.headers['Authorization'], 'Bearer access-token');
    final multipart = request as http.MultipartRequest;
    expect(multipart.files.single.field, 'file');
    expect(multipart.files.single.filename, 'memory.jpg');
  });
}

class _MemoryTokenStore extends TokenStore {
  @override
  Future<String?> readAccessToken() async => 'access-token';
}

class _RecordingClient extends http.BaseClient {
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"code":0,"fileID":"asset://photo"}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
