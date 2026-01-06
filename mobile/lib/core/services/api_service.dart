import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// API Service untuk komunikasi dengan Backend FastAPI
/// Menangani semua HTTP request (GET, POST, PUT, DELETE)
/// Otomatis menyertakan JWT token dari Supabase session
class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Base URL Configuration
  /// - Android Emulator: 10.0.2.2 (localhost dari perspektif emulator)
  /// - iOS Simulator: 127.0.0.1 atau localhost
  /// - Physical Device: IP Address laptop (harus satu WiFi)
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android Emulator menggunakan 10.0.2.2 untuk akses localhost laptop
      return 'http://10.0.2.2:8000';
    } else if (Platform.isIOS) {
      // iOS Simulator bisa langsung pakai localhost
      return 'http://127.0.0.1:8000';
    } else {
      // Default fallback
      return 'http://localhost:8000';
    }
  }

  // ============================================================
  // Token & Headers Management
  // ============================================================

  /// Ambil access token dari Supabase session
  /// Returns null jika user belum login
  String? get _accessToken {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  /// Cek apakah user sudah terautentikasi
  bool get isAuthenticated => _accessToken != null;

  /// Headers default untuk semua request
  Map<String, String> get _baseHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Headers dengan Authorization token otomatis dari Supabase
  /// Jika token tidak ada, tetap return base headers
  Map<String, String> get _headers {
    final token = _accessToken;
    if (token != null) {
      return {..._baseHeaders, 'Authorization': 'Bearer $token'};
    }
    return _baseHeaders;
  }

  /// Headers dengan custom token (override Supabase token)
  Map<String, String> _headersWithToken(String token) => {
    ..._baseHeaders,
    'Authorization': 'Bearer $token',
  };

  // ============================================================
  // HTTP Methods
  // ============================================================

  /// GET Request
  /// Token otomatis diambil dari Supabase session
  /// Atau bisa override dengan parameter [customToken]
  Future<ApiResponse> get(
    String endpoint, {
    String? customToken,
    Map<String, String>? queryParams,
  }) async {
    try {
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = customToken != null
          ? _headersWithToken(customToken)
          : _headers;

      final response = await http.get(uri, headers: headers);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// POST Request
  /// Token otomatis diambil dari Supabase session
  /// Atau bisa override dengan parameter [customToken]
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? customToken,
  }) async {
    try {
      final headers = customToken != null
          ? _headersWithToken(customToken)
          : _headers;

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// PUT Request
  /// Token otomatis diambil dari Supabase session
  Future<ApiResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? customToken,
  }) async {
    try {
      final headers = customToken != null
          ? _headersWithToken(customToken)
          : _headers;

      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// DELETE Request
  /// Token otomatis diambil dari Supabase session
  Future<ApiResponse> delete(String endpoint, {String? customToken}) async {
    try {
      final headers = customToken != null
          ? _headersWithToken(customToken)
          : _headers;

      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// PATCH Request
  /// Token otomatis diambil dari Supabase session
  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? customToken,
  }) async {
    try {
      final headers = customToken != null
          ? _headersWithToken(customToken)
          : _headers;

      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // ============================================================
  // Response Handler
  // ============================================================

  ApiResponse _handleResponse(http.Response response) {
    try {
      final dynamic data = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(data, response.statusCode);
      } else {
        String message = 'Request failed';
        if (data is Map && data.containsKey('detail')) {
          message = data['detail'].toString();
        }
        return ApiResponse.failure(message, response.statusCode, data);
      }
    } catch (e) {
      return ApiResponse.error('Failed to parse response: ${e.toString()}');
    }
  }
}

// ============================================================
// API Response Model
// ============================================================

class ApiResponse {
  final bool isSuccess;
  final dynamic data;
  final String? message;
  final int? statusCode;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.message,
    this.statusCode,
  });

  /// Factory constructor untuk response sukses
  factory ApiResponse.success(dynamic data, int statusCode) {
    return ApiResponse._(isSuccess: true, data: data, statusCode: statusCode);
  }

  /// Factory constructor untuk response gagal dari server
  factory ApiResponse.failure(String message, int statusCode, dynamic data) {
    return ApiResponse._(
      isSuccess: false,
      message: message,
      statusCode: statusCode,
      data: data,
    );
  }

  /// Factory constructor untuk error jaringan/parsing
  factory ApiResponse.error(String message) {
    return ApiResponse._(isSuccess: false, message: message);
  }

  @override
  String toString() {
    return 'ApiResponse(isSuccess: $isSuccess, statusCode: $statusCode, message: $message, data: $data)';
  }
}
