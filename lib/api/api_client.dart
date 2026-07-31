import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

/// Markaziy Dio klienti — web `client.ts` bilan bir xil mantiq:
/// har so'rovga `Bearer <token>`; 401 (login'dan tashqari) → sessiya tugadi.
class ApiClient {
  static String? token;
  static VoidCallback? onUnauthorized;

  static final Dio dio = _build();

  static Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // 4xx'ni ham qabul qilamiz — xatoni o'zimiz o'qiymiz.
      validateStatus: (s) => s != null && s < 500,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final code = response.statusCode ?? 0;
        final isLogin = response.requestOptions.path.contains('/auth/login');
        if (code == 401 && !isLogin) {
          onUnauthorized?.call();
        }
        handler.next(response);
      },
    ));
    return d;
  }

  /// Javob 2xx bo'lmasa serverdagi `message`ni yoki umumiy xatoni chiqaradi.
  static String errorMessage(Response? res, [Object? fallback]) {
    final data = res?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback?.toString() ?? 'Xatolik yuz berdi';
  }

  static bool ok(Response res) {
    final c = res.statusCode ?? 0;
    return c >= 200 && c < 300;
  }
}
