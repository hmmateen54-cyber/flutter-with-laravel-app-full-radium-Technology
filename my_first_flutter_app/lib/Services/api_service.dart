import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Shared transport for the existing Laravel API.
///
/// Endpoint paths and request payloads stay owned by the screens so this layer
/// does not change the backend contract.
class ApiService {
  ApiService._();

  static const String baseUrl = 'http://192.168.18.7:8000/api';
  static const Duration requestTimeout = Duration(seconds: 15);

  static Future<http.Response> get(
    String path, {
    bool authenticated = true,
  }) async {
    return _send('GET', path, authenticated: authenticated);
  }

  static Future<http.Response> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    return _send('POST', path, body: body, authenticated: authenticated);
  }

  static Future<http.Response> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    return _send('PUT', path, body: body, authenticated: authenticated);
  }

  static Future<http.Response> delete(
    String path, {
    bool authenticated = true,
  }) async {
    return _send('DELETE', path, authenticated: authenticated);
  }

  static Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    required bool authenticated,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    if (authenticated) {
      final preferences = await SharedPreferences.getInstance();
      final token = preferences.getString('token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final uri = Uri.parse('$baseUrl$path');
    final request = switch (method) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: body),
      'PUT' => http.put(uri, headers: headers, body: body),
      'DELETE' => http.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };

    return request.timeout(requestTimeout);
  }

  static dynamic decode(http.Response response) {
    if (response.body.trim().isEmpty) return null;

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('The server returned an invalid response.');
    }
  }

  static String encode(Object? value) => jsonEncode(value);

  static String messageForStatus(int statusCode, {String? serverMessage}) {
    final message = serverMessage?.trim();
    if (message != null && message.isNotEmpty) return message;

    return switch (statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to do that.',
      404 => 'The requested information could not be found.',
      >= 500 => 'The service is temporarily unavailable. Please try again.',
      _ => 'We could not complete your request. Please try again.',
    };
  }

  static String messageForError(Object error) {
    if (error is TimeoutException) {
      return 'The request took too long. Check your connection and try again.';
    }
    if (error is http.ClientException) {
      return 'No internet connection. Check your connection and try again.';
    }
    if (error is FormatException) {
      return 'The server sent an unexpected response. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  static String? responseMessage(http.Response response) {
    try {
      final decoded = decode(response);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } on FormatException {
      // Fall through to the status based message below.
    }
    return null;
  }
}
