// KIRISHDA YUZ TASDIQLASH — sessiya tomoni (ekran emas):
// qurilma maydonlari, `faceRequired` holati va 401 `{faceRequired:true}` ilgagi.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/api/api_client.dart';
import 'package:student/services/device_identity.dart';
import 'package:student/services/session.dart';

import 'fake_adapter.dart';

const Map<String, dynamic> _student = {
  'id': 'u1',
  'fullName': 'Ali Valiyev',
  'role': 'student',
};

String _login({bool face = false, String? status, String token = 'jwt-1'}) => jsonEncode({
      'token': token,
      'user': _student,
      if (face) 'faceRequired': true,
      if (status != null) 'faceStatus': status,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DeviceIdentity.resetCache();
    resetApiClient();
  });

  tearDown(resetApiClient);

  // -------------------------------------------------------------------------
  group('DeviceIdentity', () {
    test('bir marta yaratiladi va SAQLANADI (har kirishda yangilanmaydi)', () async {
      final first = await DeviceIdentity.id();
      expect(first, hasLength(32));

      // Kesh tozalansa ham diskdagi qiymat qaytadi — server uchun bu AYNAN
      // shu qurilma bo'lib qolishi shart.
      DeviceIdentity.resetCache();
      expect(await DeviceIdentity.id(), first);

      final p = await SharedPreferences.getInstance();
      expect(p.getString('device_id'), first);
    });

    test('login so\'roviga qo\'shiladigan maydonlar to\'liq', () async {
      final f = await DeviceIdentity.fields();
      expect(f.keys, containsAll(['deviceId', 'deviceName', 'platform', 'appVersion']));
      expect(f['deviceId'], isNotEmpty);
      expect(f['platform'], isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('login', () {
    test('qurilma maydonlari YUBORILADI (aks holda server yuz so\'ramaydi)', () async {
      final api = install(FakeAdapter((_) => FakeReply.json(_login())));
      final s = Session();
      await s.init();

      expect(await s.login('ali@test.uz', 'parol'), isNull);

      final body = api.last.data as Map;
      expect(body['deviceId'], isNotEmpty);
      expect(body['deviceName'], isNotEmpty);
      expect(body['platform'], isNotEmpty);
      expect(body['appVersion'], isNotEmpty);
      // Qurilma identifikatori saqlanganiga mos bo'lsin.
      expect(body['deviceId'], await DeviceIdentity.id());
    });

    test('faceRequired YO\'Q — oqim o\'zgarmaydi (odatdagidek kiradi)', () async {
      install(FakeAdapter((_) => FakeReply.json(_login())));
      final s = Session();
      await s.init();

      expect(await s.login('ali@test.uz', 'parol'), isNull);
      expect(s.isAuthed, isTrue);
      expect(s.faceRequired, isFalse);
      expect(s.faceStatus, isNull);

      final p = await SharedPreferences.getInstance();
      expect(p.getBool('face_required'), isNull, reason: 'keraksiz bayroq diskda qolmasin');
    });

    test('faceRequired — cheklangan token saqlanadi, lekin qobiq OCHILMAYDI', () async {
      install(FakeAdapter((_) => FakeReply.json(_login(face: true, status: 'enroll'))));
      final s = Session();
      await s.init();

      expect(await s.login('ali@test.uz', 'parol'), isNull);
      expect(s.isAuthed, isTrue, reason: 'token bor — u bilan face endpointlari ishlaydi');
      expect(s.faceRequired, isTrue);
      expect(s.faceStatus, 'enroll');
      expect(ApiClient.token, 'jwt-1');
    });

    test('holat DISKKA yoziladi — ilova qayta ochilsa yana selfi so\'raladi', () async {
      install(FakeAdapter((_) => FakeReply.json(_login(face: true, status: 'verify'))));
      final s = Session();
      await s.init();
      await s.login('ali@test.uz', 'parol');

      // "Ilovani yopib qayta ochish" — yangi Session, o'sha disk.
      final again = Session();
      await again.init();
      expect(again.isAuthed, isTrue);
      expect(again.faceRequired, isTrue);
      expect(again.faceStatus, 'verify');
    });
  });

  // -------------------------------------------------------------------------
  group('completeFace', () {
    test('to\'liq token o\'rnatiladi va bayroq TOZALANADI', () async {
      install(FakeAdapter((_) => FakeReply.json(_login(face: true, status: 'enroll'))));
      final s = Session();
      await s.init();
      await s.login('ali@test.uz', 'parol');

      await s.completeFace('jwt-full');

      expect(s.faceRequired, isFalse);
      expect(s.faceStatus, isNull);
      expect(s.token, 'jwt-full');
      expect(ApiClient.token, 'jwt-full');
      expect(s.fullName, 'Ali Valiyev', reason: 'foydalanuvchi yo\'qolmasin');

      final p = await SharedPreferences.getInstance();
      expect(p.getString('token'), 'jwt-full');
      expect(p.getBool('face_required'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('401 {faceRequired:true}', () {
    test('sessiya TUGATILMAYDI — foydalanuvchi selfi ekraniga qaytariladi', () async {
      var path = '/auth/login';
      install(FakeAdapter((o) {
        path = o.path;
        if (o.path.contains('/auth/login')) return FakeReply.json(_login());
        return const FakeReply.json(
          '{"faceRequired":true,"message":"Yuz tasdiqlanmagan — selfi yuboring"}',
          status: 401,
        );
      }));
      final s = Session();
      await s.init();
      await s.login('ali@test.uz', 'parol');
      expect(s.faceRequired, isFalse);

      // Cheklangan token bilan boshqa endpointga so'rov.
      await ApiClient.dio.get('/student/me');
      expect(path, contains('/student/me'));

      expect(s.isAuthed, isTrue, reason: 'token yaroqli — logout qilinmasin');
      expect(s.faceRequired, isTrue);
    });

    test('oddiy 401 — avvalgidek sessiya tugatiladi', () async {
      install(FakeAdapter((o) {
        if (o.path.contains('/auth/login')) return FakeReply.json(_login());
        return const FakeReply.json('{"message":"Ruxsat yo\'q"}', status: 401);
      }));
      final s = Session();
      await s.init();
      await s.login('ali@test.uz', 'parol');

      await ApiClient.dio.get('/student/me');
      // logout ketma-ketligi asinxron — bir aylanish kutamiz.
      await Future<void>.delayed(Duration.zero);

      expect(s.isAuthed, isFalse);
      expect(s.faceRequired, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('logout', () {
    test('yuz bayroqlari tozalanadi, QURILMA identifikatori QOLADI', () async {
      install(FakeAdapter((_) => FakeReply.json(_login(face: true, status: 'enroll'))));
      final s = Session();
      await s.init();
      await s.login('ali@test.uz', 'parol');
      final deviceId = await DeviceIdentity.id();

      await s.logout(revokeDevice: false);

      expect(s.isAuthed, isFalse);
      expect(s.faceRequired, isFalse);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('face_required'), isNull);
      expect(p.getString('device_id'), deviceId,
          reason: 'aks holda har chiqishdan keyin yangi qurilma deb selfi so\'ralardi');
    });
  });

  // -------------------------------------------------------------------------
  group('ApiClient.isFaceRequired', () {
    test('faqat aniq bayroqni taniydi', () {
      expect(ApiClient.isFaceRequired({'faceRequired': true}), isTrue);
      expect(ApiClient.isFaceRequired({'faceRequired': false}), isFalse);
      expect(ApiClient.isFaceRequired({'faceRequired': 'true'}), isFalse);
      expect(ApiClient.isFaceRequired('faceRequired'), isFalse);
      expect(ApiClient.isFaceRequired(null), isFalse);
    });
  });
}
