import 'package:dio/dio.dart';

/// Har qanday xatoni FOYDALANUVCHI o'qiy oladigan o'zbekcha matnga aylantiradi.
///
/// Ilgari ekranlar `e.toString()` ni ko'rsatardi va foydalanuvchi
/// `DioException [bad response]: ... https://crm.intellectschool.uz/api/...`
/// degan matnni ko'rardi — tushunarsiz va infratuzilmani oshkor qiladi.
/// YAGONA joy: har bir ekranda alohida yozilmasin.
String humanError(Object? e, [String fallback = 'Xatolik yuz berdi']) {
  if (e == null) return fallback;

  if (e is DioException) {
    // Server javob bergan (4xx/5xx) — avval serverning o'z xabarini olamiz.
    final res = e.response;
    if (res != null) {
      final data = res.data;
      if (data is Map && data['message'] is String) {
        final m = (data['message'] as String).trim();
        if (m.isNotEmpty) return m;
      }
      final code = res.statusCode ?? 0;
      if (code >= 500) return "Serverda xatolik. Birozdan keyin urinib ko'ring.";
      if (code == 401 || code == 403) return "Bu ma'lumotga ruxsat yo'q.";
      if (code == 404) return "Ma'lumot topilmadi.";
      return fallback;
    }
    // Javob umuman kelmagan — tarmoq/vaqt muammosi.
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Server javob bermadi. Internetni tekshiring.',
      DioExceptionType.cancel => fallback,
      _ => "Serverga ulanib bo'lmadi. Internetni tekshiring.",
    };
  }

  // `Exception('...')` — StudentApi shu ko'rinishda tashlaydi; prefiksni olib tashlaymiz.
  if (e is Exception) {
    final s = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    // Dart ichki xato matnlari (masalan `TypeError`, `_CastError`) foydalanuvchiga
    // hech narsa anglatmaydi — ularni umumiy matn bilan almashtiramiz.
    if (s.isEmpty || _isInternal(s)) return fallback;
    return s;
  }

  // `Error` (TypeError, RangeError, ...) — bu DASTUR xatosi, matni ko'rsatilmaydi.
  return fallback;
}

bool _isInternal(String s) =>
    s.contains('is not a subtype of') ||
    s.contains('Null check operator') ||
    s.contains('RangeError') ||
    s.contains('type cast');
