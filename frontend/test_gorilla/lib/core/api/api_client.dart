import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
import 'package:test_gorilla/core/utils/jwt_storage.dart';

class ApiClient {
  static const String baseUrl = ApiConstants.baseUrl;
  late http.Client _httpClient;
  VoidCallback? _onUnauthorized;
  bool _isHandlingUnauthorized = false;

  ApiClient() {
    _httpClient = http.Client();
  }

  void setUnauthorizedHandler(VoidCallback handler) {
    _onUnauthorized = handler;
  }

  /// Log debug message
  void _log(String message) {
    if (kDebugMode) {
      print('[ApiClient] $message');
    }
  }

  /// Add auth headers
  Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = JwtStorage.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// GET request
  Future<dynamic> get(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();

      _log('GET $url');

      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(
            Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      return await _handleResponse(
        response,
        hadAuthToken: headers.containsKey('Authorization'),
      );
    } catch (e) {
      _log('GET Error: $e');
      rethrow;
    }
  }

  /// POST request
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();
      final requestHeaders = Map<String, String>.from(headers);
      final encodedBody = body != null ? jsonEncode(body) : null;

      if (encodedBody == null) {
        requestHeaders.remove('Content-Type');
      }

      _log('POST $url with body: $body');

      final response = await _httpClient
          .post(url, headers: requestHeaders, body: encodedBody)
          .timeout(
            Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      return await _handleResponse(
        response,
        hadAuthToken: requestHeaders.containsKey('Authorization'),
      );
    } catch (e) {
      _log('POST Error: $e');
      rethrow;
    }
  }

  /// PUT request
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();
      final requestHeaders = Map<String, String>.from(headers);
      final encodedBody = body != null ? jsonEncode(body) : null;

      if (encodedBody == null) {
        requestHeaders.remove('Content-Type');
      }

      _log('PUT $url with body: $body');

      final response = await _httpClient
          .put(url, headers: requestHeaders, body: encodedBody)
          .timeout(
            Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      return await _handleResponse(
        response,
        hadAuthToken: requestHeaders.containsKey('Authorization'),
      );
    } catch (e) {
      _log('PUT Error: $e');
      rethrow;
    }
  }

  /// DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();

      _log('DELETE $url');

      final response = await _httpClient
          .delete(url, headers: headers)
          .timeout(
            Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      return await _handleResponse(
        response,
        hadAuthToken: headers.containsKey('Authorization'),
      );
    } catch (e) {
      _log('DELETE Error: $e');
      rethrow;
    }
  }

  /// PATCH request
  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();
      final requestHeaders = Map<String, String>.from(headers);
      final encodedBody = body != null ? jsonEncode(body) : null;

      if (encodedBody == null) {
        requestHeaders.remove('Content-Type');
      }

      _log('PATCH $url with body: $body');

      final response = await _httpClient
          .patch(url, headers: requestHeaders, body: encodedBody)
          .timeout(
            Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      return await _handleResponse(
        response,
        hadAuthToken: requestHeaders.containsKey('Authorization'),
      );
    } catch (e) {
      _log('PATCH Error: $e');
      rethrow;
    }
  }

  /// Handle response
  Future<dynamic> _handleResponse(
    http.Response response, {
    required bool hadAuthToken,
  }) async {
    _log('Response Status: ${response.statusCode}');
    _log('Response Body: ${response.body}');

    try {
      final decodedResponse = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedResponse;
      } else {
        if (response.statusCode == 401 && hadAuthToken) {
          await _handleUnauthorized();
        }

        final errorMessage =
            decodedResponse['error']?['message'] ??
            decodedResponse['message'] ??
            'An error occurred';
        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
          response: decodedResponse,
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      if (response.statusCode == 401 && hadAuthToken) {
        await _handleUnauthorized();
      }

      throw ApiException(
        message: 'Failed to parse response',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _handleUnauthorized() async {
    if (_isHandlingUnauthorized) {
      return;
    }

    _isHandlingUnauthorized = true;
    try {
      await JwtStorage.clearAuth();
      _onUnauthorized?.call();
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  /// Dispose client
  void dispose() {
    _httpClient.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic response;

  ApiException({
    required this.message,
    required this.statusCode,
    this.response,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
