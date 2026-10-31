import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/server_models.dart';

/// Exception thrown when SysDashServer returns an error response.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? details;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => details != null && details!.isNotEmpty
      ? '$message ($details)'
      : message;
}

/// Result returned from successful login.
class LoginResult {
  final String token;
  final int expiresAt;
  final UserInfo user;

  const LoginResult({
    required this.token,
    required this.expiresAt,
    required this.user,
  });
}

/// Official API client for SysDashServer (Golang REST API + WebSocket).
class SysDashApiClient {
  final String baseUrl;
  final String token;
  final http.Client _httpClient;

  SysDashApiClient({
    required String rawUrl,
    this.token = '',
    http.Client? httpClient,
  })  : baseUrl = normalizeBaseUrl(rawUrl),
        _httpClient = httpClient ?? http.Client();

  /// Normalizes server URL into standard `/api/v1` or `/api` format.
  static String normalizeBaseUrl(String input) {
    var url = input.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    if (url.endsWith('/api/v1') || url.endsWith('/api')) {
      return url;
    }
    return '$url/api/v1';
  }

  /// Transforms http/https base URL into ws/wss WebSocket URL with limit and sorting parameters.
  String getWebSocketUrl({
    int limit = 15,
    String sort = 'cpu',
    String order = 'desc',
  }) {
    final ws = baseUrl.replaceFirst(RegExp(r'^http://'), 'ws://')
                      .replaceFirst(RegExp(r'^https://'), 'wss://');
    final query = <String>[
      if (token.isNotEmpty) 'token=$token',
      'limit=$limit',
      'sort=$sort',
      'order=$order',
    ].join('&');
    return '$ws/ws/metrics?$query';
  }

  /// Default WebSocket URL.
  String get webSocketUrl => getWebSocketUrl();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  // ---------------------------------------------------------------------------
  // 1. Health & Authentication
  // ---------------------------------------------------------------------------

  /// Checks server health via `GET /health` (no auth required).
  Future<bool> checkHealth() async {
    try {
      final res = await _httpClient
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Authenticates with username and password via `POST /auth/login`.
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await _httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    final body = _parseResponse(response);
    final userMap = (body['user'] as Map<String, dynamic>?) ?? {};

    return LoginResult(
      token: (body['token'] as String?) ?? '',
      expiresAt: (body['expires_at'] as num?)?.toInt() ?? 0,
      user: UserInfo.fromJson(userMap),
    );
  }

  /// Fetches current logged-in user profile via `GET /auth/me`.
  Future<UserInfo> getMe() async {
    final res = await _httpClient.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );
    final body = _parseResponse(res);
    return UserInfo.fromJson(body['user'] as Map<String, dynamic>);
  }

  /// Updates user information, changes password, or modifies role via `PUT /users/:id`.
  ///
  /// Requires admin token: `Authorization: Bearer <admin_token>`.
  /// All request body parameters are optional ([username], [fullName], [password], [role]).
  Future<UpdateUserResult> updateUser({
    required int id,
    String? username,
    String? fullName,
    String? password,
    String? role,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$id');
    final payload = <String, dynamic>{
      if (username != null && username.isNotEmpty) 'username': username,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      if (password != null && password.isNotEmpty) 'password': password,
      if (role != null && role.isNotEmpty) 'role': role,
    };

    final response = await _httpClient
        .put(
          uri,
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    final body = _parseResponse(response);
    return UpdateUserResult.fromJson(body);
  }

  // ---------------------------------------------------------------------------
  // 2. System & Metrics API
  // ---------------------------------------------------------------------------

  /// Fetches static hardware and OS info via `GET /system/info`.
  Future<Map<String, dynamic>> getSystemInfo() async {
    final res = await _httpClient.get(
      Uri.parse('$baseUrl/system/info'),
      headers: _headers,
    );
    return _parseResponse(res);
  }

  /// Fetches instantaneous snapshot via `GET /metrics/current`.
  Future<Map<String, dynamic>> getCurrentMetrics() async {
    final res = await _httpClient.get(
      Uri.parse('$baseUrl/metrics/current'),
      headers: _headers,
    );
    return _parseResponse(res);
  }

  /// Fetches downsampled time-series data for charts via `GET /metrics/history`.
  Future<List<Map<String, dynamic>>> getHistory({
    String range = '24h',
    String bucket = 'auto',
    int limit = 500,
  }) async {
    final uri = Uri.parse('$baseUrl/metrics/history').replace(
      queryParameters: {
        'range': range,
        'bucket': bucket,
        'limit': limit.toString(),
      },
    );
    final res = await _httpClient.get(uri, headers: _headers);
    final body = _parseResponse(res);
    final list = (body['metrics'] as List<dynamic>?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Fetches min, max, avg summary via `GET /metrics/summary`.
  Future<Map<String, dynamic>> getSummary({String range = '24h'}) async {
    final uri = Uri.parse('$baseUrl/metrics/summary').replace(
      queryParameters: {'range': range},
    );
    final res = await _httpClient.get(uri, headers: _headers);
    return _parseResponse(res);
  }

  /// Fetches running processes list via `GET /system/processes`.
  Future<List<SystemProcessItem>> getProcesses({
    String search = '',
    String sort = 'cpu',
    String order = 'desc',
    int limit = 15,
  }) async {
    final uri = Uri.parse('$baseUrl/system/processes').replace(
      queryParameters: {
        if (search.isNotEmpty) 'search': search,
        'sort': sort,
        'order': order,
        'limit': limit.toString(),
      },
    );
    final res = await _httpClient.get(uri, headers: _headers);
    final body = _parseResponse(res);
    final list = (body['processes'] as List<dynamic>?) ?? [];
    return list.map((e) => SystemProcessItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetches low-level host and memory/disk diagnostics via `GET /system/diagnostics` (Admin only).
  Future<SystemDiagnostics> getDiagnostics() async {
    final res = await _httpClient.get(
      Uri.parse('$baseUrl/system/diagnostics'),
      headers: _headers,
    );
    final body = _parseResponse(res);
    return SystemDiagnostics.fromJson(body);
  }

  // ---------------------------------------------------------------------------
  // 3. Docker Monitoring API
  // ---------------------------------------------------------------------------

  /// Fetches Docker images list via `GET /docker/images`.
  Future<List<DockerImageItem>> getDockerImages() async {
    final res = await _httpClient.get(
      Uri.parse('$baseUrl/docker/images'),
      headers: _headers,
    );
    final body = _parseResponse(res);
    final list = (body['images'] as List<dynamic>?) ?? [];
    return list.map((e) => DockerImageItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetches Docker containers list via `GET /docker/containers`.
  Future<List<ContainerInfo>> getDockerContainers() async {
    final res = await _httpClient.get(
      Uri.parse('$baseUrl/docker/containers'),
      headers: _headers,
    );
    final body = _parseResponse(res);
    final list = (body['containers'] as List<dynamic>?) ?? [];
    return list
        .map((e) => ContainerInfo.fromSysDashJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 4. WebSocket Streaming
  // ---------------------------------------------------------------------------

  /// Connects to real-time WebSocket stream `/ws/metrics?token=<jwt>&limit=<limit>&sort=<sort>&order=<order>`.
  Future<WebSocket> connectWebSocket({
    int limit = 15,
    String sort = 'cpu',
    String order = 'desc',
  }) async {
    return WebSocket.connect(
      getWebSocketUrl(limit: limit, sort: sort, order: order),
    ).timeout(
      const Duration(seconds: 6),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final errorMessage = body['error'] as String? ??
        (response.statusCode == 401
            ? 'Sai tài khoản hoặc mật khẩu (Unauthorized)'
            : 'Máy chủ trả về lỗi HTTP ${response.statusCode}');
    final details = body['details'] as String?;

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      details: details,
    );
  }

  void dispose() {
    _httpClient.close();
  }
}
