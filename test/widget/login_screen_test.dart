// LoginScreen — chizilishi, validatsiya va noto'g'ri parol xabari.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/screens/login_screen.dart';

import 'test_harness.dart';

void main() {
  setUp(() {
    // Session.login muvaffaqiyatli bo'lsa SharedPreferences'ga yozadi.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('LoginScreen chiziladi — maydonlar va tugma joyida', (tester) async {
    installFakeApi();
    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);
    expectNoRealErrors(tester);

    expect(find.text('Xush kelibsiz'), findsOneWidget);
    expect(find.text("O'quvchi akkauntingiz bilan kiring"), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Kirish'), findsOneWidget);
  });

  testWidgets("Noto'g'ri parol — serverdagi xabar ekranda ko'rinadi", (tester) async {
    final api = installFakeApi();
    api.on('/auth/login', '{"message":"Login yoki parol noto\'g\'ri"}', status: 401);

    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);

    await tester.enterText(find.byType(TextField).first, 'ali@test.uz');
    await tester.enterText(find.byType(TextField).last, 'xato-parol');
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text("Login yoki parol noto'g'ri"), findsOneWidget);
  });

  testWidgets('Server 500 — ekran qulamaydi, serverning matni chiqadi', (tester) async {
    final api = installFakeApi();
    api.failOn('/auth/login'); // 500 + {"message":"Server xatosi"}

    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);

    await tester.enterText(find.byType(TextField).first, 'ali@test.uz');
    await tester.enterText(find.byType(TextField).last, 'parol');
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    // `validateStatus` 600 gacha — 5xx ham `Response` bo'lib keladi va
    // serverning `message` i yo'qolmaydi.
    expect(find.text('Server xatosi'), findsOneWidget);
    // Xom `DioException [...]` matni foydalanuvchiga ko'rinmasligi kerak.
    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets("Server 500 + `message` yo'q — o'zbekcha umumiy sabab", (tester) async {
    final api = installFakeApi();
    api.failOn('/auth/login', body: '{}');

    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);

    await tester.enterText(find.byType(TextField).first, 'ali@test.uz');
    await tester.enterText(find.byType(TextField).last, 'parol');
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text("Serverda xatolik. Birozdan keyin urinib ko'ring."), findsOneWidget);
  });

  testWidgets("200 + kutilmagan tana (massiv) — ekran qulamaydi, tugma tirik qoladi", (tester) async {
    final api = installFakeApi();
    // Ilgari `res.data as Map<String, dynamic>` shu yerda `TypeError` berardi.
    api.on('/auth/login', '[]');

    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);

    await tester.enterText(find.byType(TextField).first, 'ali@test.uz');
    await tester.enterText(find.byType(TextField).last, 'parol');
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text("Server javobi noto'g'ri"), findsOneWidget);

    // Eng muhimi: `_loading` `finally` da tiklanadi — tugma yana ishlaydi.
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);
    expect(api.requestsFor('/auth/login'), hasLength(2), reason: 'tugma o\'lik qolmasligi kerak');
  });

  testWidgets("Bo'sh maydonda so'rov umuman yuborilmaydi", (tester) async {
    final api = installFakeApi();
    api.on('/auth/login', '{"message":"x"}', status: 400);

    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(api.requestsFor('/auth/login'), isEmpty,
        reason: "bo'sh login/parolda tarmoq so'rovi bo'lmasligi kerak");
    expect(find.textContaining("to'ldiring"), findsOneWidget);
  });

  testWidgets("Faqat parol kiritilgan — baribir so'rov yo'q", (tester) async {
    final api = installFakeApi();

    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);

    await tester.enterText(find.byType(TextField).last, 'parol');
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(api.requestsFor('/auth/login'), isEmpty);
    expect(find.textContaining("to'ldiring"), findsOneWidget);
  });

  testWidgets("Bo'sh maydondan keyin to'ldirilsa — so'rov ketadi", (tester) async {
    final api = installFakeApi();
    api.on('/auth/login', '{"message":"Login yoki parol noto\'g\'ri"}', status: 401);

    await tester.pumpWidget(wrapRoot(const LoginScreen()));
    await settle(tester, frames: 3);

    await tester.tap(find.text('Kirish')); // validatsiya to'sadi
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'ali@test.uz');
    await tester.enterText(find.byType(TextField).last, 'parol');
    await tester.tap(find.text('Kirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(api.requestsFor('/auth/login'), hasLength(1));
    expect(find.text("Login yoki parol noto'g'ri"), findsOneWidget);
  });
}
