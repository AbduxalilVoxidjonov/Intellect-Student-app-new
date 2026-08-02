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
import 'package:student/screens/attendance_screen.dart';
import 'package:student/screens/certificates_screen.dart';
import 'package:student/screens/discipline_screen.dart';
import 'package:student/screens/finance_screen.dart';
import 'package:student/screens/grades_screen.dart';
import 'package:student/screens/online_test_screen.dart';
import 'package:student/screens/statistics_screen.dart';
import 'package:student/screens/support_screen.dart';
import 'package:student/screens/tabs/tests_screen.dart';
import 'package:student/theme/app_theme.dart';

import 'test_harness.dart';

void main() {
  setUpAll(() async {
    // Bu fayldagi o'lchovlar QURILMADAGIDEK bo'lishi uchun haqiqiy Roboto
    // yuklanadi (qarang test_harness.dart -> loadRealFonts).
    expect(await loadRealFonts(), isTrue,
        reason: 'Roboto topilmadi — overflow o\'lchovlari haqiqiy emas');
  });

  testWidgets('StatisticsScreen — 4 ta KPI plitasi toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/notebook', '''
{"id":"s1","fullName":"Ali","className":"A1","balance":0,"avgGrade":4.75,
 "subjects":[{"id":"sub1","name":"Ingliz tili grammatikasi (kengaytirilgan)"}],
 "grades":{"sub1":{"2026-01":4.5}},
 "attendance":{"missedDays":{},"illnessDays":{},"missedLessons":{},"illnessLessons":{},
               "lateCount":{"1":12}},
 "conducted":120,"attended":100,"attendancePct":83.3,
 "reasons":[{"reasonId":"r1","name":"Sababsiz qoldirilgan darslar","short":"S","isLate":false,
             "count":15}],
 "disciplineScore":100,"disciplinePlus":25,"disciplineMinus":25,"disciplinePoints":[],
 "assignments":{},"evaluationTypes":[],"evaluations":[],"evaluationsBySubject":[],
 "homeworkDone":100,"homeworkMissed":20,"behaviorGood":10,"behaviorBad":5,"marksTrend":[]}
''');
    api.on('/student/grading', '[]');

    await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'StatisticsScreen 360dp');
  });

  testWidgets('StatisticsScreen — baholar trendi ustunlari toshib ketmaydi', (tester) async {
    // Bu yerda EKRAN KENGLIGI ahamiyatsiz — toshish VERTIKAL, ya'ni test
    // shriftiga bog'liq emas (qarang fayl boshidagi izoh).
    final api = installFakeApi();
    api.on('/student/notebook', '''
{"id":"s1","fullName":"Ali","className":"A1","balance":0,"avgGrade":4.5,
 "subjects":[{"id":"sub1","name":"Grammar"}],
 "grades":{"sub1":{"2026-01":4.0,"2026-02":5.0}},
 "attendance":{"missedDays":{},"illnessDays":{},"missedLessons":{},"illnessLessons":{},
               "lateCount":{}},
 "conducted":10,"attended":8,"attendancePct":80,"reasons":[],"disciplineScore":90,
 "disciplinePlus":0,"disciplineMinus":10,"disciplinePoints":[],"assignments":{},
 "evaluationTypes":[],"evaluations":[],"evaluationsBySubject":[],"homeworkDone":4,
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

  testWidgets('AttendanceScreen — 3 ta ko\'rsatkich kartasi toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/attendance', '''
{"summary":{"missedDays":{"1":12},"illnessDays":{"1":10},"missedLessons":{"1":24},
            "illnessLessons":{},"lateCount":{"1":18}},
 "rows":[{"date":"2026-03-12","period":2,"subjectId":"sub1",
          "subjectName":"Ingliz tili grammatikasi","reasonId":"r1",
          "reasonName":"Sababsiz","isLate":false,"isIll":false}]}
''');

    await tester.pumpWidget(wrapRoot(const AttendanceScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'AttendanceScreen 360dp');
  });

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

  testWidgets('GradesScreen — uzun fan nomlari bilan toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/grades', '''
{"studentId":"s1","fullName":"Ali","className":"A1","homeroomTeacher":"",
 "subjects":[{"id":"sub1","name":"Ingliz tili grammatikasi va yozma nutq"},
             {"id":"sub2","name":"Speaking"}],
 "grades":{"sub1":{"1":4.5},"sub2":{"1":5}},"attendance":{}}
''');

    await tester.pumpWidget(wrapRoot(const GradesScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'GradesScreen 360dp');
  },
      // TUZATILDI: `Ring` (lib/widgets/ui.dart) markazidagi widget endi
      // `SizedBox(size - stroke)` + `FittedBox(scaleDown)` ichida. Avval
      // markazdagi matn kengligi HECH cheklanmagandi: `GradesScreen` dagi
      // "4.50" @27px katta `textScale` da (yoki test shriftida, u yerda har
      // belgi 1em) 92dp halqaga sig'may satrga ko'chib ketardi va vertikal
      // toshish berardi. Endi sig'masa proporsional kichrayadi.
      );

  testWidgets('GradesScreen — textScale 2.0 da ham toshib ketmaydi', (tester) async {
    // Tizim sozlamasidagi katta matn (ko'rish qobiliyati past foydalanuvchilar)
    // — `Ring` markazidagi matnni cheklashning ASOSIY sababi. Bu test
    // `lib/widgets/ui.dart` dagi `FittedBox(scaleDown)` ni qo'riqlaydi:
    // usiz shu yerda "92 pixels on the bottom" toshishi qaytadi.
    useSmallScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final api = installFakeApi();
    api.on('/student/grades', '''
{"studentId":"s1","fullName":"Ali","className":"A1","homeroomTeacher":"",
 "subjects":[{"id":"sub1","name":"Ingliz tili grammatikasi va yozma nutq"},
             {"id":"sub2","name":"Speaking"}],
 "grades":{"sub1":{"1":4.5},"sub2":{"1":5}},"attendance":{}}
''');

    await tester.pumpWidget(wrapRoot(const GradesScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'GradesScreen textScale 2.0');
  });

  testWidgets('DisciplineScreen — toshib ketmaydi', (tester) async {
    useSmallScreen(tester);
    final api = installFakeApi();
    api.on('/student/discipline', '''
{"remaining":72.5,"plus":27.5,"minus":55,
 "items":[{"id":"d1","reasonName":"Darsga kechikib kelgani uchun ogohlantirish",
           "points":-2.5,"note":"Uchinchi marta","createdAt":"2026-03-01",
           "createdBy":"","source":"Jurnal"}]}
''');

    await tester.pumpWidget(wrapRoot(const DisciplineScreen()));
    await settle(tester);
    expectNoRealErrors(tester, reason: 'DisciplineScreen 360dp');
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
}
