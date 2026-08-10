import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// QURILMA IDENTIFIKATORI — "bu telefonda ilgari kirilganmi?" savolining javobi.
///
/// NEGA KERAK: yuz bilan tasdiqlash faqat YANGI qurilmada so'raladi. Server
/// ishonchli qurilmalar ro'yxatini `deviceId` bo'yicha yuritadi, ya'ni bu qiymat
/// **bir marta yaratilib abadiy saqlanishi** shart — har login'da yangisi
/// yaratilsa har safar selfi so'ralaverardi.
///
/// ⚠️ ANDROID_ID / IMEI kabi tizim identifikatorlari ATAYIN ishlatilmaydi:
/// ular Play Store siyosatida "qat'iy identifikator" hisoblanadi va ruxsat
/// talab qiladi. Bizga qurilmani BOSHQA ilovalar bilan bog'lash kerak emas —
/// faqat "shu ilovaning shu o'rnatilishi" ni ajratsa yetadi.
///
/// Saqlash joyi — `SharedPreferences` (sessiya tokeni bilan bir xil joy).
/// Ilova o'chirilib qayta o'rnatilsa qiymat yo'qoladi va foydalanuvchidan
/// selfi so'raladi — bu KUTILGAN xatti-harakat (yangi o'rnatish = yangi qurilma).
class DeviceIdentity {
  DeviceIdentity._();

  static const String _kKey = 'device_id';

  /// Disk o'qishlari takrorlanmasin (login + har `verify` da kerak bo'ladi).
  static String? _cached;

  /// Testlar uchun: keshni tozalaydi (har test o'z `SharedPreferences` i bilan).
  static void resetCache() => _cached = null;

  /// Qurilma identifikatori. Yo'q bo'lsa yaratiladi va saqlanadi.
  ///
  /// Format — 32 ta o'n oltilik belgi (128 bit, `Random.secure`), ya'ni UUID
  /// bilan bir xil entropiya. Tashqi paket qo'shilmagan: bizga faqat
  /// takrorlanmaydigan tasodifiy satr kerak.
  static Future<String> id() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_kKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return _cached = saved.trim();
    }
    final fresh = _randomHex(16);
    await p.setString(_kKey, fresh);
    return _cached = fresh;
  }

  /// Platforma — server `android`/`ios` ni kutadi (Play Integrity yo'nalishi
  /// shunga qarab tanlanadi). Boshqa platformalarda xom nom yuboriladi.
  static String get platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  /// Adminga ko'rinadigan qurilma nomi.
  ///
  /// ⚠️ HALOL CHEGARA: bu MODEL nomi emas (`Redmi Note 12` emas) — model uchun
  /// `device_info_plus` paketi kerak bo'lardi. Qurilmani ajratish vazifasini
  /// [id] bajaradi, bu qator esa faqat ro'yxatni o'qish uchun ("Android 13").
  static String get name {
    if (kIsWeb) return 'Web';
    final v = Platform.operatingSystemVersion.trim();
    final os = platform;
    if (v.isEmpty) return os;
    // "Android 13 (API 33)" / "Version 17.4 (Build 21E219)" — uzun qatorni
    // qisqartiramiz, serverda bu maydon faqat ko'rsatish uchun.
    final short = v.length > 60 ? v.substring(0, 60) : v;
    return '$os $short';
  }

  /// Ilova versiyasi — `config.dart` dagi yagona manba.
  static String get appVersion => kAppVersion;

  /// Login/verify so'rovlariga qo'shiladigan maydonlar (bir joyda tursin —
  /// ikki chaqiruv joyi bir-biridan ajralib qolmasin).
  static Future<Map<String, String>> fields() async => {
        'deviceId': await id(),
        'deviceName': name,
        'platform': platform,
        'appVersion': appVersion,
      };

  static String _randomHex(int bytes) {
    final rnd = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buf.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }
}
