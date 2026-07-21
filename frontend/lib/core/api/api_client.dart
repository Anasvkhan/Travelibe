import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ApiClient {
  late final Dio dio;
  static const String baseUrl = 'http://192.168.18.54:9000/api';

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Request interception for Authorization and Idempotency
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Apply idempotency key on mutating operations
        if (['POST', 'PUT', 'PATCH', 'DELETE'].contains(options.method)) {
          // Check if custom idempotency key is already set, else generate one
          options.headers['Idempotency-Key'] ??= const Uuid().v4();
        }

        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle token expiration or custom errors globally
        if (e.response?.statusCode == 401) {
          print('[ApiClient] Unauthorized API request. Action required: Relogin.');
        }
        return handler.next(e);
      },
    ));
  }

  // Helper storage operations
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}

