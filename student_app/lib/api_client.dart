import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Talks to the backend. Stores tokens securely and refreshes the access token automatically.
/// The app never calculates attendance: it only displays what the server returns.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 15);

  /// UI listens to this to switch between login and the main app.
  final ValueNotifier<bool> authenticated = ValueNotifier(false);
  String? _access;
  String? _refresh;

  Future<void> init() async {
    try {
      _access = await _storage.read(key: 'access_token');
      _refresh = await _storage.read(key: 'refresh_token');
    } catch (_) {
      _access = null;
      _refresh = null;
    }
    authenticated.value = _refresh != null;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$apiBaseUrl$path');
    return (query == null || query.isEmpty) ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_access != null) 'Authorization': 'Bearer $_access',
      };

  Future<http.Response> _guard(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } on http.ClientException {
      throw ApiException('Cannot reach the server. Check your internet connection.');
    }
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    var message = 'Something went wrong (error ${res.statusCode}). Please try again.';
    if (body is Map && body['detail'] is String) {
      message = body['detail'] as String;
    } else if (body is Map && body['detail'] is List) {
      message = 'Please check the details you entered.';
    }
    throw ApiException(message, res.statusCode);
  }

  Future<void> _saveTokens(Map data) async {
    _access = data['access_token'] as String;
    _refresh = data['refresh_token'] as String;
    await _storage.write(key: 'access_token', value: _access);
    await _storage.write(key: 'refresh_token', value: _refresh);
  }

  Future<void> login(String email, String password) async {
    final res = await _guard(() => http.post(
          _uri('/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        ));
    final data = _decode(res) as Map;
    if (data['role'] != 'STUDENT') {
      throw ApiException('This app is for students only. Teachers and admins should use their own app.');
    }
    await _saveTokens(data);
    authenticated.value = true;
  }

  Future<bool> _refreshTokens() async {
    final token = _refresh;
    if (token == null) return false;
    final res = await _guard(() => http.post(
          _uri('/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': token}),
        ));
    if (res.statusCode != 200) return false;
    await _saveTokens(_decode(res) as Map);
    return true;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var res = await _guard(() => http.get(_uri(path, query), headers: _headers()));
    if (res.statusCode == 401) {
      if (await _refreshTokens()) {
        res = await _guard(() => http.get(_uri(path, query), headers: _headers()));
      }
      if (res.statusCode == 401) {
        await logout();
        throw ApiException('Your session expired. Please log in again.', 401);
      }
    }
    return _decode(res);
  }

  Future<void> logout() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
    } catch (_) {}
    authenticated.value = false;
  }
}
