// AiCheckScreen — holat banneri, tarix, validatsiya va natija ekrani.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/ai_check_screen.dart';

import 'test_harness.dart';

const _statusOk = '''
{"geminiReady":true,"azureReady":true,"premium":false,"blocked":false,
 "limit":5,"usedToday":2,"remaining":3,"enabled":true}
''';

const _historyOk = '''
[{"id":"h1","type":"writing","prompt":"My holiday","score":78,"date":"2026-07-01",
  "createdAt":"2026-07-01T10:00:00","hasAudio":false},
 {"id":"h2","type":"speaking","prompt":"","score":64,"date":"2026-06-20",
  "createdAt":"2026-06-20T10:00:00","hasAudio":true}]
''';

void main() {
  testWidgets('muvaffaqiyatli yuklash — limit va tarix', (tester) async {
    // Tarix ekranning eng pastida; standart 800x600 test oynasida u ListView
    // ko'rinish sohasidan tashqarida qoladi va UMUMAN qurilmaydi.
    useTallScreen(tester);
    final api = installFakeApi();
    api.on('/student/ai-check/status', _statusOk);
    api.on('/student/ai-check/history', _historyOk);

    await tester.pumpWidget(wrapRoot(const AiCheckScreen()));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text('AI tekshiruv'), findsOneWidget);
    expect(find.text('Bugungi limit'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('Tarix'), findsOneWidget);
    expect(find.text('My holiday'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('AI tekshirish'), findsOneWidget);
  });

  testWidgets("bo'lim yopiq (enabled=false) — tekshiruv formasi ko'rsatilmaydi", (tester) async {
    final api = installFakeApi();
    api.on('/student/ai-check/status', '''
{"geminiReady":true,"azureReady":true,"premium":false,"blocked":false,
 "limit":5,"usedToday":0,"remaining":5,"enabled":false}
''');
    api.on('/student/ai-check/history', '[]');

    await tester.pumpWidget(wrapRoot(const AiCheckScreen()));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text("Bu bo'lim hali markaz tomonidan ochilmagan"), findsOneWidget);
    expect(find.text('AI tekshirish'), findsNothing);
  });

  testWidgets('ikkala API 500 — xato holati (bo\'sh holat EMAS)', (tester) async {
    final api = installFakeApi();
    api.failEverything();

    await tester.pumpWidget(wrapRoot(const AiCheckScreen()));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text('AI tekshiruv'), findsOneWidget);
    // Tarmoq xatosi "hali tekshiruv yo'q" deb ko'rsatilmaydi.
    expect(find.text("Hali tekshiruv yo'q"), findsNothing);
    expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);
  });

  testWidgets("bo'sh javoblar — kalit sozlanmagan ogohlantirishi", (tester) async {
    // "Hali tekshiruv yo'q" bo'sh holati formadan KEYIN keladi — standart
    // 800x600 oynada qurilmaydi.
    useTallScreen(tester);
    final api = installFakeApi();
    api.on('/student/ai-check/status', '{}');
    api.on('/student/ai-check/history', '[]');

    await tester.pumpWidget(wrapRoot(const AiCheckScreen()));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text('0 / 0'), findsOneWidget);
    expect(find.textContaining('hali sozlanmagan'), findsOneWidget);
    expect(find.text("Hali tekshiruv yo'q"), findsOneWidget);
  });

  testWidgets('qisqa matn — validatsiya xabari, so\'rov yuborilmaydi', (tester) async {
    final api = installFakeApi();
    api.on('/student/ai-check/status', _statusOk);
    api.on('/student/ai-check/history', '[]');

    await tester.pumpWidget(wrapRoot(const AiCheckScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.tap(find.text('AI tekshirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text('Matn juda qisqa (kamida 10 belgi).'), findsOneWidget);
    expect(api.requestsFor('/ai-check/writing'), isEmpty);
  });

  testWidgets('writing yuboriladi va natija ekrani ochiladi', (tester) async {
    final api = installFakeApi();
    api.on('/student/ai-check/writing', '''
{"id":"n1","type":"writing","prompt":"","inputText":"I go to school every day",
 "recognizedText":"","audioUrl":"","score":72,"date":"2026-08-01",
 "createdAt":"2026-08-01T10:00:00","taskType":"",
 "analysis":{"overall":72,"level":"B1","scores":{},"summary":"Yaxshi ish.",
             "strengths":["Aniq tuzilma"],"weaknesses":[],"corrections":[],"vocabulary":[],
             "improved":"I go to school every single day","recommendations":[]}}
''');
    api.on('/student/ai-check/status', _statusOk);
    api.on('/student/ai-check/history', '[]');

    await tester.pumpWidget(wrapRoot(const AiCheckScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField).at(1), 'I go to school every day');
    await tester.tap(find.text('AI tekshirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(api.requestsFor('/ai-check/writing'), hasLength(1));
    expect(find.text('AI tekshiruv natijasi'), findsOneWidget);
    expect(find.text('Yaxshi ish.'), findsOneWidget);
    expect(find.text('Daraja: B1'), findsOneWidget);
  });

  testWidgets('writing xatosi — xato kartada ko\'rsatiladi', (tester) async {
    final api = installFakeApi();
    api.on('/student/ai-check/writing', '{"message":"Bugungi limit tugadi"}', status: 429);
    api.on('/student/ai-check/status', _statusOk);
    api.on('/student/ai-check/history', '[]');

    await tester.pumpWidget(wrapRoot(const AiCheckScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField).at(1), 'I go to school every day');
    await tester.tap(find.text('AI tekshirish'));
    await settle(tester);
    expectNoRealErrors(tester);

    expect(find.text('Bugungi limit tugadi'), findsOneWidget);
  });
}
