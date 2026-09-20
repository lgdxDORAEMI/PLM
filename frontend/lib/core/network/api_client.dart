import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Backend가 반환한 오류 응답(4xx/5xx)을 감싼다. 화면은 이 타입만 알면 되고,
/// HTTP 상태 코드나 Supabase 자체를 직접 다루지 않는다(STEP 15: Frontend가
/// DB 구조를 직접 알지 않게 한다).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Frontend → API 사이의 유일한 통로(Service 계층). Repository들은 이 클래스만
/// 통해 backend를 호출하고, Supabase Table을 직접 조회하지 않는다 — 인증
/// 토큰도 여기서만 붙인다(Supabase Auth는 로그인 상태 확인 용도로만 쓴다,
/// backend/README.md의 SUPABASE_ANON_KEY 설명과 동일한 경계).
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.backendUrl;

  final http.Client _http;
  final String _baseUrl;

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, String>? query,
    bool throwOnNotFound = false,
  }) async => _asMap(
    await _send('GET', path, query: query, throwOnNotFound: throwOnNotFound),
  );

  Future<List<dynamic>?> getList(
    String path, {
    Map<String, String>? query,
  }) async => _asList(await _send('GET', path, query: query));

  Future<Map<String, dynamic>?> put(
    String path, [
    Map<String, dynamic>? body,
  ]) async => _asMap(await _send('PUT', path, body: body));

  Future<Map<String, dynamic>?> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async => _asMap(await _send('POST', path, body: body));

  Future<void> delete(String path) async => _send('DELETE', path);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool throwOnNotFound = false,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _accessToken;
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 404 && !throwOnNotFound) return null;
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _extractMessage(response.body));
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('API 응답이 객체 형식이 아닙니다.');
  }

  List<dynamic>? _asList(Object? value) {
    if (value == null) return null;
    if (value is List<dynamic>) return value;
    throw const FormatException('API 응답이 배열 형식이 아닙니다.');
  }

  String? get _accessToken {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      // Supabase.initialize()가 아직 안 됐거나(.env 없음) 로그인 전 — 토큰 없이 보낸다.
      return null;
    }
  }

  String _extractMessage(String body) {
    if (body.isEmpty) return 'Unknown error';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
