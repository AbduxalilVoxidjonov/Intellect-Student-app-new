// «UMUMIY STATISTIKA» (StatisticsScreen) — ilgari uchta alohida ekran bo'lgan
// Baholar / Davomat / Baholash endi shu ekran ichidagi TABLAR, ustida esa
// hafta/oy davr filtri turadi.
//
// Tekshiriladi: (1) davr tanlagich va u yuboradigan sanalar, (2) har bir tab
// mazmuni, (3) xato/bo'sh holatlar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/statistics_screen.dart';
import 'package:student/utils/format.dart';

import 'test_harness.dart';

/// To'rtta dars: ikkitasida baho, bittasi sababli qoldirilgan, bittasi
/// umuman belgilanmagan (na "keldi", na sabab) — davomat tabidagi uchala
/// holat shu bitta javobda bor.
const _journalJson = '''
{
  "from": "2026-03-09", "to": "2026-03-15", "groupId": "",
  "groups": [{"groupId":"g1","groupName":"A1","courseName":"Grammar","teacherName":"Aziza"}],
  "summary": {"held": 4, "attended": 3, "absent": 1, "late": 0, "attendancePct": 75,
              "gradesCount": 2, "avgGrade": 4.5, "homeworkDone": 3, "homeworkMissed": 1,
              "behaviorGood": 2, "behaviorBad": 0},
  "subjects": [
    {"subjectId":"sub1","subjectName":"Grammar","held":2,"attended":2,"gradesCount":2,"avgGrade":4.5},
    {"subjectId":"sub2","subjectName":"Speaking","held":2,"attended":1,"gradesCount":0,"avgGrade":0}
  ],
  "lessons": [
    {"date":"2026-03-09","period":1,"groupId":"g1","groupName":"A1","subjectId":"sub1",
     "subjectName":"Grammar","topic":"Present Simple","homeworkText":"Unit 1","conducted":true,
     "present":true,"grade":5,"reasonName":null,"reasonShort":null,"isLate":false,
     "homeworkMark":1,"behavior":1,"mastery":2},
    {"date":"2026-03-11","period":2,"groupId":"g1","groupName":"A1","subjectId":"sub1",
     "subjectName":"Grammar","topic":"Past Simple","homeworkText":"","conducted":true,
     "present":true,"grade":4,"reasonName":null,"reasonShort":null,"isLate":false,
     "homeworkMark":2,"behavior":0,"mastery":null},
    {"date":"2026-03-13","period":1,"groupId":"g1","groupName":"A1","subjectId":"sub2",
     "subjectName":"Speaking","topic":"Hobbies","homeworkText":"","conducted":true,
     "present":false,"grade":null,"reasonName":"Kasallik","reasonShort":"Kasal","isLate":false,
     "homeworkMark":0,"behavior":0,"mastery":null},
    {"date":"2026-03-15","period":1,"groupId":"g1","groupName":"A1","subjectId":"sub2",
     "subjectName":"Speaking","topic":"","homeworkText":"","conducted":true,
     "present":false,"grade":null,"reasonName":null,"reasonShort":null,"isLate":false,
     "homeworkMark":0,"behavior":0,"mastery":null}
  ]
}
''';

/// Dars ham, baho ham bo'lmagan davr (ta'til / guruhga hali qo'shilmagan).
const _emptyJournalJson = '''
{"from":"2026-03-09","to":"2026-03-15","groupId":"","groups":[],
 "summary":{"held":0,"attended":0,"absent":0,"late":0,"attendancePct":0,"gradesCount":0,
            "avgGrade":0,"homeworkDone":0,"homeworkMissed":0,"behaviorGood":0,"behaviorBad":0},
 "subjects":[],"lessons":[]}
''';

/// «Oxirgi 6 oy» bloklari uchun (davr filtriga bo'ysunmaydi).
const _notebookJson = '''
{
  "id": "s1", "fullName": "Ali Valiyev", "className": "A1", "balance": 0, "avgGrade": 4.4,
  "subjects": [{"id": "sub1", "name": "Grammar"}],
  "grades": {"sub1": {"2026-01": 4.0, "2026-02": 5.0}},
  "attendance": {"missedDays": {}, "illnessDays": {}, "missedLessons": {}, "illnessLessons": {},
                 "lateCount": {}},
  "conducted": 40, "attended": 34, "attendancePct": 85, "reasons": [],
  "homeworkDone": 8, "homeworkMissed": 2, "behaviorGood": 3, "behaviorBad": 1,
  "marksTrend": [{"month":"2026-01","homeworkDone":4,"homeworkMissed":1,
                  "behaviorGood":2,"behaviorBad":0}]
}
''';

/// Joriy hafta ichidagi sana ("yyyy-MM-dd") — baholash tabidagi dars qatorlari
/// KLIENT tomonda davr bo'yicha filtrlanadi, shuning uchun fikstura sanalari
/// haqiqiy joriy haftaga tushishi SHART.
String _weekDay(int offset) {
  final w = weekStart(DateTime.now());
  return isoDate(DateTime(w.year, w.month, w.day + offset));
}

String _gradingJson() {
  final month = _weekDay(0).substring(0, 7);
  return '''
[{"groupId":"g1","groupName":"A1","months":["$month"],"month":"$month",
  "dates":["${_weekDay(0)}","${_weekDay(2)}"],
  "criteria":[{"id":"c1","name":"Uy vazifa","done":2,"total":4}],
  "lessons":[{"date":"${_weekDay(0)}","doneCriterionIds":["c1"]},
             {"date":"${_weekDay(2)}","doneCriterionIds":[]}],
  "monthBall":7,"totalBall":25}]
''';
}

void main() {
  setUpAll(() async {
    // O'lchovlar qurilmadagidek bo'lsin (qarang test_harness.dart -> loadRealFonts).
    await loadRealFonts();
  });

  // =========================================================================
  group('Davr tanlagich', () {
    testWidgets('ochilganda JORIY HAFTA so\'raladi', (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      final reqs = api.requestsFor('/student/journal');
      expect(reqs.length, 1);
      final now = DateTime.now();
      expect(reqs.first.queryParameters['from'], isoDate(weekStart(now)));
      expect(reqs.first.queryParameters['to'], isoDate(weekEnd(now)));
      expect(find.text('Umumiy statistika'), findsOneWidget);
      expect(find.text(fmtRange(weekStart(now), weekEnd(now))), findsOneWidget);
    });

    testWidgets("«Oy» tanlansa joriy OY oralig'i so'raladi", (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.text('Oy'));
      await settle(tester);
      expectNoRealErrors(tester);

      final reqs = api.requestsFor('/student/journal');
      expect(reqs.length, 2);
      final (mf, mt) = monthBounds(DateTime.now());
      expect(reqs.last.queryParameters['from'], isoDate(mf));
      expect(reqs.last.queryParameters['to'], isoDate(mt));
    });

    testWidgets('orqaga strelka — OLDINGI hafta', (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await settle(tester);
      expectNoRealErrors(tester);

      final w = weekStart(DateTime.now());
      final prev = DateTime(w.year, w.month, w.day - 7);
      final reqs = api.requestsFor('/student/journal');
      expect(reqs.length, 2);
      expect(reqs.last.queryParameters['from'], isoDate(prev));
      expect(reqs.last.queryParameters['to'], isoDate(weekEnd(prev)));
    });

    testWidgets('KELAJAKKA o\'tib bo\'lmaydi — joriy haftada oldinga strelka ishlamaydi',
        (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await settle(tester);
      expectNoRealErrors(tester);

      // Yangi so'rov KETMAYDI va sarlavha o'zgarmaydi.
      expect(api.requestsFor('/student/journal').length, 1);
      final now = DateTime.now();
      expect(find.text(fmtRange(weekStart(now), weekEnd(now))), findsOneWidget);
    });

    testWidgets('orqaga qaytilgach oldinga strelka ISHLAYDI', (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await settle(tester);
      expectNoRealErrors(tester);

      final reqs = api.requestsFor('/student/journal');
      expect(reqs.length, 3);
      expect(reqs.last.queryParameters['from'], isoDate(weekStart(DateTime.now())));
    });
  });

  // =========================================================================
  group('Umumiy tab', () {
    testWidgets('KPI va davr bo\'limlari chiziladi', (tester) async {
      useTallScreen(tester);
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);
      api.on('/student/notebook', _notebookJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('4.5'), findsWidgets); // KPI: o'rtacha baho
      expect(find.text('75%'), findsWidgets); // KPI + donut: davomat
      expect(find.text('Xulq'), findsOneWidget);
      expect(find.text("4 darsdan 3 tasida qatnashildi"), findsOneWidget);
      expect(find.text("Fanlar bo'yicha"), findsOneWidget);
      expect(find.text('Grammar'), findsWidgets);
      expect(find.text('Speaking'), findsWidgets);
    });

    testWidgets("davrga bog'liq bo'lmagan bloklar ochiq belgilangan", (tester) async {
      useTallScreen(tester);
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);
      api.on('/student/notebook', _notebookJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      // Sarlavha ostidagi izoh — foydalanuvchi bu blok davr filtriga
      // bo'ysunmasligini BILISHI kerak.
      expect(find.text('Baholar trendi'), findsOneWidget);
      expect(find.text("Oxirgi 6 oy — davr filtriga bog'liq emas"), findsWidgets);
    });

    testWidgets("bo'sh davr — 'dars bo'lmagan' holati (RangeError/NaN yo'q)", (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _emptyJournalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Bu davrda dars bo'lmagan"), findsOneWidget);
      expect(find.text('—'), findsWidgets); // baho/davomat yo'q — 0% EMAS
      expect(find.textContaining('NaN'), findsNothing);
    });
  });

  // =========================================================================
  group('Baholar tab', () {
    testWidgets('faqat BAHO qo\'yilgan darslar, sana bo\'yicha guruhlangan', (tester) async {
      useTallScreen(tester);
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.text('Baholar'));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Har darsga olingan baho'), findsOneWidget);
      // "2 ta" ikki marta: 2 ta baho va 2 ta fan (halqa yonidagi ikki qator).
      expect(find.text('2 ta'), findsNWidgets(2));
      // Baholi darslar (mavzusi bilan) ko'rinadi...
      expect(find.text('5'), findsWidgets);
      expect(find.text('4'), findsWidgets);
      expect(find.text('1-dars · Present Simple'), findsOneWidget);
      expect(find.text('2-dars · Past Simple'), findsOneWidget);
      // ...bahosizlari esa UMUMAN chiqmaydi.
      expect(find.text('1-dars · Hobbies'), findsNothing);
      expect(find.text('Kasal'), findsNothing);
      // Sana sarlavhasi (guruhlash) — "12 Mart" ko'rinishida.
      expect(find.text(dayDividerLabel('2026-03-09')), findsOneWidget);
    });

    testWidgets("baho yo'q davrda tushunarli bo'sh holat", (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _emptyJournalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.text('Baholar'));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Bu davrda dars bo'lmagan"), findsOneWidget);
    });
  });

  // =========================================================================
  group('Davomat tab', () {
    testWidgets('keldi / sabab / belgilanmagan — uchala holat', (tester) async {
      useTallScreen(tester);
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      // "Davomat" matni Umumiy tabdagi bo'lim sarlavhasida ham bor — tab chipi
      // daraxtda BIRINCHI (ro'yxatdan yuqorida).
      await tester.tap(find.text('Davomat').first);
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("O'tilgan dars"), findsOneWidget);
      expect(find.text('Keldi'), findsWidgets);
      expect(find.text('Kasal'), findsOneWidget); // sabab chipi (reasonShort)
      // Sababsiz VA "keldi" belgilanmagan dars "Qoldirdi" deb ko'rsatilmaydi.
      expect(find.text('Belgilanmagan'), findsOneWidget);
      expect(find.text("Darslar bo'yicha"), findsOneWidget);
    });
  });

  // =========================================================================
  group('Baholash tab', () {
    testWidgets('ball OY nomi bilan + hafta izohi ko\'rinadi', (tester) async {
      useTallScreen(tester);
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);
      api.on('/student/grading', _gradingJson());

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.text('Baholash'));
      await settle(tester);
      expectNoRealErrors(tester);

      final month = _weekDay(0).substring(0, 7);
      expect(find.text(fmtMonth(month)), findsOneWidget); // ball plitasi yorlig'i
      expect(find.text('7'), findsOneWidget); // oylik ball
      expect(find.text('25'), findsOneWidget); // jami ball
      // Mezon nomi: oylik xulosada 1 marta + har darslik chiplarida 2 marta.
      expect(find.text('Uy vazifa'), findsNWidgets(3));
      expect(find.text('2/4 · 50%'), findsOneWidget);
      // HAFTA rejimida ball baribir OYGA tegishli — bu ochiq yozilishi shart.
      expect(find.text("Ball butun oy bo'yicha hisoblanadi — tanlangan hafta emas."),
          findsOneWidget);
      expect(find.text('Oylik xulosa (butun oy)'), findsOneWidget);
    });

    testWidgets('hafta IKKI oyga bo\'linsa — ikkala oy so\'raladi', (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);
      api.on('/student/grading', '[]');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);

      // Oy chegarasidan o'tadigan haftani topguncha orqaga qaytamiz (ko'pi bilan
      // 5 hafta — har oyda bunday hafta bor).
      var anchor = weekStart(DateTime.now());
      for (var i = 0; i < 6 && weekEnd(anchor).month == anchor.month; i++) {
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await settle(tester, frames: 3);
        anchor = DateTime(anchor.year, anchor.month, anchor.day - 7);
      }
      expect(weekEnd(anchor).month == anchor.month, isFalse,
          reason: 'oy chegarasidagi hafta topilmadi');

      await tester.tap(find.text('Baholash'));
      await settle(tester);
      expectNoRealErrors(tester);

      // `/student/grading` faqat OY qabul qiladi — shuning uchun ikkala oy
      // alohida so'raladi va javoblar klientda birlashtiriladi.
      final months = api
          .requestsFor('/student/grading')
          .map((r) => r.queryParameters['month'])
          .toSet();
      expect(months.length, 2);
      expect(months, contains(isoDate(anchor).substring(0, 7)));
      expect(months, contains(isoDate(weekEnd(anchor)).substring(0, 7)));
    });

    testWidgets('mezon biriktirilmagan — bo\'sh holat', (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);
      api.on('/student/grading', '[]');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.text('Baholash'));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Baholash mavjud emas'), findsOneWidget);
    });

    testWidgets('baholash xatosi butun ekranni buzmaydi', (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);
      api.failOn('/student/grading');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.text('Baholash'));
      await settle(tester);
      expectNoRealErrors(tester);

      // Jurnal muvaffaqiyatli tushgani uchun "Yuklab bo'lmadi" CHIQMAYDI.
      expect(find.text("Yuklab bo'lmadi"), findsNothing);
      expect(find.text('Baholash mavjud emas'), findsOneWidget);
    });
  });

  // =========================================================================
  group('Xato holatlari', () {
    testWidgets('API 403 — ekran qulamaydi, sabab + qayta urinish', (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', '{"message":"Ruxsat yo\'q"}', status: 403);

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
      expect(find.text("Ruxsat yo'q"), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('API 500 — ekran qulamaydi', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/journal');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("notebook tushmasa ham asosiy ekran ishlaydi", (tester) async {
      final api = installFakeApi();
      api.on('/student/journal', _journalJson);
      api.failOn('/student/notebook');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      // Qo'shimcha (davrga bog'liq bo'lmagan) blok yo'qoladi, xolos.
      expect(find.text("Yuklab bo'lmadi"), findsNothing);
      expect(find.text('Baholar trendi'), findsNothing);
      expect(find.text("Fanlar bo'yicha"), findsOneWidget);
    });
  });
}
