import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

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

  String get fullName => (_user?['fullName'] as String?) ?? '';
  String? get studentId => _user?['id'] as String?;

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
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      final user = (data['user'] as Map?)?.cast<String, dynamic>();
      if (token == null) return 'Server javobi noto\'g\'ri';
      // Faqat o'quvchi rolini bu ilovaga kiritamiz.
      final role = user?['role'] as String?;
      if (role != null && role != 'student' && role != 'parent') {
        return 'Bu ilova faqat o\'quvchilar uchun';
      }
      await _persist(token, user);
      return null; // muvaffaqiyat
    } on Exception {
      return 'Serverga ulanib bo\'lmadi. Internetni tekshiring.';
    }
  }

  Future<void> _persist(String token, Map<String, dynamic>? user) async {
    _token = token;
    _user = user;
    ApiClient.token = token;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (user != null) await p.setString(_kUser, jsonEncode(user));
    notifyListeners();
  }

  void _onUnauthorized() {
    logout();
  }

  Future<void> logout() async {
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
