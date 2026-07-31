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
  "pendingAssignmentsCount": 0,
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
  "disciplineScore": 90, "disciplinePlus": 5, "disciplineMinus": 5, "disciplinePoints": [],
  "assignments": {"count": 0, "gradedCount": 0, "totalScore": 0, "totalMax": 0, "items": []},
  "evaluationTypes": [], "evaluations": [], "evaluationsBySubject": [],
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

const _notificationsJson = '''
{
  "unread": 3,
  "items": [
    {"id": "n1", "title": "Yangi baho", "body": "Grammar fanidan 5 baho qo'yildi.", "type": "grade", "createdAt": "2026-07-14T09:00:00", "read": false, "confirmed": false},
    {"id": "n2", "title": "Ruxsatnoma", "body": "Ertangi tadbirga ruxsat bering.", "type": "permission", "createdAt": "2026-07-13T15:00:00", "read": true, "confirmed": false}
  ]
}
''';

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    final p = options.path;
    String body = '{}';
    if (p.contains('/student/dashboard')) {
      body = _dashboardJson;
    } else if (p.contains('/student/notebook')) {
      body = _notebookJson;
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

void main() {
  testWidgets('DashboardScreen renders success path with real data', (tester) async {
    ApiClient.dio.httpClientAdapter = _FakeAdapter();

    await tester.pumpWidget(
      ChangeNotifierProvider<Session>(
        create: (_) => Session(),
        child: MaterialApp(
          builder: (context, child) =>
              AppTheme(colors: AppColors.light, child: child ?? const SizedBox()),
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );

    // Barcha async yuklashlar tugashini kutamiz.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    final ex = tester.takeException();
    expect(ex, isNull, reason: 'success path threw: $ex');

    // Asosiy kartalar chindan ekranda bo'lishi kerak.
    expect(find.text('Guruhim'), findsOneWidget);
    expect(find.text("Yig'ilgan ball"), findsOneWidget);
    expect(find.textContaining('Umumiy statistika'), findsWidgets);
  });
}
