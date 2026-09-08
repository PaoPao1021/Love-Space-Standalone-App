import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'http_client_factory.dart';

class ApiClient {
  ApiClient({required this.tokenStore, http.Client? client})
    : _client = client ?? createHttpClient();

  final TokenStore tokenStore;
  final http.Client _client;
  Future<bool> Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) {
    return _send('GET', path, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _send('POST', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _send('PUT', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send('DELETE', path, authenticated: true);
  }

  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required Uint8List bytes,
    required String fileName,
  }) {
    return _uploadBytes(path, bytes: bytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    required bool authenticated,
    bool retried = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await tokenStore.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'PUT' => await _client.put(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method'),
    };

    if (response.statusCode == 401 && authenticated && !retried) {
      final refreshed = await onUnauthorized?.call() ?? false;
      if (refreshed) {
        return _send(
          method,
          path,
          body: body,
          authenticated: authenticated,
          retried: true,
        );
      }
    }

    return _decode(response);
  }

  Future<Map<String, dynamic>> _uploadBytes(
    String path, {
    required Uint8List bytes,
    required String fileName,
    bool retried = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
    );
    final token = await tokenStore.readAccessToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode == 401 && !retried) {
      final refreshed = await onUnauthorized?.call() ?? false;
      if (refreshed) {
        return _uploadBytes(
          path,
          bytes: bytes,
          fileName: fileName,
          retried: true,
        );
      }
    }
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> payload = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        throw ApiException('服务器返回了无法识别的响应', statusCode: response.statusCode);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        payload['message'] as String? ?? '请求失败（${response.statusCode}）',
        statusCode: response.statusCode,
      );
    }
    if (payload['code'] is num && (payload['code'] as num) != 0) {
      throw ApiException(payload['message'] as String? ?? '请求未完成');
    }
    return payload;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
