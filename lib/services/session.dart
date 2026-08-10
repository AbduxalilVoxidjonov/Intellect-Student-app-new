import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../utils/errors.dart';
import 'device_identity.dart';
import 'push.dart';

/// Foydalanuvchi sessiyasi + tema. Ilovaning tepasida `ChangeNotifierProvider` bilan beriladi.
class Session extends ChangeNotifier {
  static const _kToken = 'token';
  static const _kUser = 'user';
  static const _kTheme = 'student_theme';
  static const _kFaceRequired = 'face_required';
  static const _kFaceStatus = 'face_status';

  String? _token;
  Map<String, dynamic>? _user;
  bool _dark = false;
  bool _ready = false;
  bool _faceRequired = false;
  String? _faceStatus;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthed => _token != null;
  bool get isDark => _dark;
  bool get ready => _ready;

  /// YUZ TASDIQLASH KUTILMOQDA — token bor, lekin u CHEKLANGAN (15 daqiqa,
  /// faqat `/student/face/*`). Ilova qobiq (Shell) o'rniga selfi ekranini
  /// ko'rsatadi.
  ///
  /// ⚠️ Bu holat DISKKA yoziladi: foydalanuvchi tekshiruv o'rtasida ilovani
  /// yopsa, qayta ochilganda yana selfi ekrani chiqishi kerak. Aks holda
  /// cheklangan token bilan qobiq ochilar va HAR BIR so'rov 401 bo'lardi.
  bool get faceRequired => _faceRequired;

  /// `enroll` — etalon hali yo'q (profil rasmidan olinadi), `verify` — bor.
  String? get faceStatus => _faceStatus;

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

  /// Rol: `student` | `parent`. Qiymat NORMALLASHTIRILADI va faqat shu ikkitadan
  /// biri qaytadi. Default `student` saqlab qolindi, chunki u hech qanday RUXSAT
  /// bermaydi — ilovaga kirish huquqi login/init dagi fail-closed tekshiruvida
  /// hal qilinadi, bu getter esa faqat UI ni tanlaydi (dashboard `!= 'parent'`).
  /// Normalizatsiya kerak: `PARENT` kabi qiymat login tekshiruvidan o'tadi,
  /// lekin xom holda `!= 'parent'` bo'lib ota-onaga o'quvchi ekrani ochilardi.
  String get role {
    final r = _user?['role']?.toString().trim().toLowerCase();
    return r == 'parent' ? 'parent' : 'student';
  }

  /// Rol shu ilovaga mos keladimi — FAIL-CLOSED.
  /// Backend `role` ni HAR DOIM yuboradi (`UserDto.Role` non-nullable, DB'da
  /// NOT NULL) va u kichik harfda: `student`/`teacher`/`admin`/`superadmin`/
  /// `staff`. Shuning uchun rol umuman kelmasa, `null` bo'lsa yoki String
  /// bo'lmasa — bu KUTILMAGAN holat va biz KIRITMAYMIZ.
  /// (`parent` backendda hozircha yo'q, kelajakka zaxira sifatida qoldirilgan.)
  static bool _roleAllowed(Object? raw) {
    final role = raw?.toString().trim().toLowerCase();
    return role == 'student' || role == 'parent';
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString(_kToken);
    final u = p.getString(_kUser);
    if (u != null) {
      try {
        _user = jsonDecode(u) as Map<String, dynamic>;
      } catch (_) {}
    }
    // Saqlangan sessiyani ham tekshiramiz: rol mos kelmasa (yoki `user` yozuvi
    // buzilgan bo'lib rolni umuman o'qib bo'lmasa) sessiyani TOZALAYMIZ.
    // Aks holda login'dagi qat'iy tekshiruvni disk orqali chetlab o'tish mumkin
    // bo'lardi. `logout()` chaqirilmaydi — u PushService/Firebase ga tegadi,
    // ishga tushish paytida esa bu keraksiz; shunchaki holatni tozalaymiz.
    if (_token != null && !_roleAllowed(_user?['role'])) {
      _token = null;
      _user = null;
      await p.remove(_kToken);
      await p.remove(_kUser);
    }
    if (_token != null) {
      _faceRequired = p.getBool(_kFaceRequired) ?? false;
      _faceStatus = p.getString(_kFaceStatus);
    }
    _dark = p.getString(_kTheme) == 'dark';
    ApiClient.token = _token;
    ApiClient.onUnauthorized = _onUnauthorized;
    ApiClient.onFaceRequired = _onFaceRequired;
    _ready = true;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final res = await ApiClient.dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
        // QURILMA — server "bu telefonda ilgari kirilganmi" ni shundan biladi.
        // Yuborilmasa yuz tekshiruvi UMUMAN so'ralmaydi (server eski
        // ilovalarni shu tarzda ajratadi), ya'ni bu maydonlar himoyaning
        // ishlashi uchun SHART.
        ...await DeviceIdentity.fields(),
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
      // `user` kutilmagan turda kelsa (String, List) — `null` bo'ladi va quyidagi
      // rol tekshiruvi sessiyani OCHMAYDI (fail-closed).
      final raw = data['user'];
      final user = raw is Map ? raw.cast<String, dynamic>() : null;
      // Faqat o'quvchi (va zaxira sifatida ota-ona) rolini bu ilovaga kiritamiz.
      // Backend rolni kafolatlaydi, shuning uchun rol kelmasa yoki mos kelmasa —
      // KIRITMAYMIZ (fail-closed).
      if (!_roleAllowed(user?['role'])) {
        return 'Bu ilova faqat o\'quvchilar uchun';
      }
      // Yangi qurilma — server CHEKLANGAN token berdi va selfi kutmoqda.
      // `faceRequired` kelmasa (eski server) hammasi avvalgidek ishlaydi.
      final needFace = data['faceRequired'] == true;
      final faceStatus = data['faceStatus'];
      await _persist(
        token,
        user,
        faceRequired: needFace,
        faceStatus: needFace ? (faceStatus is String ? faceStatus : null) : null,
      );
      return null; // muvaffaqiyat
    } catch (e) {
      // `on Exception` EMAS: `Error` turidagi xatolar ham ushlansin va foydalanuvchi
      // texnik matn o'rniga tushunarli sabab ko'rsin.
      return humanError(e, 'Serverga ulanib bo\'lmadi. Internetni tekshiring.');
    }
  }

  /// Yuz tekshiruvi MUVAFFAQIYATLI tugadi — server TO'LIQ token berdi.
  /// Shundan keyin ilova odatdagidek ochiladi.
  Future<void> completeFace(String token) async {
    await _persist(token, _user);
  }

  /// Cheklangan token bilan boshqa endpointga so'rov ketdi (401 `faceRequired`).
  /// Sessiya TUGATILMAYDI — foydalanuvchi selfi ekraniga qaytariladi.
  void _onFaceRequired() {
    if (_faceRequired || _token == null) return;
    _faceRequired = true;
    notifyListeners();
    // Diskka yozish fon rejimida — bu yerda kutib turishning ma'nosi yo'q
    // (ekran allaqachon almashishi kerak).
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kFaceRequired, true))
        .catchError((Object _) => false);
  }

  Future<void> _persist(
    String token,
    Map<String, dynamic>? user, {
    bool faceRequired = false,
    String? faceStatus,
  }) async {
    _token = token;
    _user = user;
    _faceRequired = faceRequired;
    _faceStatus = faceStatus;
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
    if (faceRequired) {
      await p.setBool(_kFaceRequired, true);
      if (faceStatus != null) {
        await p.setString(_kFaceStatus, faceStatus);
      } else {
        await p.remove(_kFaceStatus);
      }
    } else {
      await p.remove(_kFaceRequired);
      await p.remove(_kFaceStatus);
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
    _faceRequired = false;
    _faceStatus = null;
    ApiClient.token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
    await p.remove(_kFaceRequired);
    await p.remove(_kFaceStatus);
    // ⚠️ `device_id` O'CHIRILMAYDI — u qurilmaning identifikatori, sessiyaniki
    // emas. Har chiqishda yangilansa, har kirishda yangi qurilma deb selfi
    // so'ralaverardi.
    notifyListeners();
  }

  Future<void> setDark(bool v) async {
    _dark = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, v ? 'dark' : 'light');
    notifyListeners();
  }
}
