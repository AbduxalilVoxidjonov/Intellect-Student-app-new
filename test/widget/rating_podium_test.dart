// PROGRESS → REYTING: guruh va markaz podiumi.
//
// NEGA BU TESTLAR BOR: guruh reytingi ilgari `classRows` (matn yorlig'i bo'yicha
// filtrlangan ro'yxat) dan chizilardi va M2M a'zolikka o'tilgandan keyin ko'pincha
// BO'SH kelardi — foydalanuvchi "Guruh" tabini bosganda faqat markaz reytingini
// ko'rardi. Endi manba `groups` (har bir faol guruh alohida) va TOP-3 podiumda
// chiziladi. Shu ikki narsa (manba + podium) shu yerda qulflanadi.

import 'package:flutter_test/flutter_test.dart';
import 'package:student/screens/tabs/progress_screen.dart';
import 'package:student/widgets/podium.dart';

import 'test_harness.dart';

/// Ikkita guruh: A1 (4 kishi, men 2-o'rinda) va B1 (2 kishi, men 1-o'rinda).
const _twoGroupsJson = '''
{
  "meStudentId": "s1",
  "classRows": [],
  "schoolRows": [
    {"rank": 1, "studentId": "x1", "fullName": "Aziza Karimova", "className": "A1", "average": 4.8, "attendance": 96, "ball": 1280},
    {"rank": 2, "studentId": "x2", "fullName": "Sardor Aliyev", "className": "B2", "average": 4.6, "attendance": 90, "ball": 1200},
    {"rank": 3, "studentId": "x3", "fullName": "Bobur Rashidov", "className": "A1", "average": 4.2, "attendance": 88, "ball": 990},
    {"rank": 4, "studentId": "s1", "fullName": "Ali Valiyev", "className": "A1", "average": 4.1, "attendance": 85, "ball": 900}
  ],
  "meSchoolRank": 4, "schoolSize": 340,
  "groups": [
    {
      "groupId": "g1", "groupName": "Ingliz tili A1", "meRank": 2, "size": 4,
      "rows": [
        {"rank": 1, "studentId": "x1", "fullName": "Aziza Karimova", "className": "A1", "average": 4.8, "attendance": 96, "ball": 1280},
        {"rank": 2, "studentId": "s1", "fullName": "Ali Valiyev", "className": "A1", "average": 4.1, "attendance": 85, "ball": 900},
        {"rank": 3, "studentId": "x3", "fullName": "Bobur Rashidov", "className": "A1", "average": 4.2, "attendance": 88, "ball": 870},
        {"rank": 4, "studentId": "x4", "fullName": "Dilnoza Yusupova", "className": "A1", "average": 4.0, "attendance": 80, "ball": 700}
      ]
    },
    {
      "groupId": "g2", "groupName": "Matematika B1", "meRank": 1, "size": 2,
      "rows": [
        {"rank": 1, "studentId": "s1", "fullName": "Ali Valiyev", "className": "B1", "average": 5.0, "attendance": 99, "ball": 400},
        {"rank": 2, "studentId": "x9", "fullName": "Kamola Yo'ldosheva", "className": "B1", "average": 4.4, "attendance": 91, "ball": 300}
      ]
    }
  ]
}
''';

/// Bitta kishilik guruh — podium 3 ustunidan faqat o'rtadagisi to'ladi.
const _oneMemberJson = '''
{
  "meStudentId": "s1", "classRows": [], "schoolRows": [],
  "meSchoolRank": null, "schoolSize": 0,
  "groups": [
    {
      "groupId": "g1", "groupName": "Yakka guruh", "meRank": 1, "size": 1,
      "rows": [
        {"rank": 1, "studentId": "s1", "fullName": "Ali Valiyev", "className": "A1", "average": 4.2, "attendance": 90, "ball": 320}
      ]
    }
  ]
}
''';

/// Ikki kishilik guruh — 1 va 2-o'rin bor, 3-ustun bo'sh.
const _twoMembersJson = '''
{
  "meStudentId": "s1", "classRows": [], "schoolRows": [],
  "meSchoolRank": null, "schoolSize": 0,
  "groups": [
    {
      "groupId": "g1", "groupName": "Kichik guruh", "meRank": 2, "size": 2,
      "rows": [
        {"rank": 1, "studentId": "x1", "fullName": "Aziza Karimova", "className": "A1", "average": 4.8, "attendance": 96, "ball": 500},
        {"rank": 2, "studentId": "s1", "fullName": "Ali Valiyev", "className": "A1", "average": 4.2, "attendance": 90, "ball": 320}
      ]
    }
  ]
}
''';

/// Faol guruhi yo'q o'quvchi — markaz reytingi bor, guruhniki yo'q.
const _noGroupsJson = '''
{
  "meStudentId": "s1", "classRows": [],
  "schoolRows": [
    {"rank": 1, "studentId": "x1", "fullName": "Aziza Karimova", "className": "A1", "average": 4.8, "ball": 1280}
  ],
  "meSchoolRank": null, "schoolSize": 340,
  "groups": []
}
''';

FakeApi _api(String ratingJson) {
  final api = installFakeApi();
  // Reyting so'rovidan OLDIN qo'shiladi — `/student/curriculum` yo'li
  // `/student/rating` bilan kesishmaydi, lekin tartib aniq bo'lgani ma'qul.
  api.on('/student/curriculum', '[]');
  api.on('/student/rating', ratingJson);
  return api;
}

Future<void> _openGroupTab(WidgetTester tester) async {
  await tester.tap(find.text('Guruh'));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('Guruh rejimi — TOP-3 podiumda, qolgani jadvalda', (tester) async {
    useTallScreen(tester);
    _api(_twoGroupsJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await _openGroupTab(tester);

    // Uchta podium kartochkasi (1/2/3-o'rin).
    expect(find.byType(PodiumCard), findsNWidgets(3));
    expect(find.text("1-o'rin"), findsOneWidget);
    expect(find.text("3-o'rin"), findsOneWidget);
    // 2-o'rin — o'zim, shuning uchun yorliq "Siz · 2".
    expect(find.text('Siz · 2'), findsOneWidget);

    // Guruh nomi sarlavha sifatida.
    expect(find.text('Ingliz tili A1'), findsWidgets);
    // 4-o'rindagi o'quvchi podiumda emas, jadvalda.
    expect(find.text('Dilnoza Yusupova'), findsOneWidget);
    expectNoRealErrors(tester);
  });

  testWidgets('Markaz rejimida ham podium chiziladi', (tester) async {
    useTallScreen(tester);
    _api(_twoGroupsJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await tester.tap(find.text('Markaz'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PodiumCard), findsNWidgets(3));
    expect(find.text('Markaz reytingi · TOP 15'), findsOneWidget);
    expectNoRealErrors(tester);
  });

  testWidgets('Ko\'p guruh — chip bosilganda podium almashadi', (tester) async {
    useTallScreen(tester);
    _api(_twoGroupsJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await _openGroupTab(tester);

    // Boshida birinchi guruh: 4 kishi → podium 3 + jadvalda 1.
    expect(find.byType(PodiumCard), findsNWidgets(3));
    expect(find.text('Dilnoza Yusupova'), findsOneWidget);

    // Ikkinchi guruh chipi (chip matni — guruh nomi).
    await tester.tap(find.text('Matematika B1').first);
    await tester.pump(const Duration(milliseconds: 200));

    // 2 kishi → faqat 2 ta podium kartochkasi, birinchi guruh odamlari yo'q.
    expect(find.byType(PodiumCard), findsNWidgets(2));
    expect(find.text('Dilnoza Yusupova'), findsNothing);
    expect(find.text("Kamola Yo'ldosheva"), findsWidgets);
    expectNoRealErrors(tester);
  });

  testWidgets('Bitta a\'zoli guruh — podium qulamaydi (faqat 1-o\'rin)', (tester) async {
    useSmallScreen(tester);
    _api(_oneMemberJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await _openGroupTab(tester);

    expect(find.byType(PodiumCard), findsOneWidget);
    expect(find.text('Siz · 1'), findsOneWidget);
    expectNoRealErrors(tester, reason: 'bitta a\'zoli guruh');
  });

  testWidgets('Ikki a\'zoli guruh — 3-ustun bo\'sh, toshmaydi', (tester) async {
    useSmallScreen(tester);
    _api(_twoMembersJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await _openGroupTab(tester);

    expect(find.byType(PodiumCard), findsNWidgets(2));
    expect(find.text("1-o'rin"), findsOneWidget);
    expect(find.text('Siz · 2'), findsOneWidget);
    expectNoRealErrors(tester, reason: 'ikki a\'zoli guruh');
  });

  testWidgets('Faol guruh yo\'q — tushunarli bo\'sh holat (jim bo\'sh jadval EMAS)',
      (tester) async {
    useTallScreen(tester);
    _api(_noGroupsJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await _openGroupTab(tester);

    expect(find.byType(PodiumCard), findsNothing);
    expect(find.text("Guruh reytingi yo'q"), findsOneWidget);
    expectNoRealErrors(tester);
  });

  testWidgets('Bitta guruhda chip KO\'RSATILMAYDI (tanlaydigan narsa yo\'q)',
      (tester) async {
    useTallScreen(tester);
    _api(_oneMemberJson);
    await tester.pumpWidget(wrapBody(const ProgressScreen()));
    await settle(tester);
    await _openGroupTab(tester);

    // Sarlavhada guruh nomi bir marta chiqadi; chip bo'lganda ikki marta bo'lardi.
    expect(find.text('Yakka guruh'), findsOneWidget);
    expectNoRealErrors(tester);
  });
}
