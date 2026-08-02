// FinanceScreen / CertificatesScreen / ContractsScreen —
// muvaffaqiyat, API xatosi va bo'sh ma'lumot stsenariylari.

import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/certificates_screen.dart';
import 'package:student/screens/contracts_screen.dart';
import 'package:student/screens/finance_screen.dart';

import 'test_harness.dart';

void main() {
  // =========================================================================
  group('FinanceScreen', () {
    const okJson = '''
{
  "student": {"id":"s1","fullName":"Ali Valiyev","className":"A1"},
  "balance": -150000, "monthlyFee": 450000,
  "totalCharged": 900000, "totalDiscount": 50000, "totalPaid": 750000,
  "months": [
    {"month":"2026-01","charged":450000,"discount":0,"paid":450000,"remaining":0,
     "status":"paid","courses":[{"courseName":"Ingliz tili","fee":450000}]},
    {"month":"2026-02","charged":450000,"discount":50000,"paid":300000,"remaining":100000,
     "status":"partial","courses":[]}
  ],
  "payments": [{"date":"2026-01-05","amount":450000,"note":"Naqd"}]
}
''';

    testWidgets('muvaffaqiyatli yuklash — qarz, oylar va tarix', (tester) async {
      // To'lovlar tarixi ekranning pastida — standart oynada qurilmaydi.
      useTallScreen(tester);
      final api = installFakeApi();
      api.on('/student/finance', okJson);

      await tester.pumpWidget(wrapRoot(const FinanceScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("To'lovlar"), findsOneWidget);
      expect(find.text('Joriy qarz'), findsOneWidget);
      // Qarz summasi `RichText` (finance_screen.dart:153) — "150 000" va " so'm"
      // ikkita `TextSpan`. Oddiy `find.text` `RichText` ni ko'rmaydi.
      expect(find.textContaining('150 000', findRichText: true), findsOneWidget);
      expect(find.text("Oylar bo'yicha"), findsOneWidget);
      expect(find.text('Yanvar 2026'), findsOneWidget);
      expect(find.text('Fevral 2026'), findsOneWidget);
      expect(find.text("To'langan"), findsOneWidget);
      expect(find.text('Qisman'), findsOneWidget);
      expect(find.text("To'lovlar tarixi"), findsOneWidget);
      expect(find.text('+450 000'), findsOneWidget);
      // Qarz bor — to'lash tugmasi ko'rinadi.
      expect(find.text("To'lovni amalga oshirish"), findsOneWidget);
    });

    testWidgets('API 500 — ekran qulamaydi, xato holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/finance');

      await tester.pumpWidget(wrapRoot(const FinanceScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets('API 403 — ekran qulamaydi', (tester) async {
      final api = installFakeApi();
      api.on('/student/finance', '{"message":"Ruxsat yo\'q"}', status: 403);

      await tester.pumpWidget(wrapRoot(const FinanceScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
      expect(find.text("Ruxsat yo'q"), findsOneWidget);
    });

    testWidgets("bo'sh ma'lumot — bo'sh holatlar ko'rinadi", (tester) async {
      final api = installFakeApi();
      api.on('/student/finance', '{}');

      await tester.pumpWidget(wrapRoot(const FinanceScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Balans'), findsOneWidget);
      expect(find.text("Ma'lumot yo'q"), findsOneWidget);
      expect(find.text("To'lovlar yo'q"), findsOneWidget);
      // Qarz yo'q — to'lash tugmasi ham yo'q.
      expect(find.text("To'lovni amalga oshirish"), findsNothing);
    });
  });

  // =========================================================================
  group('CertificatesScreen', () {
    testWidgets('muvaffaqiyatli yuklash', (tester) async {
      final api = installFakeApi();
      api.on('/student/certificates', '''
[
  {"id":"c1","courseName":"Ingliz tili A1","issuedAt":"2026-01-15","expiresAt":"",
   "status":"active","fileName":"sertifikat-a1.pdf","downloadUrl":"/uploads/c1.pdf",
   "downloadCount":2},
  {"id":"c2","courseName":"Ingliz tili A2","issuedAt":"2025-06-01","expiresAt":"2026-06-01",
   "status":"expired","fileName":"sertifikat-a2.pdf","downloadUrl":"/uploads/c2.pdf",
   "downloadCount":0}
]
''');

      await tester.pumpWidget(wrapRoot(const CertificatesScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Sertifikatlar'), findsOneWidget);
      expect(find.text('Ingliz tili A1'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('ta sertifikat (1 ta amal qiluvchi)'), findsOneWidget);
      expect(find.text('Yuklab olish'), findsNWidgets(2));
      expect(find.text('Ulashish'), findsNWidgets(2));
      expect(find.text("Muddati o'tgan"), findsOneWidget);
    });

    testWidgets('API 500 — xato holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/certificates');

      await tester.pumpWidget(wrapRoot(const CertificatesScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("bo'sh ro'yxat — bo'sh holat", (tester) async {
      final api = installFakeApi();
      api.on('/student/certificates', '[]');

      await tester.pumpWidget(wrapRoot(const CertificatesScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Hali sertifikat yo'q"), findsOneWidget);
    });
  });

  // =========================================================================
  group('ContractsScreen', () {
    testWidgets('muvaffaqiyatli yuklash — sarlavhasiz shartnoma raqam bilan', (tester) async {
      final api = installFakeApi();
      api.on('/student/contracts', '''
[{"id":"k1","number":12,"title":"","target":"student","recipientKey":"",
  "recipientName":"Ali Valiyev","templateName":"Asosiy shartnoma","date":"2026-01-10",
  "pdfUrl":"/uploads/k1.pdf","docxUrl":"","delivered":true,"status":"active","visible":true}]
''');

      await tester.pumpWidget(wrapRoot(const ContractsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Shartnoma'), findsOneWidget); // sarlavha
      expect(find.text('Shartnoma № 12'), findsOneWidget);
      expect(find.text('Asosiy shartnoma'), findsOneWidget);
      expect(find.text('10 Yanvar'), findsOneWidget);
    });

    testWidgets('API 500 — xato holati', (tester) async {
      final api = installFakeApi();
      api.failOn('/student/contracts');

      await tester.pumpWidget(wrapRoot(const ContractsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text("Yuklab bo'lmadi"), findsOneWidget);
    });

    testWidgets("bo'sh ro'yxat — bo'sh holat", (tester) async {
      final api = installFakeApi();
      api.on('/student/contracts', '[]');

      await tester.pumpWidget(wrapRoot(const ContractsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      expect(find.text('Shartnoma hali tuzilmagan'), findsOneWidget);
    });

    testWidgets("noto'g'ri turdagi javob ({} o'rniga []) ham qulatmaydi", (tester) async {
      final api = installFakeApi();
      api.on('/student/contracts', '{}');

      await tester.pumpWidget(wrapRoot(const ContractsScreen()));
      await settle(tester);
      expectNoRealErrors(tester);

      // StudentApi.contracts List bo'lmasa bo'sh ro'yxat qaytaradi.
      expect(find.text('Shartnoma hali tuzilmagan'), findsOneWidget);
    });
  });
}

