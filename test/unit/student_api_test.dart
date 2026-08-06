import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/api/student_api.dart';
import 'package:student/models/models.dart';

import 'fake_adapter.dart';

const _dashboardJson = '''
{
  "profile": {"id": "s1", "fullName": "Ali Valiyev", "className": "A1"},
  "meta": {"lessonTimes": [], "absenceReasons": [], "currentQuarter": 2, "currentWeek": 5},
  "todayLessons": [],
  "todayGrades": [],
  "balance": -150000,
  "monthlyFee": 450000
}
''';

const _groupsJson = '''
[
  {"groupId": "g1", "name": "Ingliz A1", "courseName": "General English", "teacherName": "Aziza",
   "days": [0, 2, 4], "startTime": "09:00", "endTime": "10:30", "room": "201",
   "state": "active", "status": "active", "isActive": true, "groupArchived": false,
   "joinedAt": "2026-01-10", "leftAt": ""},
  {"groupId": "g2", "name": "IELTS", "courseName": "IELTS", "teacherName": "Bekzod",
   "days": [1, 3], "startTime": "18:00", "endTime": "19:30", "room": "105",
   "state": "finished", "status": "completed", "isActive": false, "groupArchived": true,
   "joinedAt": "2025-09-01", "leftAt": "2025-12-30"}
]
''';

const _onlineTestJson = '''
{
  "id": "t1", "groupId": "g1", "groupName": "Ingliz A1", "name": "Unit 3 test",
  "date": "2026-07-01", "questionCount": 20, "optionCount": 4,
  "startAt": "2026-07-01T09:00", "endAt": "2026-07-01T10:00",
  "pdfUrl": "/uploads/t1.pdf", "pdfName": "t1.pdf", "state": "submitted",
  "score": 17, "answers": "ABCDA", "submittedAt": "2026-07-01T09:40",
  "answerKey": "ABCDB", "rank": 2, "participants": 15
}
''';

const _notificationsJson = '''
{
  "unread": 2,
  "items": [
    {"id": "n1", "title": "Yangi baho", "body": "5 qo'yildi", "type": "grade",
     "createdAt": "2026-07-14T09:00:00", "read": false, "confirmed": false},
    {"id": "n2", "title": "Ruxsatnoma", "body": "Tasdiqlang", "type": "permission",
     "createdAt": "2026-07-13T15:00:00", "read": true, "confirmed": true}
  ]
}
''';

void main() {
  setUp(resetApiClient);
  tearDown(resetApiClient);

  group('_sid — ?studentId= query', () {
    test('studentId berilganda query ga qo\'shiladi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json(_dashboardJson)));

      await StudentApi.dashboard(studentId: 'stu-42');

      expect(a.last.uri.queryParameters['studentId'], 'stu-42');
    });

    test('studentId berilmaganda query BO\'SH bo\'ladi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json(_dashboardJson)));

      await StudentApi.dashboard();

      expect(a.last.uri.queryParameters.containsKey('studentId'), isFalse);
      expect(a.last.uri.query, isEmpty);
    });

    test('boshqa parametrlar bilan birga qo\'shiladi (attendance: quarter + studentId)', () async {
      final a = install(FakeAdapter.always(const FakeReply.json(
        '{"summary": {}, "byMonth": {}, "rows": []}',
      )));

      try {
        await StudentApi.attendance(quarter: 3, studentId: 'stu-9');
      } catch (_) {
        // Model tarkibi bu testda muhim emas — bizni faqat query qiziqtiradi.
      }

      expect(a.last.uri.queryParameters['quarter'], '3');
      expect(a.last.uri.queryParameters['studentId'], 'stu-9');
    });

    test('grading — month berilmasa query ga tushmaydi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('[]')));

      await StudentApi.grading();

      expect(a.last.uri.queryParameters, isEmpty);
    });

    test('grading — month berilsa tushadi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('[]')));

      await StudentApi.grading(month: '2026-07', studentId: 's1');

      expect(a.last.uri.queryParameters['month'], '2026-07');
      expect(a.last.uri.queryParameters['studentId'], 's1');
    });
  });

  group('_fail — server matni bilan Exception', () {
    test('400 + `message` — aynan serverning matni', () async {
      install(FakeAdapter.always(
        const FakeReply.json('{"message":"Chorak notogri"}', status: 400),
      ));

      await expectLater(
        StudentApi.dashboard(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'toString', contains('Chorak notogri'))),
      );
    });

    test('403 + `message` — ruxsat xatosi ham shu yo\'l bilan chiqadi', () async {
      install(FakeAdapter.always(
        const FakeReply.json('{"message":"Bu ma\'lumot sizga ochiq emas"}', status: 403),
      ));

      await expectLater(
        StudentApi.groups(studentId: 'boshqa-oquvchi'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains("Bu ma'lumot sizga ochiq emas"),
        )),
      );
    });

    test('404 + `message` yo\'q — umumiy matn', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 404)));

      await expectLater(
        StudentApi.notifications(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'toString', contains('Xatolik yuz berdi'))),
      );
    });

    // 5xx endi `_fail` ga yetib keladi (validateStatus: s < 600) — foydalanuvchi
    // xom `DioException` o'rniga serverning matnini ko'radi.
    test('500 — serverning matni bilan Exception', () async {
      install(FakeAdapter.always(
        const FakeReply.json('{"message":"Ichki server xatosi"}', status: 500),
      ));

      await expectLater(
        StudentApi.dashboard(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          allOf(contains('Ichki server xatosi'), isNot(contains('DioException'))),
        )),
      );
    });

    test('500 + `message` yo\'q — o\'zbekcha server xatosi matni', () async {
      install(FakeAdapter.always(const FakeReply.json('{}', status: 500)));

      await expectLater(
        StudentApi.dashboard(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains("Serverda xatolik. Birozdan keyin urinib ko'ring."),
        )),
      );
    });
  });

  group('dashboard()', () {
    test('to\'g\'ri yo\'l va model parsing', () async {
      final a = install(FakeAdapter.always(const FakeReply.json(_dashboardJson)));

      final d = await StudentApi.dashboard();

      expect(a.last.path, '/student/dashboard');
      expect(a.last.method, 'GET');
      expect(d.profile.fullName, 'Ali Valiyev');
      expect(d.balance, -150000);
      expect(d.monthlyFee, 450000);
      expect(d.meta.currentQuarter, 2);
    });

    // `_obj` tanani `is Map` bilan tekshiradi: server 200 bilan JSON BO'LMAGAN
    // javob (HTML/proxy sahifasi) qaytarsa xom `TypeError` (Error!) emas,
    // ekranlar ushlay oladigan `Exception` chiqadi.
    test('200 + JSON bo\'lmagan tana — tushunarli Exception (TypeError EMAS)', () async {
      install(FakeAdapter.always(const FakeReply.text('<html>502 Bad Gateway</html>')));

      await expectLater(
        StudentApi.dashboard(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains("Server javobi noto'g'ri"),
        )),
      );
    });

    test('200 + `null` tana — obyekt kutilgan joyda ham Exception', () async {
      install(FakeAdapter.always(const FakeReply.json('null')));

      await expectLater(
        StudentApi.dashboard(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains("Server javobi noto'g'ri"),
        )),
      );
    });
  });

  group('groups()', () {
    test('ro\'yxat to\'liq o\'qiladi (faol + tugagan)', () async {
      final a = install(FakeAdapter.always(const FakeReply.json(_groupsJson)));

      final g = await StudentApi.groups();

      expect(a.last.path, '/student/groups');
      expect(g, hasLength(2));
      expect(g[0].name, 'Ingliz A1');
      expect(g[0].days, [0, 2, 4]);
      expect(g[0].isCurrent, isTrue);
      expect(g[0].statusLabel, 'Aktiv');
      expect(g[1].isCurrent, isFalse);
      expect(g[1].statusLabel, 'Guruh yopilgan');
    });

    test('bo\'sh massiv — bo\'sh ro\'yxat', () async {
      install(FakeAdapter.always(const FakeReply.json('[]')));

      expect(await StudentApi.groups(), isEmpty);
    });

    test('`null` javob — bo\'sh ro\'yxat', () async {
      install(FakeAdapter.always(const FakeReply.json('null')));

      expect(await StudentApi.groups(), isEmpty);
    });

    test('tana umuman bo\'sh — bo\'sh ro\'yxat', () async {
      install(FakeAdapter.always(const FakeReply.json('')));

      expect(await StudentApi.groups(), isEmpty);
    });
  });

  // Himoya IZCHIL: barcha ro'yxat qaytaruvchi metodlar `_arr` orqali ishlaydi.
  group('ro\'yxat metodlari — kutilmagan javobga bardosh', () {
    test('`null` javobda barchasi bo\'sh ro\'yxat qaytaradi', () async {
      install(FakeAdapter.always(const FakeReply.json('null')));

      expect(await StudentApi.curriculum(), isEmpty);
      expect(await StudentApi.grading(), isEmpty);
      expect(await StudentApi.chat(), isEmpty);
      expect(await StudentApi.certificates(), isEmpty);
      expect(await StudentApi.testResults(), isEmpty);
      expect(await StudentApi.onlineTests(), isEmpty);
      expect(await StudentApi.aiCheckHistory(), isEmpty);
      expect(await StudentApi.contracts(), isEmpty);
      expect(await StudentApi.courseProgress('c1'), isEmpty);
    });

    test('massiv o\'rniga obyekt kelsa ham bo\'sh ro\'yxat (xato tashlanmaydi)', () async {
      install(FakeAdapter.always(const FakeReply.json('{"items":[]}')));

      expect(await StudentApi.curriculum(), isEmpty);
      expect(await StudentApi.testResults(), isEmpty);
    });

    test('ro\'yxat ichidagi begona elementlar e\'tiborsiz qoldiriladi', () async {
      install(FakeAdapter.always(const FakeReply.json('[null, 5, "x"]')));

      expect(await StudentApi.certificates(), isEmpty);
    });
  });

  group('contracts()', () {
    test('List bo\'lsa parse qilinadi', () async {
      install(FakeAdapter.always(const FakeReply.json(
        '[{"id":"c1","number":12,"title":"Shartnoma","target":"parent",'
        '"recipientKey":"p1","recipientName":"Ota","templateName":"tpl",'
        '"date":"2026-01-05","pdfUrl":"/uploads/c1.pdf","docxUrl":"",'
        '"delivered":true,"status":"signed","visible":true}]',
      )));

      final c = await StudentApi.contracts(studentId: 's1');

      expect(c, hasLength(1));
      expect(c.first.number, 12);
      expect(c.first.pdfUrl, '/uploads/c1.pdf');
    });

    test('List EMAS (Map) — bo\'sh ro\'yxat, xato tashlanmaydi', () async {
      install(FakeAdapter.always(const FakeReply.json('{"items": []}')));

      expect(await StudentApi.contracts(), isEmpty);
    });

    test('`null` javob — bo\'sh ro\'yxat', () async {
      install(FakeAdapter.always(const FakeReply.json('null')));

      expect(await StudentApi.contracts(), isEmpty);
    });
  });

  group('certificateBytes()', () {
    test('muvaffaqiyat — baytlar qaytadi', () async {
      final a = install(FakeAdapter.always(const FakeReply.binary([37, 80, 68, 70])));

      final bytes = await StudentApi.certificateBytes('cert-1');

      expect(a.last.path, '/student/certificates/cert-1/download');
      expect(a.last.responseType, ResponseType.bytes);
      expect(bytes, [37, 80, 68, 70]);
    });

    test('404 — "Sertifikatni yuklab bo\'lmadi"', () async {
      install(FakeAdapter.always(const FakeReply.binary(<int>[], status: 404)));

      await expectLater(
        StudentApi.certificateBytes('yoq'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains("Sertifikatni yuklab bo'lmadi"),
        )),
      );
    });

    // Xato javobi ham BAYT bo'lib keladi — uni JSON deb o'qib, serverning
    // matnini foydalanuvchiga uzatamiz (403 "limit tugadi" yo'qolib ketmasin).
    test('403 — serverning `message` i uzatiladi', () async {
      install(FakeAdapter((_) => const FakeReply.json('{"message":"Kunlik limit tugadi"}', status: 403)));

      await expectLater(
        StudentApi.certificateBytes('c1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains('Kunlik limit tugadi'),
        )),
      );
    });

    test('xato javobi JSON bo\'lmasa — umumiy matn', () async {
      install(FakeAdapter.always(const FakeReply.binary([1, 2, 3], status: 500)));

      await expectLater(
        StudentApi.certificateBytes('c1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains("Sertifikatni yuklab bo'lmadi"),
        )),
      );
    });
  });

  group('saveCourseAttempt() — xato YUTILADI', () {
    test('500 bo\'lsa ham throw QILMAYDI', () async {
      install(FakeAdapter.always(const FakeReply.json('{"message":"xato"}', status: 500)));

      await expectLater(
        StudentApi.saveCourseAttempt(
          itemId: 'i1',
          section: 'test',
          correct: 8,
          total: 10,
          durationSec: 120,
        ),
        completes,
      );
    });

    test('tarmoq uzilsa ham throw QILMAYDI', () async {
      install(FakeAdapter.failing());

      await expectLater(
        StudentApi.saveCourseAttempt(itemId: 'i1', section: 'view', correct: 0, total: 0, durationSec: 5),
        completes,
      );
    });

    test('body: majburiy maydonlar + shartli `exerciseKind`/`answers`', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.saveCourseAttempt(
        itemId: 'i1',
        section: 'exercise',
        exerciseKind: 'match',
        correct: 4,
        total: 5,
        durationSec: 42,
        answers: [
          AttemptAnswer(index: 0, prompt: 'cat', answer: 'mushuk', expected: 'mushuk', ok: true, sec: 3),
        ],
      );

      final body = a.last.data as Map<String, dynamic>;
      expect(a.last.path, '/student/curriculum/attempt');
      expect(body['itemId'], 'i1');
      expect(body['section'], 'exercise');
      expect(body['exerciseKind'], 'match');
      expect(body['correct'], 4);
      expect(body['total'], 5);
      expect(body['durationSec'], 42);
      expect((body['answers'] as List).first, containsPair('answer', 'mushuk'));
    });

    test('exerciseKind bo\'sh / answers null — kalitlar umuman qo\'shilmaydi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.saveCourseAttempt(
        itemId: 'i1',
        section: 'view',
        exerciseKind: '',
        correct: 0,
        total: 0,
        durationSec: 1,
      );

      final body = a.last.data as Map<String, dynamic>;
      expect(body.containsKey('exerciseKind'), isFalse);
      expect(body.containsKey('answers'), isFalse);
    });
  });

  group('submitOnlineTest()', () {
    test('POST + javoblar body da, natija parse qilinadi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json(_onlineTestJson)));

      final d = await StudentApi.submitOnlineTest('t1', 'ABCDA');

      expect(a.last.method, 'POST');
      expect(a.last.path, '/student/online-tests/t1/submit');
      expect(a.last.data, {'answers': 'ABCDA'});
      expect(d.test.name, 'Unit 3 test');
      expect(d.test.isSubmitted, isTrue);
      expect(d.test.score, 17);
      expect(d.answerKey, 'ABCDB');
      expect(d.rank, 2);
      expect(d.participants, 15);
    });

    test('400 "allaqachon topshirilgan" — serverning matni', () async {
      install(FakeAdapter.always(
        const FakeReply.json('{"message":"Test allaqachon topshirilgan"}', status: 400),
      ));

      await expectLater(
        StudentApi.submitOnlineTest('t1', 'AAAA'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          contains('Test allaqachon topshirilgan'),
        )),
      );
    });
  });

  group('sendFeedback() — FormData', () {
    test('rasmsiz: faqat type + text', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.sendFeedback('bug', 'Ilova qulab tushdi');

      final fd = a.last.data as FormData;
      expect(a.last.path, '/student/feedback');
      expect(fd.fields.map((e) => e.key), containsAll(<String>['type', 'text']));
      expect(fd.fields.firstWhere((e) => e.key == 'type').value, 'bug');
      expect(fd.fields.firstWhere((e) => e.key == 'text').value, 'Ilova qulab tushdi');
      expect(fd.files, isEmpty);
      expect(a.last.headers[Headers.contentTypeHeader], contains('multipart/form-data'));
    });

    test('rasm bilan: `image` fayli berilgan nom bilan', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.sendFeedback('idea', 'Taklif', imageBytes: [1, 2, 3], imageName: 'screenshot.png');

      final fd = a.last.data as FormData;
      expect(fd.files, hasLength(1));
      expect(fd.files.first.key, 'image');
      expect(fd.files.first.value.filename, 'screenshot.png');
    });

    test('imageName berilmasa — image.jpg', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.sendFeedback('bug', 'x', imageBytes: [9]);

      final fd = a.last.data as FormData;
      expect(fd.files.first.value.filename, 'image.jpg');
    });

    test('413 — serverning matni chiqadi', () async {
      install(FakeAdapter.always(
        const FakeReply.json('{"message":"Rasm juda katta"}', status: 413),
      ));

      await expectLater(
        StudentApi.sendFeedback('bug', 'x', imageBytes: [1]),
        throwsA(isA<Exception>().having((e) => e.toString(), 'toString', contains('Rasm juda katta'))),
      );
    });
  });

  group('notifications()', () {
    test('unread + items parse qilinadi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json(_notificationsJson)));

      final n = await StudentApi.notifications();

      expect(a.last.path, '/student/notifications');
      expect(a.last.uri.query, isEmpty, reason: 'notifications() studentId qabul qilmaydi');
      expect(n.unread, 2);
      expect(n.items, hasLength(2));
      expect(n.items.first.title, 'Yangi baho');
      expect(n.items.first.read, isFalse);
      expect(n.items.last.confirmed, isTrue);
    });

    test('bo\'sh javob — 0 va bo\'sh ro\'yxat', () async {
      install(FakeAdapter.always(const FakeReply.json('{}')));

      final n = await StudentApi.notifications();

      expect(n.unread, 0);
      expect(n.items, isEmpty);
    });

    test('markNotificationsRead / confirmNotification — to\'g\'ri yo\'llar', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.markNotificationsRead();
      expect(a.last.path, '/student/notifications/read');
      expect(a.last.method, 'POST');

      await StudentApi.confirmNotification('n7');
      expect(a.last.path, '/student/notifications/n7/confirm');
    });
  });

  group('registerDevice / unregisterDevice', () {
    test('registerDevice — bo\'sh deviceName/appId body ga tushmaydi', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.registerDevice(token: 'fcm-1', platform: 'android', deviceName: '', appId: null);

      final body = a.last.data as Map<String, dynamic>;
      expect(body['token'], 'fcm-1');
      expect(body['platform'], 'android');
      expect(body.containsKey('deviceName'), isFalse);
      expect(body.containsKey('appId'), isFalse);
    });

    test('unregisterDevice — DELETE + ?token=', () async {
      final a = install(FakeAdapter.always(const FakeReply.json('{}')));

      await StudentApi.unregisterDevice('fcm-1');

      expect(a.last.method, 'DELETE');
      expect(a.last.uri.queryParameters['token'], 'fcm-1');
    });
  });
}
