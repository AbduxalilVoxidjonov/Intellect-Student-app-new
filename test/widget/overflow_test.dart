// KICHIK EKRAN (360x640 dp) — "RenderFlex overflowed" bo'lmasligi tekshiriladi.
// `expectNoRealErrors` overflow xatolarini ham ushlaydi (ular FlutterError sifatida
// chizish paytida qayd etiladi).
//
// ------------------------------------------------------------------------------
// TEST SHRIFTI HAQIDA (natijalarni to'g'ri o'qish uchun MUHIM)
// ------------------------------------------------------------------------------
// Bu fayl `setUpAll` da HAQIQIY Roboto shriftini yuklaydi (`loadRealFonts()`,
// qarang test_harness.dart), shuning uchun o'lchovlar qurilmadagiga MOS keladi.
// Busiz `flutter test` "FlutterTest" (Ahem uslubidagi) zaxira shriftni
// ishlatadi — u yerda HAR BIR BELGI aynan 1em kenglikda chiziladi, ya'ni
// matn ~2 baravar keng ("4.50" @27px: zaxirada 108px, Roboto'da 56px) va
// gorizontal toshish testda qurilmadagidan ancha erta "topiladi".
//
// Shrift topilmasa (SDK keshi yo'q) `loadRealFonts()` `false` qaytaradi va
// `setUpAll` dagi `expect` shu holatni ochiq ko'rsatadi — testlar jimgina
// noto'g'ri o'lchov bilan ishlab ketmaydi.
//
// Katta matn masshtabi (textScale) — alohida stsenariy: tizim sozlamasi
// 1.5-2.0 bo'lganda layout haqiqatan toshib ketishi mumkin, shuning uchun
// eng zichlari uchun aniq test bor (qarang GradesScreen textScale 2.0).

import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/certificates_screen.dart';
import 'package:student/screens/finance_screen.dart';
import 'package:student/screens/online_test_screen.dart';
import 'package:student/screens/statistics_screen.dart';
import 'package:student/screens/support_screen.dart';
import 'package:student/screens/tabs/progress_screen.dart';
import 'package:student/screens/tabs/tests_screen.dart';
import 'package:student/theme/app_theme.dart';
import 'package:student/widgets/podium.dart';

import 'test_harness.dart';

/// Uzun fan/mavzu nomlari va katta raqamlar bilan bitta haftalik jurnal —
/// «Umumiy statistika» ning barcha tablari shu javobdan quriladi.
const _journalJson = '''
{"from":"2026-03-09","to":"2026-03-15","groupId":"",
 "groups":[{"groupId":"g1","groupName":"Ingliz tili Intermediate B2 kechki guruh",
            "courseName":"Ingliz tili grammatikasi (kengaytirilgan)","teacherName":"Aziza"}],
 "summary":{"held":120,"attended":100,"absent":15,"late":5,"attendancePct":83,
            "gradesCount":40,"avgGrade":4.75,"homeworkDone":100,"homeworkMissed":20,
            "behaviorGood":10,"behaviorBad":5},
 "subjects":[{"subjectId":"sub1","subjectName":"Ingliz tili grammatikasi (kengaytirilgan)",
              "held":120,"attended":100,"gradesCount":40,"avgGrade":4.75}],
 "lessons":[
   {"date":"2026-03-09","period":1,"groupId":"g1",
    "groupName":"Ingliz tili Intermediate B2 kechki guruh","subjectId":"sub1",
    "subjectName":"Ingliz tili grammatikasi (kengaytirilgan)",
    "topic":"Present Perfect Continuous va uning qo'llanilishi","homeworkText":"Unit 1",
    "conducted":true,"present":true,"grade":5,"reasonName":null,"reasonShort":null,
    "isLate":false,"homeworkMark":1,"behavior":1,"mastery":2},
   {"date":"2026-03-11","period":2,"groupId":"g1",
    "groupName":"Ingliz tili Intermediate B2 kechki guruh","subjectId":"sub1",
    "subjectName":"Ingliz tili grammatikasi (kengaytirilgan)","topic":"","homeworkText":"",
    "conducted":true,"present":false,"grade":null,
    "reasonName":"Sababsiz qoldirilgan darslar","reasonShort":"Sababsiz qoldirdi",
    "isLate":false,"homeworkMark":0,"behavior":0,"mastery":null}
 ]}
''';

void main() {
  setUpAll(() async {
    // Bu fayldagi o'lchovlar QURILMADAGIDEK bo'lishi uchun haqiqiy Roboto
    // yuklanadi (qarang test_harness.dart -> loadRealFonts).
    expect(await loadRealFonts(), isTrue,
        reason: 'Roboto topilmadi — overflow o\'lchovlari haqiqiy emas');
  });

  testWidgets('StatisticsScreen — davr tanlagich + tablar + KPI toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/journal', _journalJson);
    api.on('/student/notebook', '''
{"id":"s1","fullName":"Ali","className":"A1","balance":0,"avgGrade":4.75,
 "subjects":[{"id":"sub1","name":"Ingliz tili grammatikasi (kengaytirilgan)"}],
 "grades":{"sub1":{"2026-01":4.5}},
 "attendance":{"missedDays":{},"illnessDays":{},"missedLessons":{},"illnessLessons":{},
               "lateCount":{"1":12}},
 "conducted":120,"attended":100,"attendancePct":83.3,
 "reasons":[{"reasonId":"r1","name":"Sababsiz qoldirilgan darslar","short":"S","isLate":false,
             "count":15}],
 "homeworkDone":100,"homeworkMissed":20,"behaviorGood":10,"behaviorBad":5,"marksTrend":[]}
''');
    api.on('/student/grading', '[]');

    await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'StatisticsScreen 360dp');
  });

  testWidgets('StatisticsScreen — textScale 2.0 da davr tanlagich toshib ketmaydi',
      (tester) async {
    // Tizim sozlamasidagi katta matn: segment/nav/tab chiplarining balandligi
    // QAT'IY EMAS (padding bilan) — aks holda 46dp ichida matn sig'masdi.
    useSmallScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final api = installFakeApi();
    api.on('/student/journal', _journalJson);
    api.on('/student/grading', '[]');

    await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'StatisticsScreen textScale 2.0');
  });

  testWidgets('StatisticsScreen — Baholar tabi uzun mavzu bilan toshmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/journal', _journalJson);

    await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
    await settle(tester);
    await tester.tap(find.text('Baholar'));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'StatisticsScreen Baholar 360dp');
  });

  testWidgets('StatisticsScreen — Davomat tabi uzun sabab chipi bilan toshmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/journal', _journalJson);

    await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
    await settle(tester);
    await tester.tap(find.text('Davomat').first);
    await settle(tester);
    expectNoRealErrors(tester, reason: 'StatisticsScreen Davomat 360dp');
  },
      // TUZATILDI: sabab chipi `ConstrainedBox(maxWidth: 118)` ichida — uzun
      // sabab nomi qatorni yon tomonga surib toshirardi.
      );

  testWidgets('StatisticsScreen — baholar trendi ustunlari toshib ketmaydi', (tester) async {
    // Bu yerda EKRAN KENGLIGI ahamiyatsiz — toshish VERTIKAL, ya'ni test
    // shriftiga bog'liq emas (qarang fayl boshidagi izoh).
    final api = installFakeApi();
    api.on('/student/journal', _journalJson);
    api.on('/student/notebook', '''
{"id":"s1","fullName":"Ali","className":"A1","balance":0,"avgGrade":4.5,
 "subjects":[{"id":"sub1","name":"Grammar"}],
 "grades":{"sub1":{"2026-01":4.0,"2026-02":5.0}},
 "attendance":{"missedDays":{},"illnessDays":{},"missedLessons":{},"illnessLessons":{},
               "lateCount":{}},
 "conducted":10,"attended":8,"attendancePct":80,"reasons":[],"homeworkDone":4,
 "homeworkMissed":1,"behaviorGood":0,"behaviorBad":0,"marksTrend":[]}
''');
    api.on('/student/grading', '[]');

    await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'StatisticsScreen baholar trendi');
  },
      // TUZATILDI: `_TrendBars` da qat'iy `SizedBox(height: 116)` o'rniga
      // `ConstrainedBox(minHeight: 116)` — balandlik mazmunga qarab o'sadi
      // (maksimal bahoda kerakli ~123dp), past ustunlarda esa avvalgidek 116dp.
      );

  testWidgets('FinanceScreen — uzun summalar bilan toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/finance', '''
{"student":{"id":"s1","fullName":"Ali","className":"A1"},
 "balance":-12500000,"monthlyFee":1250000,"totalCharged":15000000,
 "totalDiscount":2500000,"totalPaid":12500000,
 "months":[{"month":"2026-01","charged":1250000,"discount":250000,"paid":1000000,
            "remaining":0,"status":"partial",
            "courses":[{"courseName":"Ingliz tili (kengaytirilgan kurs)","fee":1250000}]}],
 "payments":[{"date":"2026-01-05","amount":1000000,"note":"Naqd to'lov, kassa orqali"}]}
''');

    await tester.pumpWidget(wrapRoot(const FinanceScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'FinanceScreen 360dp');
  },
      // TUZATILDI: "Chegirma" kartasidagi summa `Text` i `Flexible` ga o'raldi.
      );

  testWidgets('StatisticsScreen — Baholar tabi textScale 2.0 da ham toshmaydi', (tester) async {
    // `Ring` markazidagi "4.8" @27px katta shriftda 92dp halqaga sig'masligi
    // mumkin — `lib/widgets/ui.dart` dagi `FittedBox(scaleDown)` shuni ushlaydi.
    useSmallScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final api = installFakeApi();
    api.on('/student/journal', _journalJson);

    await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
    await settle(tester);
    await tester.tap(find.text('Baholar'));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'StatisticsScreen Baholar textScale 2.0');
  });

  testWidgets('TestsScreen — uzun test nomi bilan toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/online-tests', '''
[{"id":"t1","groupId":"g1","groupName":"Ingliz tili Intermediate B2 kechki guruh",
  "name":"Unit 1-2-3 oraliq nazorat testi (yozma)","date":"2026-08-01",
  "questionCount":40,"optionCount":4,"startAt":"2026-08-01T09:00","endAt":"2026-08-01T10:00",
  "pdfUrl":"/uploads/t1.pdf","pdfName":"savollar.pdf","state":"open","answers":"",
  "submittedAt":""}]
''');
    api.on('/student/test-results', '''
[{"testId":"tr1","groupId":"g1","groupName":"Ingliz tili Intermediate B2 kechki guruh",
  "name":"Yakuniy nazorat testi","date":"2026-03-01","maxScore":100,"score":87,
  "rank":3,"total":24}]
''');

    await tester.pumpWidget(wrapBody(const TestsScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'TestsScreen 360dp');
  },
      // TUZATILDI: natija kartasidagi oxirgi `Column` `Flexible` ga o'raldi.
      );

  testWidgets('SupportScreen — ochilgan akkordeon toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/support', '''
{"myBookings":[{"id":"b1","teacherId":"t1","teacherName":"Aziza Karimova Baxtiyorovna",
                "date":"2026-08-05","startTime":"15:00","endTime":"15:30",
                "status":"booked","topic":"","notes":""}],
 "supports":[{"teacherId":"t1","fullName":"Aziza Karimova Baxtiyorovna",
              "subject":"Ingliz tili (Speaking)",
              "openSlots":[{"id":"s1","date":"2026-08-01","startTime":"09:00",
                            "endTime":"09:30"}]}]}
''');

    await tester.pumpWidget(wrapRoot(const SupportScreen()));
    await settle(tester);
    await tester.tap(find.text('Aziza Karimova Baxtiyorovna').last);
    await settle(tester, frames: 4);
    expectNoRealErrors(tester, reason: 'SupportScreen 360dp');
  });

  testWidgets('CertificatesScreen — uzun kurs nomi bilan toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/certificates', '''
[{"id":"c1","courseName":"Ingliz tili — Intermediate (B1/B2) to'liq kurs",
  "issuedAt":"2026-01-15","expiresAt":"2027-01-15","status":"active",
  "fileName":"intellect-sertifikat-2026-01-15.pdf","downloadUrl":"/uploads/c1.pdf",
  "downloadCount":12}]
''');

    await tester.pumpWidget(wrapRoot(const CertificatesScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'CertificatesScreen 360dp');
  },
      // TUZATILDI: sariq "hisobot" kartasidagi `Column` `Expanded` ga o'raldi.
      );

  testWidgets('OnlineTestScreen — 40 savollik varaqa toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/online-tests/t1', '''
{"id":"t1","groupId":"g1","groupName":"Ingliz tili Intermediate B2",
 "name":"Unit 1-2-3 oraliq nazorat testi","date":"2026-08-01",
 "questionCount":40,"optionCount":5,"startAt":"2026-08-01T09:00","endAt":"2026-08-01T10:00",
 "pdfUrl":"/uploads/t1.pdf","pdfName":"savollar-unit-1-2-3.pdf","state":"open",
 "answers":"","submittedAt":"","answerKey":"","rank":0,"participants":0}
''');

    await tester.pumpWidget(wrapRoot(const OnlineTestScreen(testId: 't1')));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'OnlineTestScreen 360dp');
  });

  testWidgets('Tungi rejim (dark) ham toshmasdan chiziladi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/finance', '{"balance": -450000, "monthlyFee": 450000}');

    await tester.pumpWidget(wrapRoot(const FinanceScreen(), colors: AppColors.dark));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'FinanceScreen dark 360dp');
  });

  // -------------------------------------------------------------------------
  // REYTING PODIUMI — 3 USTUNLI Row, ya'ni eng xavfli joy.
  //
  // 360dp da har bir ustunga ~110dp qoladi; uzun FISH va katta ball raqami
  // bilan matn sig'masligi mumkin. Shuning uchun ikkala reyting rejimi ham
  // (guruh + markaz) va katta matn masshtabi alohida sinaladi.
  // -------------------------------------------------------------------------

  /// Ataylab UZUN ismlar va KATTA ballar (5 xonali) — podium matnlari eng keng holat.
  const podiumRatingJson = '''
{
  "meStudentId": "s1", "classRows": [],
  "schoolRows": [
    {"rank": 1, "studentId": "x1", "fullName": "Abdurahmonova Gulnoraxon Baxtiyorovna", "className": "Ingliz tili Intermediate B2 kechki guruh", "average": 4.85, "attendance": 100, "ball": 12850},
    {"rank": 2, "studentId": "s1", "fullName": "Mirzayev Abdulaziz Shuxratovich", "className": "Ingliz tili Intermediate B2 kechki guruh", "average": 4.75, "attendance": 98, "ball": 11200},
    {"rank": 3, "studentId": "x3", "fullName": "To'lqinov Jasurbek Ulug'bekovich", "className": "Matematika (kengaytirilgan) B1", "average": 4.55, "attendance": 95, "ball": 10990}
  ],
  "meSchoolRank": 2, "schoolSize": 3400,
  "groups": [
    {
      "groupId": "g1", "groupName": "Ingliz tili Intermediate B2 kechki guruh", "meRank": 2, "size": 4,
      "rows": [
        {"rank": 1, "studentId": "x1", "fullName": "Abdurahmonova Gulnoraxon Baxtiyorovna", "className": "Ingliz tili Intermediate B2 kechki guruh", "average": 4.85, "attendance": 100, "ball": 12850},
        {"rank": 2, "studentId": "s1", "fullName": "Mirzayev Abdulaziz Shuxratovich", "className": "Ingliz tili Intermediate B2 kechki guruh", "average": 4.75, "attendance": 98, "ball": 11200},
        {"rank": 3, "studentId": "x3", "fullName": "To'lqinov Jasurbek Ulug'bekovich", "className": "Ingliz tili Intermediate B2 kechki guruh", "average": 4.55, "attendance": 95, "ball": 10990},
        {"rank": 4, "studentId": "x4", "fullName": "Yo'ldosheva Dilnozaxon Farrux qizi", "className": "Ingliz tili Intermediate B2 kechki guruh", "average": 4.10, "attendance": 80, "ball": 9870}
      ]
    },
    {
      "groupId": "g2", "groupName": "Matematika (kengaytirilgan) B1", "meRank": 1, "size": 2,
      "rows": [
        {"rank": 1, "studentId": "s1", "fullName": "Mirzayev Abdulaziz Shuxratovich", "className": "Matematika (kengaytirilgan) B1", "average": 5.0, "attendance": 99, "ball": 4400},
        {"rank": 2, "studentId": "x9", "fullName": "Qodirova Kamolaxon Zafarovna", "className": "Matematika (kengaytirilgan) B1", "average": 4.4, "attendance": 91, "ball": 3300}
      ]
    }
  ]
}
''';

  Future<void> openProgressRating(WidgetTester tester, String tab) async {
    final api = installFakeApi();
    api.on('/student/curriculum', '[]');
    api.on('/student/rating', podiumRatingJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await tester.tap(find.text(tab));
    await settle(tester, frames: 3);
  }

  testWidgets('Progress → Guruh podiumi 360dp da toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    await openProgressRating(tester, 'Guruh');
    expect(find.byType(PodiumCard), findsNWidgets(3));
    expectNoRealErrors(tester, reason: 'Guruh podiumi 360dp');
  });

  testWidgets('Progress → Markaz podiumi 360dp da toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    await openProgressRating(tester, 'Markaz');
    expect(find.byType(PodiumCard), findsNWidgets(3));
    expectNoRealErrors(tester, reason: 'Markaz podiumi 360dp');
  });

  testWidgets('Progress → podium textScale 2.0 da ham toshmaydi', (tester) async {
    // Eng og'ir holat: 360dp × 3 ustun × 2x matn. Kartochkadagi matnlar shu
    // sabab `maxLines: 1` + ellipsis (ball raqami esa `Flexible` ichida).
    useSmallScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openProgressRating(tester, 'Guruh');
    expectNoRealErrors(tester, reason: 'podium textScale 2.0');
  });

  testWidgets('Progress → podium tungi rejimda ham toshmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/curriculum', '[]');
    api.on('/student/rating', podiumRatingJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen(), colors: AppColors.dark));
    await settle(tester);
    await tester.tap(find.text('Guruh'));
    await settle(tester, frames: 3);
    expectNoRealErrors(tester, reason: 'podium dark 360dp');
  });
}
