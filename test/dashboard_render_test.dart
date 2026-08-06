import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:student/api/api_client.dart';
import 'package:student/services/session.dart';
import 'package:student/theme/app_theme.dart';
import 'package:student/screens/tabs/dashboard_screen.dart';

const _dashboardJson = '''
{
  "profile": {"id": "s1", "fullName": "Ali Valiyev", "className": "Ingliz tili A1", "birthDate": "", "gender": "male", "parentFullName": "", "parentPhone": "", "enrollmentDate": ""},
  "meta": {"lessonTimes": [], "absenceReasons": [], "currentQuarter": 1, "currentWeek": 1},
  "todayLessons": [],
  "todayGrades": [],
  "balance": -150000,
  "monthlyFee": 450000
}
''';

const _notebookJson = '''
{
  "id": "s1", "fullName": "Ali Valiyev", "className": "Ingliz tili A1", "balance": -150000, "avgGrade": 4.2,
  "subjects": [{"id": "sub1", "name": "Grammar"}],
  "grades": {"Grammar": {"2026-01": 4.5}, "Speaking": {"2026-01": 3.8}, "Listening": {"2026-01": 5.0}},
  "attendance": {"missedDays": {}, "illnessDays": {}, "missedLessons": {}, "illnessLessons": {}, "lateCount": {}},
  "conducted": 40, "attended": 34, "attendancePct": 85,
  "reasons": [],
  "homeworkDone": 8, "homeworkMissed": 2, "behaviorGood": 3, "behaviorBad": 1, "marksTrend": []
}
''';

const _ratingJson = '''
{
  "meStudentId": "s1",
  "classRows": [{"rank": 1, "studentId": "s1", "fullName": "Ali Valiyev", "className": "Ingliz tili A1", "average": 4.2, "ball": 320}],
  "schoolRows": [{"rank": 5, "studentId": "s1", "fullName": "Ali Valiyev", "className": "Ingliz tili A1", "average": 4.2, "ball": 320}],
  "meSchoolRank": 5, "schoolSize": 120
}
''';

const _schoolJson = '{"name": "Intellect School", "telegramChannel": "@intellectschool"}';

// "Guruh" kartasi ALOHIDA endpointdan (`/student/groups`) keladi — soxta javob
// berilmasa `groups()` xato beradi va karta umuman chizilmaydi (test yiqilardi).
const _groupsJson = '''
[{
  "groupId": "g1", "name": "Ingliz tili A1", "courseName": "Ingliz tili",
  "teacherName": "Aziza Karimova", "days": [0, 2, 4],
  "startTime": "14:00", "endTime": "15:30", "room": "204",
  "state": "active", "status": "active", "isActive": true, "groupArchived": false,
  "joinedAt": "2026-01-10", "leftAt": ""
}]
''';

const _notificationsJson = '''
{
  "unread": 3,
  "items": [
    {"id": "n1", "title": "Yangi baho", "body": "Grammar fanidan 5 baho qo'yildi.", "type": "grade", "createdAt": "2026-07-14T09:00:00", "read": false, "confirmed": false},
    {"id": "n2", "title": "Ruxsatnoma", "body": "Ertangi tadbirga ruxsat bering.", "type": "permission", "createdAt": "2026-07-13T15:00:00", "read": true, "confirmed": false}
  ]
}
''';

/// Xulqi FAQAT salbiy o'quvchi — "0%" va "ma'lumot yo'q" (—) farqi uchun.
const _zeroBehaviorNotebookJson = '''
{
  "id": "s1", "fullName": "Ali Valiyev", "className": "Ingliz tili A1", "balance": 0, "avgGrade": 0,
  "subjects": [], "grades": {},
  "attendance": {"missedDays": {}, "illnessDays": {}, "missedLessons": {}, "illnessLessons": {}, "lateCount": {}},
  "conducted": 0, "attended": 0, "attendancePct": 0,
  "reasons": [],
  "homeworkDone": 0, "homeworkMissed": 0, "behaviorGood": 0, "behaviorBad": 5, "marksTrend": []
}
''';

class _FakeAdapter implements HttpClientAdapter {
  /// `null` — standart (`_notebookJson`) javob.
  final String? notebook;
  _FakeAdapter({this.notebook});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    final p = options.path;
    String body = '{}';
    if (p.contains('/student/dashboard')) {
      body = _dashboardJson;
    } else if (p.contains('/student/groups')) {
      body = _groupsJson;
    } else if (p.contains('/student/notebook')) {
      body = notebook ?? _notebookJson;
    } else if (p.contains('/student/rating')) {
      body = _ratingJson;
    } else if (p.contains('/student/school')) {
      body = _schoolJson;
    } else if (p.contains('/student/notifications')) {
      body = _notificationsJson;
    }
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Widget _app() => ChangeNotifierProvider<Session>(
      create: (_) => Session(),
      child: MaterialApp(
        builder: (context, child) =>
            AppTheme(colors: AppColors.light, child: child ?? const SizedBox()),
        home: const Scaffold(body: DashboardScreen()),
      ),
    );

/// Barcha async yuklashlar tugashini kutadi (`pumpAndSettle` ISHLAMAYDI —
/// `Loader` cheksiz animatsiya qiladi).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('DashboardScreen renders success path with real data', (tester) async {
    ApiClient.dio.httpClientAdapter = _FakeAdapter();

    await tester.pumpWidget(_app());
    await _settle(tester);

    final ex = tester.takeException();
    expect(ex, isNull, reason: 'success path threw: $ex');

    // Asosiy kartalar chindan ekranda bo'lishi kerak (web Dashboard.tsx tarkibi).
    // Guruh kartasi: nom + holat yorlig'i (ilgari "Guruh" degan sarlavha bor edi —
    // u olib tashlangan, endi karta guruh nomining o'zi bilan boshlanadi).
    expect(find.text('Ingliz tili A1'), findsOneWidget);
    expect(find.text('Aktiv'), findsOneWidget);
    expect(find.text('Balans'), findsOneWidget);
    expect(find.text('Dars qoldirdi'), findsOneWidget);
    expect(find.textContaining('Umumiy statistika'), findsWidgets);
    expect(find.text("O'rtacha baho"), findsOneWidget);
    expect(find.text('Davomat'), findsOneWidget);
  });

  // "MA'LUMOT YO'Q" (belgi umuman yo'q → "—") va "0%" ikki BOSHQA holat.
  // Bu qoida ilgari intizom ballida edi; modul olib tashlangach "Xulq" kartasiga o'tdi.
  testWidgets("xulq faqat salbiy — '—' emas, '0%' ko'rsatiladi", (tester) async {
    // Baland ekran: xulq kartasi ListView ning pastida — kichik ekranda
    // umuman qurilmaydi va `find.text` uni topa olmaydi.
    tester.view.physicalSize = const Size(800 * 3, 2000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    ApiClient.dio.httpClientAdapter = _FakeAdapter(notebook: _zeroBehaviorNotebookJson);

    await tester.pumpWidget(_app());
    await _settle(tester);

    expect(tester.takeException(), isNull);

    final card = find.ancestor(of: find.text('Xulq'), matching: find.byType(Column)).first;
    expect(find.descendant(of: card, matching: find.text('0%')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('—')), findsNothing);
  });
}
