import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../data/demo_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class BoardMapApi {
  BoardMapApi._();
  static final BoardMapApi instance = BoardMapApi._();
  static const String baseUrl = String.fromEnvironment(
    'BOARDMAP_API_URL',
    // Uvicorn's default bind is IPv4 loopback; using localhost can resolve to
    // IPv6 first in browsers even when the backend is only listening on IPv4.
    defaultValue: 'http://127.0.0.1:8000',
  );
  static Uri urlFor(String path) => Uri.parse(
    path.startsWith('http')
        ? path
        : '$baseUrl${path.startsWith('/') ? '' : '/'}$path',
  );
  static const String _sessionKey = 'boardmap.accessToken';
  String? _token;
  Map<String, dynamic>? user;

  bool get isAuthenticated => _token != null;
  void logout() {
    _token = null;
    user = null;
    removeSessionValue(_sessionKey);
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    String? username,
    required String email,
    required String password,
    required String role,
    String? contactNumber,
  }) async {
    final suppliedUsername = username?.trim();
    final result = await _request(
      'POST',
      '/api/v1/auth/register',
      body: {
        'full_name': fullName,
        'username': suppliedUsername?.isNotEmpty == true
            ? suppliedUsername
            : _usernameForEmail(email),
        'email': email,
        'password': password,
        'role': role,
        'contact_number': contactNumber,
      },
    );
    // Registration creates an account only. The user must sign in explicitly.
    return result;
  }

  static String _usernameForEmail(String email) {
    var hash = 0;
    for (final unit in email.trim().toLowerCase().codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return 'account_${hash.toRadixString(16)}';
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final result = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'identifier': identifier, 'password': password},
    );
    _acceptSession(result);
    return result;
  }

  void _acceptSession(Map<String, dynamic> result) {
    final token = result['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('The BoardMap API returned an invalid session.');
    }
    _token = token;
    user = result['user'] as Map<String, dynamic>?;
    writeSessionValue(_sessionKey, token);
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    final token = readSessionValue(_sessionKey);
    if (token == null || token.isEmpty) return null;
    _token = token;
    try {
      user = await getMe();
      return user;
    } on ApiException catch (error) {
      if (error.statusCode == 401) logout();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getHouses({
    String? query,
    int? minPrice,
    int? maxPrice,
    String? roomType,
    int pageSize = 100,
  }) async {
    final params = <String, String>{'page_size': '$pageSize'};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (minPrice != null) params['min_price'] = '$minPrice';
    if (maxPrice != null) params['max_price'] = '$maxPrice';
    if (roomType != null && roomType != 'Any room') {
      params['room_type'] = roomType;
    }
    final data = await _request(
      'GET',
      '/api/v1/boarding-houses',
      query: params,
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final data = await _request(
      'GET',
      '/api/v1/favorites',
      authenticated: true,
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getRecommendations({
    int? minPrice,
    int? maxPrice,
    String? roomType,
    String? location,
    List<String> amenities = const [],
  }) async {
    final params = <String, String>{};
    if (minPrice != null) params['min_price'] = '$minPrice';
    if (maxPrice != null) params['max_price'] = '$maxPrice';
    if (roomType != null && roomType != 'Any room') {
      params['room_type'] = roomType;
    }
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (amenities.isNotEmpty) params['amenities'] = amenities.join(',');
    final data = await _request(
      'GET',
      '/api/v1/recommendations',
      query: params,
      authenticated: true,
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> toggleFavorite(int houseId, {required bool saved}) async {
    await _request(
      saved ? 'DELETE' : 'POST',
      '/api/v1/favorites/$houseId',
      authenticated: true,
    );
  }

  Future<List<Map<String, dynamic>>> getOwnerHouses() async {
    final data = await _request(
      'GET',
      '/api/v1/owners/me/boarding-houses',
      authenticated: true,
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createHouse(Map<String, dynamic> data) async =>
      await _request(
        'POST',
        '/api/v1/boarding-houses',
        body: data,
        authenticated: true,
      ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> uploadHouseImage(
    int houseId,
    String filename,
    Uint8List bytes,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/boarding-houses/$houseId/images'),
    );
    final token = _token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Image upload failed (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['detail'] is String) {
            message = decoded['detail'] as String;
          }
        } catch (_) {}
        throw ApiException(message, statusCode: response.statusCode);
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not upload the image. Check your connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> sendInquiry(int houseId, String message) async =>
      await _request(
        'POST',
        '/api/v1/boarding-houses/$houseId/inquiries',
        body: {'message': message},
        authenticated: true,
      ) as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> getOwnerInquiries() async {
    final data = await _request(
      'GET',
      '/api/v1/owners/me/inquiries',
      authenticated: true,
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> respondToInquiry(
    int inquiryId,
    String response,
  ) async => await _request(
    'PATCH',
    '/api/v1/inquiries/$inquiryId/response',
    body: {'response': response},
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateHouse(
    int id,
    Map<String, dynamic> data,
  ) async => await _request(
    'PATCH',
    '/api/v1/boarding-houses/$id',
    body: data,
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateOwnerListingStatus(
    int id,
    String status,
  ) async => await _request(
    'PATCH',
    '/api/v1/boarding-houses/$id',
    body: {'status': status},
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<void> deleteHouse(int id) async =>
      _request('DELETE', '/api/v1/boarding-houses/$id', authenticated: true);

  Future<Map<String, dynamic>> getMe() async =>
      await _request('GET', '/api/v1/users/me', authenticated: true)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> uploadProfilePhoto(
    String filename,
    Uint8List bytes,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/users/me/photo'),
    );
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Photo upload failed (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['detail'] is String) {
            message = decoded['detail'] as String;
          }
        } catch (_) {}
        if (response.statusCode == 401) logout();
        throw ApiException(message, statusCode: response.statusCode);
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      user = result;
      return result;
    } on ApiException {
      rethrow;
    } catch (error) {
      if (error is http.ClientException) {
        throw const ApiException(
          'Could not reach the BoardMap API to upload the photo.',
        );
      }
      rethrow;
    }
  }

  Future<void> deleteProfilePhoto() async {
    await _request('DELETE', '/api/v1/users/me/photo', authenticated: true);
    if (user != null) user = {...user!, 'profile_photo_url': null};
  }

  Future<Map<String, dynamic>> updateMe({
    required String fullName,
    required String email,
    String? contactNumber,
  }) async {
    final result = await _request(
      'PATCH',
      '/api/v1/users/me',
      body: {
        'full_name': fullName,
        'email': email,
        ...?(contactNumber == null ? null : {'contact_number': contactNumber}),
      },
      authenticated: true,
    ) as Map<String, dynamic>;
    user = result;
    return result;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      'PATCH',
      '/api/v1/users/me/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> submitIssueReport({
    required String category,
    required String subject,
    required String description,
    String? filename,
    Uint8List? attachment,
  }) async {
    final token = _token;
    if (token == null) {
      throw const ApiException(
        'Please sign in to submit a report.',
        statusCode: 401,
      );
    }
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/reports'))
          ..headers['Authorization'] = 'Bearer $token'
          ..fields.addAll({
            'category': category,
            'subject': subject,
            'description': description,
          });
    if (filename != null && attachment != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', attachment, filename: filename),
      );
    }
    final response = await _sendMultipart(
      request,
      action: 'submit your report',
    );
    return response as Map<String, dynamic>;
  }

  Future<dynamic> _sendMultipart(
    http.MultipartRequest request, {
    required String action,
  }) async {
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Unable to $action. Please try again.';
        try {
          final detail = jsonDecode(response.body)['detail'];
          if (detail is String) message = detail;
          if (detail is List) {
            message = detail.map((e) => e['msg'] ?? e.toString()).join('\n');
          }
        } catch (_) {}
        if (response.statusCode == 401) logout();
        throw ApiException(message, statusCode: response.statusCode);
      }
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Could not reach the BoardMap API to $action.');
    }
  }

  Future<Map<String, dynamic>> getMyIssueReports({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (status != null && status != 'All') query['status'] = status;
    if (search != null && search.trim().isNotEmpty) query['q'] = search.trim();
    return await _request(
      'GET',
      '/api/v1/reports/my',
      query: query,
      authenticated: true,
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getIssueReport(int id) async =>
      await _request('GET', '/api/v1/reports/$id', authenticated: true)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> replyToIssueReport(
    int id,
    String message,
  ) async => await _request(
    'POST',
    '/api/v1/reports/$id/messages',
    body: {'message': message},
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<Uint8List> getIssueReportAttachment(int id) async {
    final headers = <String, String>{'Authorization': 'Bearer $_token'};
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/v1/reports/$id/attachment'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Unable to load the report attachment.';
        try {
          final detail = jsonDecode(response.body)['detail'];
          if (detail is String) message = detail;
        } catch (_) {}
        if (response.statusCode == 401) logout();
        throw ApiException(message, statusCode: response.statusCode);
      }
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Could not load the report attachment.');
    }
  }

  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    final data = await _request(
      'GET',
      '/api/v1/notifications/my',
      authenticated: true,
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> markNotificationRead(int id) async {
    await _request(
      'PATCH',
      '/api/v1/notifications/$id/read',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> getAdminSummary() async =>
      await _request('GET', '/api/v1/admin/summary', authenticated: true)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> getAdminActivity({
    int page = 1,
    int pageSize = 20,
  }) async => await _request(
    'GET',
    '/api/v1/admin/activity',
    query: {'page': '$page', 'page_size': '$pageSize'},
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getAdminIssueReportStatistics() async =>
      await _request(
        'GET',
        '/api/v1/admin/reports/statistics',
        authenticated: true,
      ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getAdminIssueReports({
    String? status,
    String? category,
    String? search,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (status != null && status != 'All') query['status'] = status;
    if (category != null && category != 'All') query['category'] = category;
    if (search != null && search.trim().isNotEmpty) query['q'] = search.trim();
    if (startDate != null) query['start_date'] = startDate;
    if (endDate != null) query['end_date'] = endDate;
    return await _request(
      'GET',
      '/api/v1/admin/reports',
      query: query,
      authenticated: true,
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdminIssueReport(int id) async =>
      await _request('GET', '/api/v1/admin/reports/$id', authenticated: true)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateAdminIssueReportStatus(
    int id,
    String status, {
    String? remarks,
  }) async => await _request(
    'PATCH',
    '/api/v1/admin/reports/$id/status',
    body: {'status': status, 'remarks': remarks},
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> respondToAdminIssueReport(
    int id,
    String message,
  ) async => await _request(
    'POST',
    '/api/v1/admin/reports/$id/respond',
    body: {'message': message},
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    const pageSize = 100;
    final users = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final data = await _request(
        'GET',
        '/api/v1/admin/users',
        query: {'page': '$page', 'page_size': '$pageSize'},
        authenticated: true,
      );
      final rows = (data as List).cast<Map<String, dynamic>>();
      users.addAll(rows);
      if (rows.length < pageSize) return users;
      page++;
    }
  }

  Future<List<Map<String, dynamic>>> getAdminListings() async {
    final data = await _request(
      'GET',
      '/api/v1/admin/listings',
      authenticated: true,
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateAdminListingStatus(
    int id,
    String status, {
    String? reason,
  }) async => await _request(
    'PATCH',
    '/api/v1/admin/listings/$id/status',
    body: {'status': status, 'reason': reason},
    authenticated: true,
  ) as Map<String, dynamic>;

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Request failed (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          final detail = decoded['detail'];
          if (detail is String) message = detail;
          if (detail is List) {
            message = detail.map((e) => e['msg'] ?? e.toString()).join('\n');
          }
        } catch (_) {}
        if (response.statusCode == 401) logout();
        throw ApiException(message, statusCode: response.statusCode);
      }
      if (response.statusCode == 204 || response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } catch (error) {
      if (error is Exception && error.toString().contains('TimeoutException')) {
        throw const ApiException(
          'The BoardMap API request timed out. Please retry.',
        );
      }
      if (error is http.ClientException || error is FormatException) {
        throw const ApiException(
          'Could not reach the BoardMap API. Check that the backend is running and allows this app origin in CORS.',
        );
      }
      rethrow;
    }
  }
}
