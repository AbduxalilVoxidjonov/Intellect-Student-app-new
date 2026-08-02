import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/api/api_client.dart';

import 'fake_adapter.dart';

void main() {
  // `ApiClient.dio` — statik singleton. Testlar bir-biriga ta'sir qilmasligi uchun
  // token/callback/adapter har testda tozalanadi.
  setUp(resetApiClient);
  tearDown(resetApiClient);

  group('ApiClient.ok()', () {
    test('2xx chegaralari: 200/204/299 — true', () {
      expect(ApiClient.ok(fakeResponse(statusCode: 200)), isTrue);
      expect(ApiClient.ok(fakeResponse(statusCode: 204)), isTrue);
      expect(ApiClient.ok(fakeResponse(statusCode: 299)), isTrue);
    });

    test('2xx dan tashqari: 199/300/404/500 — false', () {
      expect(ApiClient.ok(fakeResponse(statusCode: 199)), isFalse);
      expect(ApiClient.ok(fakeResponse(statusCode: 300)), isFalse);
      expect(ApiClient.ok(fakeResponse(statusCode: 404)), isFalse);
      expect(ApiClient.ok(fakeResponse(statusCode: 500)), isFalse);
    });

    test('statusCode == null — false (0 deb qaraladi)', () {
      expect(ApiClient.ok(fakeResponse(statusCode: null)), isFalse);
    });
  });

  group('ApiClient.errorMessage()', () {
    test('Map + string `message` — serverning matni qaytadi', () {
      final res = fakeResponse(statusCode: 400, data: {'message': "Parol noto'g'ri"});
      expect(ApiClient.errorMessage(res), "Parol noto'g'ri");
      // fallback berilsa ham server matni ustun.
      expect(ApiClient.errorMessage(res, 'boshqa'), "Parol noto'g'ri");
    });

    test('Map bor, lekin `message` yo\'q — fallback', () {
      final res = fakeResponse(statusCode: 400, data: {'error': 'oops'});
      expect(ApiClient.errorMessage(res, 'fallback matni'), 'fallback matni');
      expect(ApiClient.errorMessage(res), 'Xatolik yuz berdi');
    });

    test('`message` String EMAS (masalan validatsiya massivi) — fallback', () {
      final res = fakeResponse(statusCode: 400, data: {
        'message': ['juda qisqa', 'raqam kerak'],
      });
      expect(ApiClient.errorMessage(res, 'fallback'), 'fallback');
    });

    test('javob List — fallback', () {
      final res = fakeResponse(statusCode: 400, data: [1, 2, 3]);
      expect(ApiClient.errorMessage(res, 'fallback'), 'fallback');
    });

    test('javob null / res null — umumiy matn', () {
      expect(ApiClient.errorMessage(fakeResponse(statusCode: 400)), 'Xatolik yuz berdi');
      expect(ApiClient.errorMessage(null), 'Xatolik yuz berdi');
      expect(ApiClient.errorMessage(null, 'ulanmadi'), 'ulanmadi');
    });

    test('5xx — `message` bo\'lmasa o\'zbekcha server xatosi matni', () {
      // 5xx endi dio darajasida emas, shu yerda ishlanadi (validateStatus < 600).
      expect(
        ApiClient.errorMessage(fakeResponse(statusCode: 500)),
        "Serverda xatolik. Birozdan keyin urinib ko'ring.",
      );
      // fallback berilsa ham 5xx matni ustun — sabab aniqroq.
      expect(
        ApiClient.errorMessage(fakeResponse(statusCode: 503), "Login yoki parol noto'g'ri"),
        "Serverda xatolik. Birozdan keyin urinib ko'ring.",
      );
      // Server o'z matnini bergan bo'lsa — u ustun.
      expect(
        ApiClient.errorMessage(fakeResponse(statusCode: 500, data: {'message': 'Baza yopiq'})),
        'Baza yopiq',
      );
    });

    test('fallback Object bo\'lsa toString() olinadi', () {
      expect(ApiClient.errorMessage(null, Exception('xato')), contains('xato'));
    });
  });

  group('Authorization sarlavhasi', () {
    test('token bor — `Bearer <token>` qo\'shiladi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));
      ApiClient.token = 'abc123';

      await ApiClient.dio.get('/student/me');

      expect(a.last.headers['Authorization'], 'Bearer abc123');
    });

    test('token null — sarlavha umuman qo\'shilmaydi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));
      ApiClient.token = null;

      await ApiClient.dio.get('/student/me');

      expect(a.last.headers.containsKey('Authorization'), isFalse);
    });

    test('token o\'zgarsa keyingi so\'rov yangi token bilan ketadi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      ApiClient.token = 'eski';
      await ApiClient.dio.get('/student/me');
      ApiClient.token = 'yangi';
      await ApiClient.dio.get('/student/me');

      expect(a.requests[0].headers['Authorization'], 'Bearer eski');
      expect(a.requests[1].headers['Authorization'], 'Bearer yangi');
    });

    test('baseUrl va Content-Type BaseOptions dan keladi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await ApiClient.dio.get('/student/me');

      expect(a.last.baseUrl, contains('/api'));
      expect(a.last.headers['Content-Type'], 'application/json');
    });
  });

  group('401 → onUnauthorized', () {
    test('oddiy yo\'lda 401 — callback CHAQIRILADI', () async {
      install(FakeAdapter.always(const FakeReply.json('{"message":"unauthorized"}', status: 401)));
      var calls = 0;
      ApiClient.onUnauthorized = () => calls++;

      final res = await ApiClient.dio.get('/student/dashboard');

      expect(res.statusCode, 401, reason: 'validateStatus 4xx ni o\'tkazadi');
      expect(calls, 1);
    });

    test('/auth/login yo\'lida 401 — callback CHAQIRILMAYDI', () async {
      install(FakeAdapter.always(const FakeReply.json('{"message":"bad creds"}', status: 401)));
      var calls = 0;
      ApiClient.onUnauthorized = () => calls++;

      await ApiClient.dio.post('/auth/login', data: {'email': 'a', 'password': 'b'});

      expect(calls, 0);
    });

    test('403 — callback CHAQIRILMAYDI (faqat 401)', () async {
      install(FakeAdapter.always(const FakeReply.json('{"message":"forbidden"}', status: 403)));
      var calls = 0;
      ApiClient.onUnauthorized = () => calls++;

      await ApiClient.dio.get('/student/dashboard');

      expect(calls, 0);
    });

    test('onUnauthorized null bo\'lsa 401 xatosiz o\'tadi', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 401)));
      ApiClient.onUnauthorized = null;

      final res = await ApiClient.dio.get('/student/dashboard');

      expect(res.statusCode, 401);
    });

    test('parallel 401 lar — onUnauthorized FAQAT BIR MARTA chaqiriladi', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 401)));
      var calls = 0;
      ApiClient.onUnauthorized = () => calls++;

      await Future.wait([
        ApiClient.dio.get('/student/dashboard'),
        ApiClient.dio.get('/student/grades'),
        ApiClient.dio.get('/student/finance'),
      ]);

      expect(calls, 1, reason: 'dedublikatsiya — sessiya bir marta tugatiladi');
    });

    test('muvaffaqiyatli login dedublikatsiya bayrog\'ini tiklaydi', () async {
      install(FakeAdapter((o) => o.path.contains('/auth/login')
          ? const FakeReply.json('{"token":"t"}')
          : const FakeReply.json('{}', status: 401)));
      var calls = 0;
      ApiClient.onUnauthorized = () => calls++;

      await ApiClient.dio.get('/student/dashboard'); // 1-marta
      await ApiClient.dio.get('/student/grades'); // dedublikatsiya — chaqirilmaydi
      expect(calls, 1);

      await ApiClient.dio.post('/auth/login', data: {'email': 'a', 'password': 'b'});
      await ApiClient.dio.get('/student/dashboard');

      expect(calls, 2, reason: 'yangi sessiyadagi 401 yana ushlanishi kerak');
    });

    test('onUnauthorized hali o\'rnatilmagan bo\'lsa bayroq YOQILMAYDI', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 401)));
      ApiClient.onUnauthorized = null;

      await ApiClient.dio.get('/student/dashboard');

      var calls = 0;
      ApiClient.onUnauthorized = () => calls++;
      await ApiClient.dio.get('/student/grades');

      expect(calls, 1, reason: 'ilgaksiz 401 keyingisini "yeb" qo\'ymasligi kerak');
    });
  });

  group('validateStatus: s < 600', () {
    test('4xx — Response qaytadi (xato tashlanmaydi), data o\'qiladi', () async {
      install(FakeAdapter.always(const FakeReply.json('{"message":"Topilmadi"}', status: 404)));

      final res = await ApiClient.dio.get('/student/dashboard');

      expect(ApiClient.ok(res), isFalse);
      expect(ApiClient.errorMessage(res), 'Topilmadi');
    });

    // 5xx ham `Response` bo'lib keladi — dio o'zi `DioException` TASHLAMAYDI,
    // shuning uchun serverning `message` i yo'qolmaydi va ekranlarga
    // "DioException [bad response]: ..." kabi inglizcha matn chiqmaydi.
    test('5xx — Response qaytadi, serverning `message` i saqlanadi', () async {
      install(FakeAdapter.always(const FakeReply.json('{"message":"Bazaga ulanib bo\'lmadi"}', status: 500)));

      final res = await ApiClient.dio.get('/student/dashboard');

      expect(res.statusCode, 500);
      expect(ApiClient.ok(res), isFalse);
      expect(ApiClient.errorMessage(res), "Bazaga ulanib bo'lmadi");
    });

    test('599 gacha bo\'lgan har qanday kod — xato tashlanmaydi', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 599)));

      final res = await ApiClient.dio.get('/student/dashboard');

      expect(res.statusCode, 599);
      expect(ApiClient.errorMessage(res), "Serverda xatolik. Birozdan keyin urinib ko'ring.");
    });

    test('tarmoq uzilishi — DioException.unknown', () async {
      install(FakeAdapter.failing());

      await expectLater(
        ApiClient.dio.get('/student/dashboard'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
