import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/api/api_client.dart';
import 'package:student/services/session.dart';

import 'fake_adapter.dart';

const Map<String, dynamic> _studentUser = {
  'id': 'u1',
  'fullName': 'Ali Valiyev',
  'role': 'student',
};

String _loginOk({Map<String, dynamic> user = _studentUser, String token = 'jwt-1'}) =>
    jsonEncode({'token': token, 'user': user});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    resetApiClient();
  });

  tearDown(resetApiClient);

  // -------------------------------------------------------------------------
  group('init()', () {
    test('bo\'sh SharedPreferences — sessiya yo\'q, lekin ready = true', () async {
      final s = Session();
      expect(s.ready, isFalse);

      await s.init();

      expect(s.ready, isTrue);
      expect(s.isAuthed, isFalse);
      expect(s.token, isNull);
      expect(s.user, isNull);
      expect(s.isDark, isFalse);
      expect(ApiClient.token, isNull);
      expect(ApiClient.onUnauthorized, isNotNull, reason: '401 ilgagi o\'rnatilishi shart');
    });

    test('token + user saqlangan — tiklanadi va ApiClient ga uzatiladi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': 'jwt-saved',
        'user': jsonEncode(_studentUser),
        'student_theme': 'dark',
      });

      final s = Session();
      await s.init();

      expect(s.isAuthed, isTrue);
      expect(s.token, 'jwt-saved');
      expect(s.fullName, 'Ali Valiyev');
      expect(s.userId, 'u1');
      expect(s.role, 'student');
      expect(s.isDark, isTrue);
      expect(ApiClient.token, 'jwt-saved');
    });

    test('buzilgan JSON `user` — xato YUTILADI, ilova qulamaydi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': 'jwt-saved',
        'user': '{buzilgan json',
      });

      final s = Session();
      await expectLater(s.init(), completes);

      expect(s.ready, isTrue);
      // Token bor, lekin user yo'q — foydalanuvchi "ismsiz" holda ichkarida qoladi.
      expect(s.isAuthed, isTrue);
      expect(s.user, isNull);
      expect(s.fullName, '');
      expect(s.userId, isNull);
      expect(s.role, 'student', reason: 'default `student`');
    });

    test('`user` JSON massiv — cast xatosi ham yutiladi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'user': '[]'});

      final s = Session();
      await expectLater(s.init(), completes);

      expect(s.user, isNull);
    });

    test('theme `light`/yo\'q — isDark false', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'student_theme': 'light'});

      final s = Session();
      await s.init();

      expect(s.isDark, isFalse);
    });

    test('init() bir marta notifyListeners chaqiradi', () async {
      final s = Session();
      var n = 0;
      s.addListener(() => n++);

      await s.init();

      expect(n, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('login()', () {
    test('muvaffaqiyat — null qaytadi, holat va SharedPreferences yangilanadi', () async {
      final a = install(FakeAdapter.always(FakeReply.json(_loginOk())));
      final s = Session();
      await s.init();

      final err = await s.login('  ali@mail.uz  ', 'secret');

      expect(err, isNull);
      expect(a.last.path, '/auth/login');
      expect(a.last.method, 'POST');
      expect((a.last.data as Map)['email'], 'ali@mail.uz', reason: 'email trim qilinadi');
      expect((a.last.data as Map)['password'], 'secret');

      expect(s.isAuthed, isTrue);
      expect(s.token, 'jwt-1');
      expect(s.fullName, 'Ali Valiyev');
      expect(ApiClient.token, 'jwt-1');

      final p = await SharedPreferences.getInstance();
      expect(p.getString('token'), 'jwt-1');
      expect(jsonDecode(p.getString('user')!), _studentUser);
    });

    test('parent roli ham kiritiladi', () async {
      install(FakeAdapter.always(
        FakeReply.json(_loginOk(user: {'id': 'p1', 'fullName': 'Ota', 'role': 'parent'})),
      ));
      final s = Session();

      expect(await s.login('o@mail.uz', 'x'), isNull);
      expect(s.role, 'parent');
    });

    test('rolsiz user ham kiritiladi (role == null → tekshiruv o\'tkaziladi)', () async {
      install(FakeAdapter.always(FakeReply.json(_loginOk(user: {'id': 'x', 'fullName': 'X'}))));
      final s = Session();

      expect(await s.login('a@b.c', 'x'), isNull);
      expect(s.role, 'student', reason: 'default');
    });

    test('noto\'g\'ri parol (401) — serverning matni qaytadi, sessiya ochilmaydi', () async {
      install(FakeAdapter.always(
        const FakeReply.json('{"message":"Login yoki parol xato"}', status: 401),
      ));
      final s = Session();
      await s.init();

      final err = await s.login('a@b.c', 'yomon');

      expect(err, 'Login yoki parol xato');
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
    });

    test('401 `message` siz — fallback "Login yoki parol noto\'g\'ri"', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 401)));

      expect(await Session().login('a@b.c', 'x'), "Login yoki parol noto'g'ri");
    });

    test('/auth/login dagi 401 onUnauthorized ni ISHGA TUSHIRMAYDI', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 401)));
      final s = Session();
      await s.init();
      var logouts = 0;
      s.addListener(() => logouts++);

      await s.login('a@b.c', 'x');

      expect(logouts, 0, reason: 'login xatosi sessiyani tugatmasligi kerak');
    });

    test('`token` yo\'q — "Server javobi noto\'g\'ri"', () async {
      install(FakeAdapter.always(const FakeReply.json('{"user":{"id":"u1","role":"student"}}')));
      final s = Session();

      expect(await s.login('a@b.c', 'x'), "Server javobi noto'g'ri");
      expect(s.isAuthed, isFalse);
    });

    test('roli `teacher` — rad etiladi', () async {
      install(FakeAdapter.always(
        FakeReply.json(_loginOk(user: {'id': 't1', 'fullName': 'O\'qituvchi', 'role': 'teacher'})),
      ));
      final s = Session();

      expect(await s.login('t@b.c', 'x'), "Bu ilova faqat o'quvchilar uchun");
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
    });

    test('roli `admin` — rad etiladi', () async {
      install(FakeAdapter.always(
        FakeReply.json(_loginOk(user: {'id': 'a1', 'fullName': 'Admin', 'role': 'admin'})),
      ));

      expect(await Session().login('a@b.c', 'x'), "Bu ilova faqat o'quvchilar uchun");
    });

    test('tarmoq xatosi — "Serverga ulanib bo\'lmadi..."', () async {
      install(FakeAdapter.failing());

      expect(
        await Session().login('a@b.c', 'x'),
        "Serverga ulanib bo'lmadi. Internetni tekshiring.",
      );
    });

    // 5xx endi dio darajasida tashlanmaydi (validateStatus < 600) — serverning
    // o'z matni foydalanuvchiga yetib boradi, sabab to'g'ri ko'rsatiladi.
    test('server 500 — serverning matni qaytadi', () async {
      install(FakeAdapter.always(
        const FakeReply.json('{"message":"Baza ishlamayapti"}', status: 500),
      ));

      expect(await Session().login('a@b.c', 'x'), 'Baza ishlamayapti');
    });

    test('server 500 + `message` yo\'q — o\'zbekcha server xatosi matni', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 500)));

      expect(
        await Session().login('a@b.c', 'x'),
        "Serverda xatolik. Birozdan keyin urinib ko'ring.",
      );
    });

    // Ilgari `res.data as Map<String, dynamic>` `TypeError` berardi. TypeError —
    // `Error`, `Exception` EMAS, ya'ni `on Exception` uni ushlamas va xato
    // ekrangacha chiqib ketardi (tugma o'lik qolardi). Endi `is` tekshiruvi.
    test('200 + JSON massiv — xato TASHLANMAYDI, tushunarli matn qaytadi', () async {
      install(FakeAdapter.always(const FakeReply.json('[]')));

      final s = Session();
      expect(await s.login('a@b.c', 'x'), "Server javobi noto'g'ri");
      expect(s.isAuthed, isFalse);
    });

    test('200 + JSON bo\'lmagan tana (proxy/HTML) — "Server javobi noto\'g\'ri"', () async {
      install(FakeAdapter.always(const FakeReply.text('<html>Gateway</html>')));

      expect(await Session().login('a@b.c', 'x'), "Server javobi noto'g'ri");
    });

    test('`user` maydoni String — e\'tiborsiz qoldiriladi, sessiya token bilan ochiladi', () async {
      install(FakeAdapter.always(const FakeReply.json('{"token":"t","user":"ali"}')));

      final s = Session();
      expect(await s.login('a@b.c', 'x'), isNull);
      expect(s.isAuthed, isTrue);
      expect(s.user, isNull);
      expect(s.role, 'student', reason: 'default');
    });

    test('`token` bo\'sh satr — "Server javobi noto\'g\'ri"', () async {
      install(FakeAdapter.always(const FakeReply.json('{"token":""}')));

      expect(await Session().login('a@b.c', 'x'), "Server javobi noto'g'ri");
    });
  });

  // -------------------------------------------------------------------------
  group('_persist — eski `user` qolib ketishi', () {
    // TUZATILDI: `user` kelmasa disk yozuvi O'CHIRILADI, aks holda yangi token
    // eski foydalanuvchining ismi/id'si bilan birga tiklanardi.
    test('user siz login — eski foydalanuvchi diskdan O\'CHIRILADI', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': 'eski-token',
        'user': jsonEncode({'id': 'old', 'fullName': 'Eski Foydalanuvchi', 'role': 'student'}),
      });
      install(FakeAdapter.always(const FakeReply.json('{"token":"yangi-token"}')));

      final s = Session();
      await s.init();
      expect(s.fullName, 'Eski Foydalanuvchi');

      final err = await s.login('yangi@mail.uz', 'x');

      expect(err, isNull);
      expect(s.token, 'yangi-token');
      expect(s.fullName, '', reason: 'xotirada tozalandi');

      final p = await SharedPreferences.getInstance();
      expect(p.getString('user'), isNull, reason: 'eski user o\'chirilishi shart');

      // Ilova qayta ishga tushsa — faqat YANGI token tiklanadi, begona ism yo'q.
      final s2 = Session();
      await s2.init();
      expect(s2.token, 'yangi-token');
      expect(s2.fullName, '');
      expect(s2.userId, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('logout()', () {
    // DIQQAT: `logout()` → `PushService.stop()` → Firebase. `revoke: false` da
    // `stop()` Firebase ga UMUMAN murojaat qilmaydi; `revoke: true` da esa
    // `Firebase.apps` chaqiruvi PushService ichidagi try/catch bilan o'ralgan.
    // Shuning uchun bu testlar Firebase o'rnatilmagan muhitda ham o'tishi kerak.
    // Agar kelajakda Firebase SDK o'zgarib xato tashlasa — bu testlar yiqiladi,
    // bu esa DI yo'qligining (PushService qattiq bog'langan) bevosita natijasi.
    test('holatni to\'liq tozalaydi va SharedPreferences dan o\'chiradi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': 'jwt',
        'user': jsonEncode(_studentUser),
        'student_theme': 'dark',
      });
      final s = Session();
      await s.init();

      await s.logout(revokeDevice: false);

      expect(s.isAuthed, isFalse);
      expect(s.token, isNull);
      expect(s.user, isNull);
      expect(s.fullName, '');
      expect(s.userId, isNull);
      expect(ApiClient.token, isNull);

      final p = await SharedPreferences.getInstance();
      expect(p.getString('token'), isNull);
      expect(p.getString('user'), isNull);
      expect(p.getString('student_theme'), 'dark', reason: 'tema saqlanib qoladi');
    });

    test('`_loggingOut` qorovuli — parallel chaqiruv ikkinchi marta ishlamaydi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'token': 'jwt'});
      final s = Session();
      await s.init();
      var n = 0;
      s.addListener(() => n++);

      final f1 = s.logout(revokeDevice: false);
      final f2 = s.logout(revokeDevice: false); // hali birinchisi tugamagan
      await Future.wait([f1, f2]);

      expect(n, 1, reason: 'faqat bitta logout bajarildi');
      expect(s.isAuthed, isFalse);
    });

    test('sessiyasiz logout xatosiz o\'tadi', () async {
      final s = Session();
      await s.init();

      await expectLater(s.logout(revokeDevice: false), completes);
      expect(s.isAuthed, isFalse);
    });

    test('401 → onUnauthorized → sessiya tugaydi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': 'jwt',
        'user': jsonEncode(_studentUser),
      });
      final s = Session();
      await s.init();
      expect(s.isAuthed, isTrue);

      install(FakeAdapter.always(const FakeReply.json('{}', status: 401)));
      await ApiClient.dio.get('/student/dashboard');
      // logout() await qilinmasdan chaqiriladi — bajarilishini kutamiz.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('token'), isNull);
    });

    // `ApiClient` darajasidagi dedublikatsiya + `_loggingOut` future keshi:
    // nechta 401 kelishidan qat'i nazar sessiya BIR MARTA tugatiladi.
    test('parallel 401 lar — natija bitta logout', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'token': 'jwt'});
      final s = Session();
      await s.init();
      var n = 0;
      s.addListener(() => n++);

      install(FakeAdapter.always(const FakeReply.json('{}', status: 401)));
      await Future.wait([
        ApiClient.dio.get('/student/dashboard'),
        ApiClient.dio.get('/student/grades'),
        ApiClient.dio.get('/student/finance'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(s.isAuthed, isFalse);
      expect(n, 1, reason: 'sessiya bir marta tugatiladi');
    });
  });

  // -------------------------------------------------------------------------
  group('setDark()', () {
    test('true — `dark` saqlanadi va xabar beriladi', () async {
      final s = Session();
      await s.init();
      var n = 0;
      s.addListener(() => n++);

      await s.setDark(true);

      expect(s.isDark, isTrue);
      expect(n, 1);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('student_theme'), 'dark');
    });

    test('false — `light` saqlanadi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'student_theme': 'dark'});
      final s = Session();
      await s.init();

      await s.setDark(false);

      expect(s.isDark, isFalse);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('student_theme'), 'light');
    });

    test('tema logout dan keyin ham saqlanadi', () async {
      final s = Session();
      await s.init();
      await s.setDark(true);

      await s.logout(revokeDevice: false);

      final s2 = Session();
      await s2.init();
      expect(s2.isDark, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('getterlar', () {
    test('user null — barcha getterlar xavfsiz default', () async {
      final s = Session();
      await s.init();

      expect(s.fullName, '');
      expect(s.userId, isNull);
      expect(s.role, 'student');
      expect(s.isAuthed, isFalse);
    });

    test('user maydonlari noto\'g\'ri turda — getterlar xato TASHLAMAYDI', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user': jsonEncode({'id': 123, 'fullName': 42, 'role': 7}),
      });
      final s = Session();
      await s.init();

      // Ilgari `as String?` cast'i `TypeError` (Error!) berardi — bu getterlar
      // `build()` ichidan chaqirilgani uchun butun ekran qulardi.
      expect(s.fullName, '');
      expect(s.userId, isNull);
      expect(s.role, 'student');
    });
  });
}
