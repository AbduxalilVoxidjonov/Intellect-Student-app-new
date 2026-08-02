// TestsScreen (tab) va OnlineTestScreen — muvaffaqiyat / xato / bo'sh ma'lumot.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/online_test_screen.dart';
import 'package:student/screens/tabs/tests_screen.dart';

import 'test_harness.dart';

void main() {
  // =========================================================================
  group('TestsScreen', () {
    testWidgets('muvaffaqiyatli yuklash — onlayn testlar va natijalar', (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests', '''
[{"id":"t1","groupId":"g1","groupName":"A1","name":"Unit 1 test","date":"2026-08-01",
  "questionCount":10,"optionCount":4,"startAt":"2026-08-01T09:00","endAt":"2026-08-01T10:00",
  "pdfUrl":"/uploads/t1.pdf","pdfName":"savollar.pdf","state":"open","answers":"","submittedAt":""}]
''');
      api.on('/student/test-results', '''
[{"testId":"tr1","groupId":"g1","groupName":"A1","name":"Midterm","date":"2026-03-01",
  "maxScore":20,"score":18,"rank":1,"total":12}]
''');

      await tester.pumpWidget(wrapBody(const TestsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Testlar'), findsOneWidget);
      expect(find.text('Onlayn testlar'), findsOneWidget);
      expect(find.text('Unit 1 test'), findsOneWidget);
      expect(find.text('Ochiq — ishlash mumkin'), findsOneWidget);
      expect(find.text('Natijalar'), findsOneWidget);
      expect(find.text('Midterm'), findsOneWidget);
      expect(find.text('18/20'), findsOneWidget);
      expect(find.text("🥇 1-o'rin (12 tadan)"), findsOneWidget);
    });

    testWidgets('ikkala API 500 — ekran qulamaydi, xato holati', (tester) async {
      final api = installFakeApi();
      api.failEverything();

      await tester.pumpWidget(wrapBody(const TestsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.textContaining("Ma'lumotlarni yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("bo'sh ro'yxatlar — bo'sh holat", (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests', '[]');
      api.on('/student/test-results', '[]');

      await tester.pumpWidget(wrapBody(const TestsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.textContaining("Hozircha test yo'q"), findsOneWidget);
    });

    testWidgets('faqat natijalar bor — onlayn testlar bo\'limi chizilmaydi', (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests', '[]');
      api.on('/student/test-results', '''
[{"testId":"tr1","groupId":"g1","groupName":"A1","name":"Final","date":"2026-05-01",
  "maxScore":0,"score":null,"rank":0,"total":0}]
''');

      await tester.pumpWidget(wrapBody(const TestsScreen()));
      await settle(tester);
      // maxScore = 0 — nolga bo'linish bo'lmasligi kerak.
      expectNoRealErrors(tester);

      expect(find.text('Onlayn testlar'), findsNothing);
      expect(find.text('Final'), findsOneWidget);
      expect(find.text('—'), findsWidgets); // ball ham, o'rin ham yo'q
    });
  });

  // =========================================================================
  group('OnlineTestScreen', () {
    testWidgets('ochiq test — javob varaqasi va yuborish tugmasi', (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests/t1', '''
{"id":"t1","groupId":"g1","groupName":"A1","name":"Unit 1 test","date":"2026-08-01",
 "questionCount":3,"optionCount":4,"startAt":"2026-08-01T09:00","endAt":"2026-08-01T10:00",
 "pdfUrl":"/uploads/t1.pdf","pdfName":"savollar.pdf","state":"open","answers":"",
 "submittedAt":"","answerKey":"","rank":0,"participants":0}
''');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Unit 1 test'), findsWidgets);
      expect(find.text('Javoblaringiz'), findsOneWidget);
      expect(find.text('0 / 3'), findsOneWidget);
      expect(find.text('Javoblarni yuborish'), findsOneWidget);
      expect(find.text("Ko'rish"), findsOneWidget);
      expect(find.text('3 savol · A–D'), findsOneWidget);
    });

    testWidgets('kutilayotgan test — ogohlantirish kartasi', (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests/t1', '''
{"id":"t1","groupId":"g1","groupName":"A1","name":"Kelgusi test","date":"2026-09-01",
 "questionCount":5,"optionCount":4,"startAt":"2026-09-01T09:00","endAt":"2026-09-01T10:00",
 "pdfUrl":"","pdfName":"","state":"upcoming","answers":"","submittedAt":"",
 "answerKey":"","rank":0,"participants":0}
''');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Test hali boshlanmagan'), findsOneWidget);
      expect(find.text('Javoblarni yuborish'), findsNothing);
    });

    testWidgets('topshirilgan test — natija va javob kaliti', (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests/t2', '''
{"id":"t2","groupId":"g1","groupName":"A1","name":"Unit 2 test","date":"2026-08-01",
 "questionCount":5,"optionCount":4,"startAt":"2026-08-01T09:00","endAt":"2026-08-01T10:00",
 "pdfUrl":"","pdfName":"","state":"submitted","score":4,"answers":"ABCDA",
 "submittedAt":"2026-08-01T09:30","answerKey":"ABCDD","rank":2,"participants":10}
''');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't2')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('80%'), findsOneWidget);
      expect(find.text('4 / 5'), findsOneWidget);
      expect(find.text("O'rin: 2 / 10"), findsOneWidget);
      expect(find.text('Javoblaringiz'), findsOneWidget);
    });

    testWidgets('API 500 — ekran qulamaydi', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/online-tests/t1');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1', title: 'Unit 1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
      expect(find.text('Unit 1'), findsOneWidget); // ro'yxatdan kelgan nom
    });

    testWidgets("bo'sh javob ({}) — RangeError/null check bo'lmaydi", (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests/t1', '{}');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Onlayn test'), findsOneWidget); // sarlavha fallback
    });

    // TUZATILDI: optionCount < 1 bo'lsa harflar oralig'i umuman ko'rsatilmaydi.
    testWidgets("optionCount=0 bo'lganda 'A–@' emas, tushunarli matn chiqadi", (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests/t1', '{}');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.textContaining('A–@'), findsNothing);
      expect(find.text('0 savol'), findsOneWidget);
    });

    testWidgets('javoblar qatori savollar sonidan uzun — hisoblagich cheklanadi', (tester) async {
      final api = installFakeApi();
      // Server 5 savolga 7 harfli javob qaytardi (buzuq ma'lumot).
      api.on('/student/online-tests/t1', '''
{"id":"t1","groupId":"g1","groupName":"A1","name":"Unit 1 test","date":"2026-08-01",
 "questionCount":5,"optionCount":4,"startAt":"2026-08-01T09:00","endAt":"2026-08-01T10:00",
 "pdfUrl":"","pdfName":"","state":"open","answers":"ABCDABC","submittedAt":"",
 "answerKey":"","rank":0,"participants":0}
''');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('7 / 5'), findsNothing);
    });

    testWidgets('tez kiritish: "3c 1a" — raqam savol nomerini bildiradi', (tester) async {
      final api = installFakeApi();
      api.on('/student/online-tests/t1', '''
{"id":"t1","groupId":"g1","groupName":"A1","name":"Unit 1 test","date":"2026-08-01",
 "questionCount":5,"optionCount":4,"startAt":"2026-08-01T09:00","endAt":"2026-08-01T10:00",
 "pdfUrl":"","pdfName":"","state":"open","answers":"","submittedAt":"",
 "answerKey":"","rank":0,"participants":0}
''');

      await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1')));
      await settle(tester);

      await tester.tap(find.textContaining('Tez kiritish'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '3c 1a');
      await tester.pump();
      await tester.tap(find.text("Qo'llash"));
      await tester.pump();
      expectNoRealErrors(tester);

      // Faqat 1- va 3-savol belgilanadi (harflar ketma-ket olinmaydi).
      expect(find.text('2 / 5'), findsOneWidget);
    });
  });
}

