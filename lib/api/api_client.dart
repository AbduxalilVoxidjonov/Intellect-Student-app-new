import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

/// Markaziy Dio klienti — web `client.ts` bilan bir xil mantiq:
/// har so'rovga `Bearer <token>`; 401 (login'dan tashqari) → sessiya tugadi.
class ApiClient {
  static String? token;
  static VoidCallback? onUnauthorized;

  /// 401 DEDUBLIKATSIYASI: bir vaqtda ketgan N ta so'rov N marta 401 qaytaradi.
  /// Har biri uchun `onUnauthorized` chaqirilsa — N marta logout (va N marta
  /// ekran almashishi) bo'lardi. Sessiya bir marta tugatiladi; keyingi
  /// muvaffaqiyatli login bayroqni tiklaydi.
  static bool _unauthorizedFired = false;

  /// Bayroqni tiklaydi — muvaffaqiyatli login'dan keyin (va testlar orasida).
  static void resetUnauthorizedGuard() => _unauthorizedFired = false;

  static final Dio dio = _build();

  static Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // HECH QANDAY holat kodi uchun dio o'zi xato tashlamasin: 4xx ham, 5xx ham
      // bizga `Response` bo'lib keladi va xatoni `errorMessage`/`_fail` o'qiydi.
      // Ilgari `s < 500` edi — 5xx da dio xom `DioException` tashlar, ekranlarga
      // esa inglizcha "DioException [bad response]: ..." matni chiqib ketardi.
      validateStatus: (s) => s != null && s < 600,
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
        if (isLogin && code >= 200 && code < 300) {
          // Yangi sessiya boshlandi — keyingi 401 yana ushlanishi kerak.
          _unauthorizedFired = false;
        } else if (code == 401 && !isLogin && !_unauthorizedFired) {
          final cb = onUnauthorized;
          // Bayroq FAQAT haqiqatan chaqirilganda yoqiladi — aks holda ilova
          // hali ilgak o'rnatmagan paytdagi 401 keyingisini "yeb" qo'yardi.
          if (cb != null) {
            _unauthorizedFired = true;
            cb();
          }
        }
        handler.next(response);
      },
    ));
    return d;
  }

  /// Javob 2xx bo'lmasa serverdagi `message`ni yoki umumiy xatoni chiqaradi.
  static String errorMessage(Response? res, [Object? fallback]) {
    final data = res?.data;
    if (data is Map && data['message'] is String) {
      final m = (data['message'] as String).trim();
      if (m.isNotEmpty) return m;
    }
    // 5xx endi shu yerga yetib keladi (validateStatus 600) — server matni
    // bo'lmasa ham foydalanuvchi tushunarli o'zbekcha sabab ko'rsin.
    final code = res?.statusCode ?? 0;
    if (code >= 500) return "Serverda xatolik. Birozdan keyin urinib ko'ring.";
    return fallback?.toString() ?? 'Xatolik yuz berdi';
  }

  static bool ok(Response res) {
    final c = res.statusCode ?? 0;
    return c >= 200 && c < 300;
  }
}
