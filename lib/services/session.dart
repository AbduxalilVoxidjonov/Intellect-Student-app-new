import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../utils/errors.dart';
import 'push.dart';

/// Foydalanuvchi sessiyasi + tema. Ilovaning tepasida `ChangeNotifierProvider` bilan beriladi.
class Session extends ChangeNotifier {
  static const _kToken = 'token';
  static const _kUser = 'user';
  static const _kTheme = 'student_theme';

  String? _token;
  Map<String, dynamic>? _user;
  bool _dark = false;
  bool _ready = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthed => _token != null;
  bool get isDark => _dark;
  bool get ready => _ready;

  /// `user` maydonini XAVFSIZ o'qiydi: `as String?` cast'i turi mos kelmasa
  /// `TypeError` (Error!) berardi va bu getterlar `build()` ichidan chaqilgani
  /// uchun ekran butunlay qulardi. Endi noto'g'ri tur oddiygina `null` bo'ladi.
  String? _str(String key) {
    final v = _user?[key];
    return v is String ? v : null;
  }

  String get fullName => _str('fullName') ?? '';

  /// Tokendagi FOYDALANUVCHI id'si (Student.Id EMAS — parent rolida umuman boshqa yozuv).
  /// Chatda "o'zimning xabarim"ni aniqlashda ishlatiladi; API'ga `studentId` sifatida
  /// BERILMAYDI — server o'quvchini tokenning o'zidan aniqlaydi.
  String? get userId => _str('id');

  /// Rol: `student` | `parent`.
  String get role => _str('role') ?? 'student';

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString(_kToken);
    final u = p.getString(_kUser);
    if (u != null) {
      try {
        _user = jsonDecode(u) as Map<String, dynamic>;
      } catch (_) {}
    }
    _dark = p.getString(_kTheme) == 'dark';
    ApiClient.token = _token;
    ApiClient.onUnauthorized = _onUnauthorized;
    _ready = true;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final res = await ApiClient.dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
      });
      if (!ApiClient.ok(res)) {
        return ApiClient.errorMessage(res, "Login yoki parol noto'g'ri");
      }
      // `as` cast QILMAYMIZ: server 200 bilan JSON massiv yoki HTML (proxy sahifasi)
      // qaytarsa cast `TypeError` berardi — bu `Error`, `Exception` EMAS, ya'ni
      // quyidagi `catch` ham, ekrandagi `try` ham uni ushlamay ilova qulardi.
      final data = res.data;
      if (data is! Map) return 'Server javobi noto\'g\'ri';
      final token = data['token'];
      if (token is! String || token.isEmpty) return 'Server javobi noto\'g\'ri';
      // `user` kutilmagan turda kelsa (String, List) — shunchaki e'tiborsiz qoldiramiz,
      // token bor ekan sessiya ochilaveradi (ism keyin `/student/me` dan keladi).
      final raw = data['user'];
      final user = raw is Map ? raw.cast<String, dynamic>() : null;
      // Faqat o'quvchi rolini bu ilovaga kiritamiz.
      final role = user?['role'];
      if (role is String && role != 'student' && role != 'parent') {
        return 'Bu ilova faqat o\'quvchilar uchun';
      }
      await _persist(token, user);
      return null; // muvaffaqiyat
    } catch (e) {
      // `on Exception` EMAS: `Error` turidagi xatolar ham ushlansin va foydalanuvchi
      // texnik matn o'rniga tushunarli sabab ko'rsin.
      return humanError(e, 'Serverga ulanib bo\'lmadi. Internetni tekshiring.');
    }
  }

  Future<void> _persist(String token, Map<String, dynamic>? user) async {
    _token = token;
    _user = user;
    ApiClient.token = token;
    // Yangi sessiya — 401 qorovulini tiklaymiz, aks holda oldingi sessiyada
    // ishlagan dedublikatsiya bayrog'i keyingi 401 ni "yeb" qo'yardi.
    ApiClient.resetUnauthorizedGuard();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (user != null) {
      await p.setString(_kUser, jsonEncode(user));
    } else {
      // MUHIM: `user` kelmasa eski yozuvni O'CHIRAMIZ. Aks holda diskda yangi
      // token + oldingi foydalanuvchining ismi/id'si qolib ketardi.
      await p.remove(_kUser);
    }
    notifyListeners();
  }

  void _onUnauthorized() {
    // Server tokeni yaroqsiz — qurilma tokenini o'chirishga urinmaymiz,
    // aks holda DELETE yana 401 qaytarib logout'ni qayta chaqirardi.
    logout(revokeDevice: false);
  }

  /// Ketayotgan logout — `bool` bayroq o'rniga FUTURE keshi: ikkinchi chaqiruv
  /// birinchisining natijasini kutadi (bayroq bilan u darrov qaytib ketar va
  /// chaqiruvchi tozalash tugamasdan davom etardi).
  Future<void>? _loggingOut;

  /// [revokeDevice] — push qurilma tokenini serverdan o'chirish. Sessiya 401 bilan
  /// tugaganda `false` beriladi (so'rov baribir o'tmaydi).
  Future<void> logout({bool revokeDevice = true}) =>
      _loggingOut ??= _doLogout(revokeDevice).whenComplete(() => _loggingOut = null);

  Future<void> _doLogout(bool revokeDevice) async {
    // Token hali o'chirilmasdan chaqiriladi — DELETE avtorizatsiya talab qiladi.
    await PushService.stop(revoke: revokeDevice);
    _token = null;
    _user = null;
    ApiClient.token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
    notifyListeners();
  }

  Future<void> setDark(bool v) async {
    _dark = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, v ? 'dark' : 'light');
    notifyListeners();
  }
}
