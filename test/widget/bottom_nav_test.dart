// PASTKI NAVIGATSIYA — tor telefon va katta tizim shrifti.
//
// Muammo (foydalanuvchi bildirgan): kichikroq telefonlarda pastdagi yozuvlar
// sig'masdi. Sabab ikkita edi va ikkalasi ham shu yerda qulflanadi:
//   • 5 ta tab ekran kengligini teng bo'lib oladi — 320dp li telefonda
//     bittasiga 64dp qoladi, "Dashboard" esa deyarli shuncha joy egallaydi;
//     `Text` da `maxLines` bo'lmagani uchun u IKKI QATORGA o'ralardi;
//   • ikki qatorga o'ralgan yozuv qat'iy 62dp balandlikdan toshib,
//     `RenderFlex overflowed` berardi.
//
// DIQQAT: `loadRealFonts()` SHART — zaxira test shriftida har belgi 1em
// kenglikda chiziladi va o'lchov qurilmadagidan ~2 baravar keng chiqadi
// (batafsil izoh `overflow_test.dart` boshida).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/shell.dart';

import 'test_harness.dart';

/// Berilgan kenglikdagi ekranni o'rnatadi (balandlik bu test uchun muhim emas).
void _useScreen(WidgetTester tester, double widthDp) {
  tester.view.physicalSize = Size(widthDp * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Navigatsiya panelini YAKKA o'zini chizadi.
///
/// `ShellScreen` ning o'zi render qilinmaydi: u `PushService.start()` ni
/// chaqiradi va Dashboard so'rovlarini boshlaydi — bu testga aloqasiz shovqin.
/// Panel aynan shu sabab alohida widgetga (`StudentBottomNav`) ajratilgan.
Future<void> _pumpNav(WidgetTester tester, {int index = 0, ValueChanged<int>? onSelect}) async {
  await tester.pumpWidget(wrapRoot(Scaffold(
    body: const SizedBox.shrink(),
    bottomNavigationBar: StudentBottomNav(index: index, onSelect: onSelect ?? (_) {}),
  )));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    expect(await loadRealFonts(), isTrue,
        reason: 'Roboto topilmadi — o\'lchovlar haqiqiy emas');
  });

  testWidgets('320dp telefonda beshala yozuv toshmasdan chiqadi', (tester) async {
    _useScreen(tester, 320);
    await _pumpNav(tester);

    for (final t in ['Dashboard', 'Progress', 'Test', 'Chat', 'Profil']) {
      expect(find.text(t), findsOneWidget, reason: '"$t" yozuvi yo\'q');
    }
    expectNoRealErrors(tester, reason: 'BottomNav 320dp');
  });

  testWidgets('320dp + textScale 2.0 da ham toshmaydi', (tester) async {
    _useScreen(tester, 320);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpNav(tester);
    expectNoRealErrors(tester, reason: 'BottomNav 320dp textScale 2.0');
  });

  testWidgets('360dp + textScale 1.5 da ham toshmaydi', (tester) async {
    _useScreen(tester, 360);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpNav(tester);
    expectNoRealErrors(tester, reason: 'BottomNav 360dp textScale 1.5');
  });

  testWidgets('yozuv HECH QACHON ikki qatorga o\'ralmaydi', (tester) async {
    _useScreen(tester, 320);
    await _pumpNav(tester);

    // Aynan shu qoida buzilgan edi: `maxLines` bo'lmagani uchun "Dashboard"
    // ikkiga bo'linib, panel balandligidan toshardi.
    final labels = tester.widgetList<Text>(find.descendant(
      of: find.byType(StudentBottomNav),
      matching: find.byType(Text),
    ));
    expect(labels, isNotEmpty);
    for (final t in labels) {
      expect(t.maxLines, 1, reason: '"${t.data}" bir qatorda qolishi kerak');
      expect(t.softWrap, isFalse);
    }
  });

  testWidgets('joy yetmasa yozuv kichrayadi (kesilmaydi)', (tester) async {
    _useScreen(tester, 320);
    await _pumpNav(tester);

    // `FittedBox(scaleDown)` — kesish/uch nuqta o'rniga kichraytirish.
    // Har tabga bittadan.
    final fitted = tester.widgetList<FittedBox>(find.descendant(
      of: find.byType(StudentBottomNav),
      matching: find.byType(FittedBox),
    ));
    expect(fitted.length, StudentBottomNav.tabs.length);
    for (final f in fitted) {
      expect(f.fit, BoxFit.scaleDown);
    }
  });

  testWidgets('panel balandligi katta shriftda O\'SADI (yozuv yo\'qolmasin)', (tester) async {
    _useScreen(tester, 320);
    await _pumpNav(tester);
    final normal = tester.getSize(find.byType(StudentBottomNav)).height;

    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpNav(tester);
    final big = tester.getSize(find.byType(StudentBottomNav)).height;

    // Masshtab 1.3 bilan cheklangan, ya'ni panel BIR OZ o'sadi — ekranni
    // egallab ketmaydi, lekin katta shrift butunlay e'tiborsiz ham qolmaydi.
    expect(big, greaterThan(normal));
    expect(big, lessThan(normal * 1.6));
  });

  testWidgets('tab bosilganda indeks qaytadi', (tester) async {
    _useScreen(tester, 320);
    final taps = <int>[];
    await _pumpNav(tester, onSelect: taps.add);

    await tester.tap(find.text('Chat'));
    await tester.pump();
    expect(taps, [3]);
  });
}
