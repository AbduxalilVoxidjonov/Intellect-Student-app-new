// ChatScreen (tab) va LessonScreen — muvaffaqiyat / xato / bo'sh ma'lumot.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/lesson_screen.dart';
import 'package:student/screens/tabs/chat_screen.dart';

import 'test_harness.dart';

void main() {
  // =========================================================================
  group('ChatScreen', () {
    testWidgets('muvaffaqiyatli yuklash — xabarlar chiziladi', (tester) async {
      final api = installFakeApi();
      api.on('/student/chat', '''
[{"id":"m1","className":"A1","senderUserId":"t1","senderName":"Aziza Karimova",
  "senderRole":"teacher","text":"Assalomu alaykum","createdAt":"2026-08-01T09:00:00"}]
''');

      await tester.pumpWidget(wrapBody(const ChatScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Guruh chati'), findsOneWidget);
      expect(find.text('Assalomu alaykum'), findsOneWidget);
      expect(find.text('Aziza Karimova'), findsOneWidget);
      expect(find.text("O'qituvchi"), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('API 500 — ekran qulamaydi, xato holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/chat');

      await tester.pumpWidget(wrapBody(const ChatScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.textContaining("Yuklab bo'lmadi"), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets("bo'sh ro'yxat — bo'sh holat", (tester) async {
      final api = installFakeApi();
      api.on('/student/chat', '[]');

      await tester.pumpWidget(wrapBody(const ChatScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Xabar yo'q. Hozircha guruhda xabar yo'q."), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('xabar yuboriladi va ro\'yxatga qo\'shiladi', (tester) async {
      final api = installFakeApi();
      api.on('/student/chat', '''
{"id":"m9","className":"A1","senderUserId":"me","senderName":"Ali","senderRole":"student",
 "text":"Salom","createdAt":"2026-08-01T10:00:00"}
''', method: 'POST');
      api.on('/student/chat', '[]');

      await tester.pumpWidget(wrapBody(const ChatScreen()));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'Salom');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expectNoRealErrors(tester);

      final posts = api.requestsFor('/student/chat').where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(1));
      expect((posts.single.data as Map)['text'], 'Salom');
      expect(find.text('Salom'), findsWidgets);

      await tearDownTree(tester);
    });

    testWidgets("yuborish xatosi — matn qaytarib beriladi, ekran qulamaydi", (tester) async {
      final api = installFakeApi();
      api.failOn('/student/chat', method: 'POST');
      api.on('/student/chat', '[]');

      await tester.pumpWidget(wrapBody(const ChatScreen()));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'Test xabar');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expectNoRealErrors(tester);

      // Matn yo'qolmaydi.
      expect(find.text('Test xabar'), findsWidgets);

      await tearDownTree(tester);
    });
  });

  // =========================================================================
  group('LessonScreen', () {
    testWidgets('muvaffaqiyatli yuklash — bo\'limlar bo\'ylab o\'tish', (tester) async {
      final api = installFakeApi();
      api.on('/student/curriculum/item/i1', '''
{"id":"i1","topicId":"tp1","text":"Present Simple","note":"","order":1,"type":"text",
 "videoUrl":"","audioUrl":"","textContent":"Present Simple odatlar uchun ishlatiladi.",
 "pdfUrl":"","pdfName":"","meta":"","vocab":[],
 "questions":[{"id":"q1","text":"Savol bir","options":["Variant A","Variant B"],"correctIndex":0}],
 "exerciseKind":"","exerciseJson":""}
''');

      await tester.pumpWidget(wrapRoot(const LessonScreen(itemId: 'i1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Present Simple'), findsOneWidget); // sarlavha
      expect(find.text('Matn'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Present Simple odatlar uchun ishlatiladi.'), findsOneWidget);

      await tester.tap(find.text('Tugatdim · Keyingi'));
      await settle(tester, frames: 4);
      expectNoRealErrors(tester);

      expect(find.text('Test'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Natija'), findsOneWidget);
      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('Yakunlash'), findsOneWidget);
    });

    testWidgets('API 500 — "Dars topilmadi" holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/curriculum/item/i1');

      await tester.pumpWidget(wrapRoot(const LessonScreen(itemId: 'i1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Dars topilmadi yoki kontent yo'q"), findsOneWidget);
    });

    testWidgets("bo'sh kontent — 'Kontent hali qo'shilmagan'", (tester) async {
      final api = installFakeApi();
      api.on('/student/curriculum/item/i1', '{}');

      await tester.pumpWidget(wrapRoot(const LessonScreen(itemId: 'i1')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Kontent hali qo'shilmagan"), findsOneWidget);
    });

    testWidgets("lug'at o'yini — variantsiz savol ham qulatmaydi", (tester) async {
      final api = installFakeApi();
      api.on('/student/curriculum/item/i2', '''
{"id":"i2","topicId":"tp1","text":"Lug'at","note":"","order":1,"type":"vocab",
 "videoUrl":"","audioUrl":"","textContent":"","pdfUrl":"","pdfName":"","meta":"",
 "vocab":[{"term":"book","meaning":"kitob"},{"term":"pen","meaning":"ruchka"}],
 "questions":[],"exerciseKind":"","exerciseJson":""}
''');

      await tester.pumpWidget(wrapRoot(const LessonScreen(itemId: 'i2')));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("So'zni tanlab, to'g'ri tarjimasini bosing"), findsOneWidget);
      expect(find.text('book'), findsOneWidget);
      expect(find.text('kitob'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
    });
  });
}
