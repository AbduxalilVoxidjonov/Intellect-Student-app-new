import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:student/api/api_client.dart';
import 'package:student/services/session.dart';
import 'package:student/theme/app_theme.dart';
import 'package:student/screens/tabs/progress_screen.dart';
import 'package:student/screens/tabs/profile_screen.dart';
import 'package:student/screens/notifications_sheet.dart';

// Uzun guruh nomi — profil kartasidagi overflow'ni tekshirish uchun.
const _dashboardJson = '''
{
  "profile": {"id": "s1", "fullName": "Ali Valiyev", "className": "Ingliz tili Intermediate B2 kechki guruh", "birthDate": "", "gender": "male", "parentFullName": "", "parentPhone": "", "enrollmentDate": ""},
  "meta": {"lessonTimes": [], "absenceReasons": [], "currentQuarter": 1, "currentWeek": 1},
  "todayLessons": [], "todayGrades": [], "balance": 0, "monthlyFee": 0
}
''';

const _ratingJson = '''
{
  "meStudentId": "s1",
  "classRows": [
    {"rank": 1, "studentId": "x1", "fullName": "Aziza Karimova", "className": "A1", "average": 4.8, "ball": 1280},
    {"rank": 2, "studentId": "s1", "fullName": "Ali Valiyev", "className": "A1", "average": 4.5, "ball": 1150},
    {"rank": 3, "studentId": "x3", "fullName": "Bobur Rashidov", "className": "A1", "average": 4.2, "ball": 990},
    {"rank": 4, "studentId": "x4", "fullName": "Dilnoza Yusupova", "className": "A1", "average": 4.0, "ball": 870}
  ],
  "schoolRows": [
    {"rank": 1, "studentId": "x1", "fullName": "Aziza Karimova", "className": "A1", "average": 4.8, "ball": 1280},
    {"rank": 2, "studentId": "x2", "fullName": "Sardor Aliyev", "className": "B2", "average": 4.6, "ball": 1200},
    {"rank": 3, "studentId": "x3", "fullName": "Bobur Rashidov", "className": "A1", "average": 4.2, "ball": 990}
  ],
  "meSchoolRank": 12, "schoolSize": 340
}
''';

const _curriculumJson = '''
[{
  "groupId": "g1", "courseId": "c1", "courseName": "Ingliz tili A1",
  "totalItems": 3, "coveredCount": 1, "revisionLessons": 0, "totalLessons": 3,
  "remainingItems": 2, "estLessonsLeft": 2, "lessonsPerWeek": 3, "estFinishDate": "2026-09-01",
  "levels": [{
    "id": "L1", "name": "Boshlangich daraja", "note": "", "order": 1,
    "topics": [
      {"id": "T1", "title": "Salomlashish", "note": "", "order": 1, "items": [
        {"id": "I1", "text": "Hello", "note": "", "order": 1, "covered": true, "coveredDate": "2026-07-01"},
        {"id": "I2", "text": "Goodbye", "note": "", "order": 2, "covered": false, "coveredDate": ""}
      ]},
      {"id": "T2", "title": "Raqamlar", "note": "", "order": 2, "items": [
        {"id": "I3", "text": "One to Ten", "note": "", "order": 1, "covered": false, "coveredDate": ""}
      ]}
    ]
  }]
}]
''';

const _notificationsJson = '''
{"unread": 2, "items": [
  {"id": "n1", "title": "Yangi baho", "body": "Grammar fanidan 5.", "type": "grade", "createdAt": "2026-07-14T09:00:00", "read": false, "confirmed": false},
  {"id": "n2", "title": "Ruxsatnoma", "body": "Tadbirga ruxsat.", "type": "permission", "createdAt": "2026-07-13T15:00:00", "read": true, "confirmed": false}
]}
''';

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    final p = options.path;
    String body = '{}';
    if (p.contains('/student/rating')) {
      body = _ratingJson;
    } else if (p.contains('/student/notifications')) {
      body = _notificationsJson;
    } else if (p.contains('/student/curriculum')) {
      body = _curriculumJson;
    } else if (p.contains('/student/dashboard')) {
      body = _dashboardJson;
    }
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Widget _wrap(Widget child) => MaterialApp(
      builder: (context, c) => AppTheme(colors: AppColors.light, child: c ?? const SizedBox()),
      home: Scaffold(body: child),
    );

void main() {
  setUp(() => ApiClient.dio.httpClientAdapter = _FakeAdapter());

  testWidgets('Reyting (Guruh + Markaz) toshib ketmasdan chiziladi', (tester) async {
    await tester.pumpWidget(_wrap(const ProgressScreen()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    // Guruh segmentiga o'tamiz — "Sizning o'rningiz" kartasi + to'liq ro'yxat (web bilan bir xil).
    await tester.tap(find.text('Guruh'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'Guruh reytingi threw');

    // Markaz segmenti.
    await tester.tap(find.text('Markaz'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'Markaz reytingi threw');
  });

  testWidgets('Dastur yo\'l-xaritasi (web Progress.tsx) chiziladi', (tester) async {
    await tester.pumpWidget(_wrap(const ProgressScreen()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull, reason: 'dastur threw');

    // Modul sarlavhasi katta harflarda, mavzu bayrog'i va darslar yo'l tugunlari.
    expect(find.text('BOSHLANGICH DARAJA'), findsOneWidget);
    expect(find.text('Salomlashish'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget); // o'tilgan dars
    expect(find.text('Goodbye'), findsOneWidget); // hali yopiq dars

    // Keyingi modul mavzusi ham bir xil yo'lda chiziladi (akkordeon yo'q — hammasi ochiq).
    expect(find.text('Raqamlar'), findsOneWidget);
    expect(find.text('One to Ten'), findsOneWidget);
  });

  testWidgets('Profile card renders with long group name (no overflow)', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<Session>(
        create: (_) => Session(),
        child: MaterialApp(
          builder: (context, c) => AppTheme(colors: AppColors.light, child: c ?? const SizedBox()),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull, reason: 'profile card threw');
    expect(find.text('Guruh'), findsWidgets);
  });

  testWidgets('Notifications sheet opens (slides up) and renders', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return Center(
          child: ElevatedButton(
            onPressed: () => showNotificationsSheet(ctx),
            child: const Text('open'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull, reason: 'notifications sheet threw');
    expect(find.text('Bildirishnomalar'), findsOneWidget);
    expect(find.text('Yangi baho'), findsOneWidget);
  });
}
