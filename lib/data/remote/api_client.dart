import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Error returned by the TutorDesk API (or a network failure, status 0).
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message, [this.details]);

  final int status;
  final String code;
  final String message;
  final Object? details;

  bool get isConflict => status == 409;

  @override
  String toString() => message;
}

/// Minimal JSON client for the TutorDesk backend.
class ApiClient {
  ApiClient({required this.baseUrl, this.token, this.onUnauthorized});

  String baseUrl;
  String? token;
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 20);

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body);

  Uri _uri(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base/api$path');
  }

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, _uri(path))
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      response = await http.Response.fromStream(
        await request.send().timeout(_timeout),
      );
    } on SocketException {
      throw ApiException(
        0,
        'network',
        'Cannot reach the server at $baseUrl. Check the PC is on, the backend is running, '
            'and this phone is on the same Wi‑Fi.',
      );
    } on TimeoutException {
      throw ApiException(
        0,
        'timeout',
        'The server at $baseUrl did not respond. Please try again.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(0, 'network', 'Network error: ${e.message}');
    } on FormatException {
      throw const ApiException(
        0,
        'bad_url',
        'The server address is not valid. Example: http://192.168.0.117:4000',
      );
    } on ArgumentError {
      throw const ApiException(
        0,
        'bad_url',
        'The server address is not valid. Example: http://192.168.0.117:4000',
      );
    }

    final text = utf8.decode(response.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    final err = data is Map ? data['error'] as Map? : null;
    throw ApiException(
      response.statusCode,
      (err?['code'] as String?) ?? 'error',
      (err?['message'] as String?) ?? 'Request failed (${response.statusCode})',
      err?['details'],
    );
  }
}
