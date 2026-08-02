// SupportScreen va SettingsScreen — muvaffaqiyat / xato / bo'sh ma'lumot + amallar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/screens/settings_screen.dart';
import 'package:student/screens/support_screen.dart';

import 'test_harness.dart';

const _supportJson = '''
{
  "myBookings": [
    {"id":"b1","teacherId":"t1","teacherName":"Aziza Karimova","date":"2026-08-05",
     "startTime":"15:00","endTime":"15:30","status":"booked","topic":"","notes":""}
  ],
  "supports": [{
    "teacherId":"t1","fullName":"Aziza Karimova","subject":"Ingliz tili",
    "openSlots":[
      {"id":"s1","date":"2026-08-01","startTime":"09:00","endTime":"09:30"},
      {"id":"s2","date":"2026-08-01","startTime":"10:00","endTime":"10:30"}
    ]
  }]
}
''';

void main() {
  // =========================================================================
  group('SupportScreen', () {
    testWidgets('muvaffaqiyatli yuklash — bronlar va o\'qituvchilar', (tester) async {
      final api = installFakeApi();
      api.on('/student/support', _supportJson);

      await tester.pumpWidget(wrapRoot(const SupportScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Support'), findsOneWidget);
      expect(find.text('MENING BRONLARIM'), findsOneWidget);
      expect(find.text("SUPPORT O'QITUVCHILAR"), findsOneWidget);
      expect(find.text('Bron qilindi'), findsOneWidget);
      expect(find.text("2 bo'sh"), findsOneWidget);
      // Akkordeon yopiq — slotlar ko'rinmaydi.
      expect(find.text('09:00–09:30'), findsNothing);
    });

    testWidgets('akkordeon ochiladi va slot bron qilinadi', (tester) async {
      final api = installFakeApi();
      // Aniqrog'i BIRINCHI.
      api.on('/student/support/slots/s1/book', '{}');
      api.on('/student/support', _supportJson);

      await tester.pumpWidget(wrapRoot(const SupportScreen()));
      await settle(tester);

      await tester.tap(find.text('Aziza Karimova').last);
      await settle(tester, frames: 4);
      expect(find.text('09:00–09:30'), findsOneWidget);

      await tester.tap(find.text('Bron qilish').first);
      await settle(tester);
      expectNoRealErrors(tester);

      expect(api.requestsFor('/slots/s1/book'), hasLength(1));
    });

    testWidgets('API 500 — ekran qulamaydi (xato holati ko\'rsatiladi)', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/support');

      await tester.pumpWidget(wrapRoot(const SupportScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      // Tarmoq xatosi "o'qituvchi yo'q" deb ko'rsatilmaydi.
      expect(find.text("Hozircha support o'qituvchi yo'q"), findsNothing);
      expect(find.text('Qayta urinish'), findsOneWidget);
    });

    testWidgets("bo'sh ma'lumot — bo'sh holat", (tester) async {
      final api = installFakeApi();
      api.on('/student/support', '{"supports": [], "myBookings": []}');

      await tester.pumpWidget(wrapRoot(const SupportScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Hozircha support o'qituvchi yo'q"), findsOneWidget);
      expect(find.text('MENING BRONLARIM'), findsNothing);
    });

    testWidgets(
      "yuklash xatosi bo'sh holatdan farqlanadi",
      (tester) async {
        final api = installFakeApi();
        api.failOn('/student/support');

        await tester.pumpWidget(wrapRoot(const SupportScreen()));
        await settle(tester);

        expect(find.textContaining("Yuklab bo'lmadi"), findsOneWidget);
      },
    );
  });

  // =========================================================================
  group('SettingsScreen', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    testWidgets('muvaffaqiyatli yuklash — til ro\'yxati va push holati', (tester) async {
      final api = installFakeApi();
      api.on('/student/settings', '{"language":"ru","theme":"light","notificationsEnabled":false}');

      await tester.pumpWidget(wrapRoot(const SettingsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Sozlamalar'), findsOneWidget);
      expect(find.text("KO'RINISH"), findsOneWidget);
      expect(find.text('TIL'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('Push bildirishnoma'), findsOneWidget);
      expect(find.text("Parolni o'zgartirish"), findsOneWidget);

      // Push o'chirilgan holatda kelgan.
      final push = tester.widget<Switch>(find.byType(Switch).last);
      expect(push.value, isFalse);
    });

    testWidgets('push almashtirilganda serverga saqlanadi', (tester) async {
      final api = installFakeApi();
      api.on('/student/settings', '{"language":"uz","theme":"light","notificationsEnabled":true}');

      await tester.pumpWidget(wrapRoot(const SettingsScreen()));
      await settle(tester);

      await tester.tap(find.byType(Switch).last);
      await settle(tester);
      expectNoRealErrors(tester);

      final puts = api.requestsFor('/student/settings').where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(1));
      expect((puts.single.data as Map)['notificationsEnabled'], isFalse);
    });

    testWidgets('til tanlagichi vaqtincha faolsiz — bosilganda hech nima yuborilmaydi',
        (tester) async {
      // Ilovadagi matnlar hali lokalizatsiya qilinmagan: til tanlansa ham hech
      // nima o'zgarmasdi, shuning uchun tanlagich faolsiz (TODO(lokalizatsiya)).
      final api = installFakeApi();
      api.on('/student/settings', '{"language":"uz","theme":"light","notificationsEnabled":true}');

      await tester.pumpWidget(wrapRoot(const SettingsScreen()));
      await settle(tester);

      await tester.tap(find.text('English'));
      await settle(tester);
      expectNoRealErrors(tester);

      final puts = api.requestsFor('/student/settings').where((r) => r.method == 'PUT').toList();
      expect(puts, isEmpty);
      expect(find.textContaining('tez orada'), findsOneWidget);
      // Ilova tili — o'zbekcha; faqat shu qator belgilangan.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('API 500 — faqat serverga bog\'liq bo\'lim xato bilan almashadi', (tester) async {
      // "Akkaunt" bo'limi ro'yxatning pastida — standart 800x600 oynada
      // ListView uni umuman qurmaydi (qarang test_harness `useTallScreen`).
      useTallScreen(tester);
      final api = installFakeApi();
      api.failOn('/student/settings');

      await tester.pumpWidget(wrapRoot(const SettingsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      // Serverdan keladigan qism: noto'g'ri "default" o'rniga xato + qayta urinish.
      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(find.text('Push bildirishnoma'), findsNothing);

      // Serverga BOG'LIQ BO'LMAGAN punktlar ishlab turadi (internet yo'q bo'lsa ham).
      expect(find.text('Sozlamalar'), findsOneWidget);
      expect(find.text('Tungi rejim'), findsOneWidget);
      expect(find.text("Parolni o'zgartirish"), findsOneWidget);
      expect(find.text("O'zbek"), findsOneWidget);

      // Tungi rejim almashtirilishi kerak — u SharedPreferences'da saqlanadi.
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expectNoRealErrors(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets("bo'sh javob ({}) — ekran chiziladi", (tester) async {
      final api = installFakeApi();
      api.on('/student/settings', '{}');

      await tester.pumpWidget(wrapRoot(const SettingsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("O'zbek"), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget); // faqat bitta til belgilangan
    });
  });
}
