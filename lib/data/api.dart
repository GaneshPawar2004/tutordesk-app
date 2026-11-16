import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Backend address. Override for local testing with
/// `flutter run --dart-define=API_URL=http://192.168.0.10:4000/api/v1`.
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://tutordesk-backend.onrender.com/api/v1',
);

/// The server's web address (privacy policy, terms), e.g. https://….onrender.com
final siteBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');

/// Error returned by the API (or a network failure), with a message that can
/// be shown to the user as-is.
class ApiException implements Exception {
  ApiException(this.message, {this.code = '', this.status = 0});

  final String message;
  final String code;
  final int status;

  @override
  String toString() => message;
}

/// Thin JSON client for the Kaksha API.
class Api {
  Api._();
  static final Api instance = Api._();

  /// Bearer token of the signed-in user.
  String? token;

  /// Called when the server rejects the token (expired or signed out elsewhere).
  void Function()? onUnauthorized;

  /// Called with the server's message when the institute's trial/plan ended
  /// or it was blocked (403 ACCESS_EXPIRED / ACCESS_BLOCKED).
  void Function(String code, String message)? onAccessDenied;

  /// Called when the signed-in staff login was blocked by the admin.
  void Function(String message)? onAccountBlocked;

  /// Replaceable in tests (e.g. with `MockClient` from package:http/testing).
  http.Client client = http.Client();

  // The free server sleeps when idle; the first request can take ~50 seconds.
  static const _timeout = Duration(seconds: 75);

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);
  Future<dynamic> deleteWithBody(String path, Object body) =>
      _send('DELETE', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw ApiException('The server is taking too long. Please try again.');
    } on SocketException {
      throw ApiException('No internet connection. Please check and try again.');
    } on http.ClientException {
      throw ApiException('Could not reach the server. Please try again.');
    }

    final data = res.body.isEmpty ? null : _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final error = data is Map ? data['error'] : null;
    final code = error is Map ? '${error['code'] ?? ''}' : '';
    final message = error is Map && error['message'] != null
        ? '${error['message']}'
        : 'Something went wrong (${res.statusCode}). Please try again.';
    // Wrong password on the login screen is also a 401; only an authenticated
    // request means the session is over.
    if (res.statusCode == 401 && code == 'UNAUTHORIZED' && token != null) {
      onUnauthorized?.call();
    }
    if (code == 'ACCOUNT_BLOCKED' && token != null) {
      onAccountBlocked?.call(message);
    }
    if (code == 'ACCESS_EXPIRED' || code == 'ACCESS_BLOCKED') {
      onAccessDenied?.call(code, message);
    }
    throw ApiException(message, code: code, status: res.statusCode);
  }

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

final api = Api.instance;
