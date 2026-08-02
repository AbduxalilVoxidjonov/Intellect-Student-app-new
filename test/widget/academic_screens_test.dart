// StatisticsScreen / AttendanceScreen / GradesScreen / DisciplineScreen —
// har biri uchun: (1) muvaffaqiyat, (2) API xatosi, (3) bo'sh ma'lumot.

import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/attendance_screen.dart';
import 'package:student/screens/discipline_screen.dart';
import 'package:student/screens/grades_screen.dart';
import 'package:student/screens/statistics_screen.dart';

import 'test_harness.dart';

const _notebookJson = '''
{
  "id": "s1", "fullName": "Ali Valiyev", "className": "A1", "balance": -50000, "avgGrade": 4.4,
  "subjects": [{"id": "sub1", "name": "Grammar"}, {"id": "sub2", "name": "Speaking"}],
  "grades": {"sub1": {"2026-01": 4.0, "2026-02": 5.0}, "sub2": {"2026-02": 4.2}},
  "attendance": {"missedDays": {}, "illnessDays": {}, "missedLessons": {"1": 2},
                 "illnessLessons": {}, "lateCount": {"1": 3}},
  "conducted": 40, "attended": 34, "attendancePct": 85,
  "reasons": [{"reasonId":"r1","name":"Kasallik","short":"K","isLate":false,"count":3}],
  "disciplineScore": 92, "disciplinePlus": 10, "disciplineMinus": 18, "disciplinePoints": [],
  "assignments": {}, "evaluationTypes": [], "evaluations": [],
  "evaluationsBySubject": [{"subjectId":"sub1","subjectName":"Grammar","avg":4.5,"evaluations":[]}],
  "homeworkDone": 8, "homeworkMissed": 2, "behaviorGood": 3, "behaviorBad": 1,
  "marksTrend": [{"month":"2026-01","homeworkDone":4,"homeworkMissed":1,
                  "behaviorGood":2,"behaviorBad":0}]
}
''';

const _emptyNotebookJson = '''
{"subjects": [], "grades": {}, "attendance": {}, "reasons": [], "disciplinePoints": [],
 "assignments": {}, "evaluationTypes": [], "evaluations": [], "evaluationsBySubject": [],
 "marksTrend": []}
''';

void main() {
  // =========================================================================
  group('StatisticsScreen', () {
    testWidgets('muvaffaqiyatli yuklash — KPI va bo\'limlar chiziladi', (tester) async {
      final api = installFakeApi();
      api.on('/student/notebook', _notebookJson);
      api.on('/student/grading', '[]');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Umumiy statistika'), findsOneWidget);
      expect(find.text('Baholar trendi'), findsOneWidget);
      expect(find.text("Fanlar bo'yicha o'rtacha"), findsOneWidget);
      expect(find.text('Davomat'), findsWidgets);
      // KPI plitasining yorlig'i — ekranda 'Intizom' (statistics_screen.dart:219).
      expect(find.text('Intizom'), findsOneWidget);
      expect(find.text('85%'), findsWidgets); // davomat foizi (KPI + donut)
      expect(find.text('Grammar'), findsWidgets);
    });

    testWidgets('API 403 — ekran qulamaydi, xato holati ko\'rinadi', (tester) async {
      final api = installFakeApi();
      api.on('/student/notebook', '{"message":"Ruxsat yo\'q"}', status: 403);
      api.on('/student/grading', '[]');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets('API 500 — ekran qulamaydi', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/notebook');
      api.on('/student/grading', '[]');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("bo'sh ma'lumot — nolga bo'lish/RangeError bo'lmaydi", (tester) async {
      final api = installFakeApi();
      api.on('/student/notebook', _emptyNotebookJson);
      api.on('/student/grading', '[]');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Hali baho yo'q."), findsOneWidget);
      expect(find.text('0%'), findsWidgets); // davomat va uy vazifa 0% (NaN emas)
      expect(find.text('—'), findsWidgets); // o'rtacha baho yo'q
    });

    testWidgets("bo'sh ma'lumotda Arxiv bo'limi ham qulamaydi", (tester) async {
      final api = installFakeApi();
      api.on('/student/notebook', _emptyNotebookJson);
      api.on('/student/grading', '[]');

      await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
      await settle(tester);
      await tester.tap(find.text('Arxiv'));
      await settle(tester, frames: 4);
      expectNoRealErrors(tester);

      expect(find.text("Arxiv bo'sh"), findsOneWidget);
    });

    testWidgets(
      "xato matnida xom `Exception:`/`DioException` bo'lmaydi",
      (tester) async {
        final api = installFakeApi();
        api.on('/student/notebook', '{"message":"Ruxsat yo\'q"}', status: 403);
        api.on('/student/grading', '[]');

        await tester.pumpWidget(wrapRoot(const StatisticsScreen()));
        await settle(tester);

        expect(find.textContaining('Exception'), findsNothing);
        // `humanError` serverning o'z xabarini ko'rsatadi + qayta urinish tugmasi.
        expect(find.text("Ruxsat yo'q"), findsOneWidget);
        expect(find.text('Qayta urinish'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  group('AttendanceScreen', () {
    const okJson = '''
{
  "summary": {"missedDays": {"1": 2}, "illnessDays": {"1": 1}, "missedLessons": {"1": 3},
              "illnessLessons": {}, "lateCount": {"1": 4}},
  "rows": [
    {"date":"2026-03-12","period":2,"subjectId":"sub1","subjectName":"Grammar",
     "reasonId":"r1","reasonName":"Kasallik","isLate":false,"isIll":true},
    {"date":"2026-03-14","period":1,"subjectId":"sub2","subjectName":"Speaking",
     "reasonId":"r2","reasonName":"Kech qoldi","isLate":true,"isIll":false}
  ]
}
''';

    testWidgets('muvaffaqiyatli yuklash', (tester) async {
      final api = installFakeApi();
      api.on('/student/attendance', okJson);

      await tester.pumpWidget(wrapRoot(const AttendanceScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Davomat'), findsOneWidget); // sarlavha
      expect(find.text('Dars qoldirildi'), findsOneWidget);
      expect(find.text('Kasallik'), findsWidgets);
      expect(find.text('Davomat tarixi'), findsOneWidget);
      expect(find.text('Grammar'), findsOneWidget);
      expect(find.text('2-dars'), findsOneWidget);
    });

    testWidgets('API 500 — xato holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/attendance');

      await tester.pumpWidget(wrapRoot(const AttendanceScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.textContaining("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("bo'sh ma'lumot — bo'sh holat, RangeError yo'q", (tester) async {
      final api = installFakeApi();
      api.on('/student/attendance', '{}');

      await tester.pumpWidget(wrapRoot(const AttendanceScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Ajoyib davomat! Qoldirilgan dars yo'q."), findsOneWidget);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets("sana/fan nomi bo'sh bo'lgan qator ham qulamaydi", (tester) async {
      final api = installFakeApi();
      api.on('/student/attendance', '''
{"summary": {}, "rows": [{"date":"","period":0,"subjectId":"","subjectName":"",
                          "reasonId":"","reasonName":"","isLate":false,"isIll":false}]}
''');

      await tester.pumpWidget(wrapRoot(const AttendanceScreen()));
      await settle(tester);
      // `r.subjectName[0]` bo'sh satrda RangeError bermasligi kerak (fallback '?').
      expectNoRealErrors(tester);
      expect(find.text('?'), findsOneWidget);
    });
  });

  // =========================================================================
  group('GradesScreen', () {
    testWidgets('muvaffaqiyatli yuklash', (tester) async {
      final api = installFakeApi();
      api.on('/student/grades', '''
{
  "studentId":"s1","fullName":"Ali","className":"A1","homeroomTeacher":"",
  "subjects":[{"id":"sub1","name":"Grammar"},{"id":"sub2","name":"Speaking"}],
  "grades":{"sub1":{"1":5.0},"sub2":{"1":4.0}},
  "attendance":{}
}
''');

      await tester.pumpWidget(wrapRoot(const GradesScreen()));
      await settle(tester);
      // `ignoreOverflow`: Ring markazidagi "4.50" (grades_screen.dart:74) test
      // shriftida 108px kenglikda chiziladi va 92dp halqaga sig'may 1px toshadi.
      // Bu TEST SHRIFTI artefakti (qarang test_harness.dart `useSmallScreen`
      // izohi) — qurilmadagi Roboto'da ~59px, toshish yo'q. Bu test mazmunni
      // tekshiradi, layoutni emas.
      expectNoRealErrors(tester, ignoreOverflow: true);

      expect(find.text('Baholar'), findsOneWidget);
      expect(find.text("Fanlar bo'yicha"), findsOneWidget);
      expect(find.text('4.50'), findsOneWidget); // o'rtacha
      expect(find.text('Grammar'), findsOneWidget);
      expect(find.text('2 ta'), findsOneWidget); // fanlar soni
    });

    testWidgets('API 500 — xato holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/grades');

      await tester.pumpWidget(wrapRoot(const GradesScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.textContaining("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("bo'sh ma'lumot — 0.00 va bo'sh holat (NaN yo'q)", (tester) async {
      final api = installFakeApi();
      api.on('/student/grades', '{}');

      await tester.pumpWidget(wrapRoot(const GradesScreen()));
      await settle(tester);
      // `ignoreOverflow`: yuqoridagi test bilan bir xil Ring artefakti
      // ("0.00" ham 4 belgi → test shriftida 108px).
      expectNoRealErrors(tester, ignoreOverflow: true);

      expect(find.text('0.00'), findsOneWidget);
      expect(find.text("Baholar yo'q. Hozircha baho qo'yilmagan."), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
    });
  });

  // =========================================================================
  group('DisciplineScreen', () {
    testWidgets('muvaffaqiyatli yuklash', (tester) async {
      final api = installFakeApi();
      api.on('/student/discipline', '''
{
  "remaining": 85, "plus": 10, "minus": 25,
  "items": [
    {"id":"d1","reasonName":"Darsga kech qolish","points":-5,"note":"","createdAt":"2026-03-01",
     "createdBy":"","source":"Jurnal"},
    {"id":"d2","reasonName":"Faol ishtirok","points":10,"note":"Olimpiada","createdAt":"2026-03-05",
     "createdBy":"","source":""}
  ]
}
''');

      await tester.pumpWidget(wrapRoot(const DisciplineScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Joriy intizomiy ball'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
      expect(find.text('+10'), findsWidgets);
      expect(find.text('−25'), findsOneWidget);
      expect(find.text('Darsga kech qolish'), findsOneWidget);
    });

    testWidgets('API 500 — xato holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/discipline');

      await tester.pumpWidget(wrapRoot(const DisciplineScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.textContaining("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("bo'sh ma'lumot — bo'sh holat", (tester) async {
      final api = installFakeApi();
      api.on('/student/discipline', '{}');

      await tester.pumpWidget(wrapRoot(const DisciplineScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yozuv yo'q. Hozircha intizomiy ball o'zgarmagan."), findsOneWidget);
    });
  });
}
