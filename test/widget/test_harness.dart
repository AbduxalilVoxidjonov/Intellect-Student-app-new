// Umumiy test yordamchilari — soxta (fake) Dio adapteri, soxta asset bundle,
// ekranni o'rovchi funksiyalar va xatolarni tekshirish.
//
// DIQQAT: bu fayl `_test.dart` bilan tugamaydi — `flutter test` uni alohida
// ishga tushirmaydi, faqat import qilinadi.
//
// Naqsh mavjud `test/screens_render_test.dart` dagi soxta adapterdan olingan,
// lekin marshrut (route) bo'yicha javob va HOLAT KODINI ham berish mumkin —
// shu sabab 500/403/bo'sh javob stsenariylarini yozish oson.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:student/api/api_client.dart';
import 'package:student/services/session.dart';
import 'package:student/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Soxta API
// ---------------------------------------------------------------------------

class _Route {
  final String match;
  final String body;
  final int status;

  /// `null` — istalgan metod; aks holda 'GET'/'POST'/'PUT'/'DELETE'.
  final String? method;
  const _Route(this.match, this.body, this.status, this.method);

  bool matches(RequestOptions o) =>
      o.path.contains(match) &&
      (method == null || o.method.toUpperCase() == method!.toUpperCase());
}

/// Marshrut bo'yicha javob qaytaradigan soxta HTTP adapter.
///
/// Marshrutlar QO'SHILGAN TARTIBDA tekshiriladi — aniqrog'ini (masalan
/// `/submit`) oldinroq qo'shing.
class FakeApi implements HttpClientAdapter {
  FakeApi({this.fallbackBody = '{}', this.fallbackStatus = 200});

  /// Hech bir marshrutga tushmagan so'rov uchun javob.
  String fallbackBody;
  int fallbackStatus;

  final List<_Route> _routes = <_Route>[];

  /// Yuborilgan barcha so'rovlar (tekshirish uchun).
  final List<RequestOptions> requests = <RequestOptions>[];

  void on(String match, String body, {int status = 200, String? method}) =>
      _routes.add(_Route(match, body, status, method));

  /// Shu marshrut xato qaytarsin (default — 500, ya'ni Dio istisno tashlaydi).
  void failOn(String match,
          {int status = 500, String body = '{"message":"Server xatosi"}', String? method}) =>
      _routes.add(_Route(match, body, status, method));

  /// Barcha so'rovlar xato qaytarsin.
  void failEverything({int status = 500, String body = '{"message":"Server xatosi"}'}) {
    fallbackStatus = status;
    fallbackBody = body;
  }

  List<RequestOptions> requestsFor(String match) =>
      requests.where((r) => r.path.contains(match)).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    for (final r in _routes) {
      if (r.matches(options)) return _resp(r.body, r.status);
    }
    return _resp(fallbackBody, fallbackStatus);
  }

  ResponseBody _resp(String body, int status) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Global `ApiClient.dio` ga soxta adapterni o'rnatadi.
FakeApi installFakeApi({String fallbackBody = '{}', int fallbackStatus = 200}) {
  final api = FakeApi(fallbackBody: fallbackBody, fallbackStatus: fallbackStatus);
  ApiClient.dio.httpClientAdapter = api;
  ApiClient.token = 'test-token';
  // 401 kelganda sessiya tugatilmasin (testda Session mock emas).
  ApiClient.onUnauthorized = null;
  return api;
}

// ---------------------------------------------------------------------------
// Haqiqiy shrift (Roboto)
// ---------------------------------------------------------------------------

/// Yuklangan Roboto oilasi uchun fayl nomlari (qalinlik ma'lumoti shriftning
/// o'z ichida — `FontLoader` hammasini bitta oila sifatida ro'yxatga oladi).
const List<String> _kRobotoFiles = [
  'Roboto-Regular.ttf',
  'Roboto-Medium.ttf',
  'Roboto-Bold.ttf',
  'Roboto-Black.ttf',
];

bool? _fontsLoaded;

/// Flutter SDK keshidagi `material_fonts` papkasini topadi.
///
/// QATTIQ YO'L YOZILMAYDI — avval `FLUTTER_ROOT` muhit o'zgaruvchisi
/// (`flutter test` uni har doim beradi), bo'lmasa test dvigateli (engine)
/// binarining yo'lidan (`<root>/bin/cache/artifacts/engine/...`) tiklanadi.
/// Ikkalasi ham bo'lmasa `null` — chaqiruvchi jimgina eski rejimda ishlaydi.
String? _materialFontsDir() {
  final candidates = <String>[];
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) candidates.add(env);
  final exe = Platform.resolvedExecutable;
  final i = exe.indexOf('${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}');
  if (i > 0) candidates.add(exe.substring(0, i));
  for (final root in candidates) {
    final dir = Directory([root, 'bin', 'cache', 'artifacts', 'material_fonts']
        .join(Platform.pathSeparator));
    if (dir.existsSync()) return dir.path;
  }
  return null;
}

/// Testga HAQIQIY Roboto shriftini yuklaydi (mavzu `fontFamily: 'Roboto'`
/// ishlatadi, shuning uchun qo'shimcha sozlash kerak emas).
///
/// NEGA KERAK: `flutter test` odatda hech qanday shrift yuklamaydi va
/// "FlutterTest" (Ahem uslubidagi) zaxira shriftda HAR BIR BELGI aynan 1em
/// kenglikda chiziladi — Roboto'dagidan ~2 baravar keng. Natijada gorizontal
/// toshish testlari qurilmadagidan ancha erta ishga tushadi: ham noto'g'ri
/// xato beradi, ham (matn boshqacha ko'chgani uchun) haqiqiy muammoni
/// yashirishi mumkin. Roboto bilan o'lchov qurilmadagiga mos keladi.
///
/// Shrift topilmasa (masalan SDK keshi tozalangan CI) — `false` qaytaradi va
/// test avvalgidek zaxira shriftda ishlaydi, ya'ni hech narsa yiqilmaydi.
/// `setUpAll` da bir marta chaqirish yetarli.
Future<bool> loadRealFonts() async {
  if (_fontsLoaded != null) return _fontsLoaded!;
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = _materialFontsDir();
  if (dir == null) return _fontsLoaded = false;
  final loader = FontLoader('Roboto');
  var added = 0;
  for (final name in _kRobotoFiles) {
    final file = File([dir, name].join(Platform.pathSeparator));
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    added++;
  }
  if (added == 0) return _fontsLoaded = false;
  await loader.load();
  return _fontsLoaded = true;
}

// ---------------------------------------------------------------------------
// Soxta asset bundle — `Image.asset('assets/logo.png')` testda yiqilmasin.
// ---------------------------------------------------------------------------

/// 1x1 shaffof PNG.
const String _kTinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class FakeAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.json')) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode('{}')));
    }
    if (key.endsWith('.bin')) {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    return ByteData.sublistView(base64Decode(_kTinyPng));
  }
}

// ---------------------------------------------------------------------------
// Ekranni o'rash
// ---------------------------------------------------------------------------

/// O'z `Scaffold`iga ega ekran uchun (SubScaffold ishlatadiganlar).
Widget wrapRoot(Widget screen, {Session? session, AppColors? colors}) {
  final c = colors ?? AppColors.light;
  return DefaultAssetBundle(
    bundle: FakeAssetBundle(),
    child: ChangeNotifierProvider<Session>.value(
      value: session ?? Session(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildMaterialTheme(c),
        builder: (context, child) => AppTheme(colors: c, child: child ?? const SizedBox()),
        home: screen,
      ),
    ),
  );
}

/// `Scaffold`siz tab widgetlari uchun (Dashboard/Progress/Test/Chat/Profil).
Widget wrapBody(Widget body, {Session? session, AppColors? colors}) =>
    wrapRoot(Scaffold(body: SafeArea(child: body)), session: session, colors: colors);

/// Barcha async yuklashlar tugashini kutadi.
///
/// `pumpAndSettle` ISHLATILMAYDI — `Loader` (CircularProgressIndicator) cheksiz
/// animatsiya qiladi va `pumpAndSettle` timeout bo'ladi.
Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Widget daraxtini yopadi — `dispose()` chaqirilib, timer/controller tozalanadi.
/// Chatga o'xshash `Timer.periodic` ishlatadigan ekranlardan keyin SHART.
Future<void> tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Kichik telefon ekrani (360x640 dp) — overflow tekshiruvi uchun.
///
/// DIQQAT (test shrifti): `flutter test` sukut bo'yicha HECH QANDAY haqiqiy
/// shrift yuklamaydi — "FlutterTest" (Ahem uslubidagi) zaxira shriftda HAR BIR
/// BELGI aynan 1em kenglikda chiziladi, ya'ni matn qurilmadagidan ~2 BARAVAR
/// keng va gorizontal ("on the right") toshish ancha erta "topiladi".
/// Layout/overflow o'lchaydigan testlar shu sabab `setUpAll` da
/// [loadRealFonts] ni chaqirishi KERAK — undan keyin o'lchov qurilmadagiga
/// mos bo'ladi.
void useSmallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Baland test ekrani (800x2400 dp).
///
/// Flutter `ListView` ning EKRANDAN TASHQARIDAGI elementlarini umuman
/// qurmaydi, shuning uchun `find.text(...)` ularni topa olmaydi. Uzun
/// ekranlarning pastki qismini (tarix, bo'sh holat va h.k.) tekshiradigan
/// MAZMUN testlari shu yordamchini ishlatadi. Layout/overflow testlarida
/// ishlatilmaydi — u yerda `useSmallScreen` kerak.
void useTallScreen(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(800 * 3, height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

// ---------------------------------------------------------------------------
// Xato tekshiruvi
// ---------------------------------------------------------------------------

const List<String> _ignorable = [
  'Unable to load asset',
  'AssetManifest',
  'HTTP request failed', // NetworkImage testda tarmoqqa chiqolmaydi
  'Failed to load network image',
];

/// Kutilmagan istisnolar (overflow, null check, RangeError, ...) bo'lmasligini
/// tekshiradi. Asset/tarmoq rasm xatolari e'tiborsiz qoldiriladi.
///
/// [ignoreOverflow] — FAQAT mazmun (matn/holat) tekshiradigan testlar uchun:
/// shu ekranning "RenderFlex overflowed" muammosi ALOHIDA hujjatlashtirilgan
/// (qarang `overflow_test.dart`) va bu testning maqsadi emas. Har bir ishlatish
/// joyida qaysi toshish e'tiborsiz qoldirilayotgani izohda yozilishi SHART.
void expectNoRealErrors(WidgetTester tester, {String? reason, bool ignoreOverflow = false}) {
  while (true) {
    final Object? ex = tester.takeException();
    if (ex == null) return;
    final s = ex.toString();
    final ignore = _ignorable.any(s.contains) ||
        (ignoreOverflow && s.contains('RenderFlex overflowed'));
    if (!ignore) {
      fail('Kutilmagan istisno${reason == null ? '' : ' ($reason)'}: $s');
    }
  }
}

/// Ekrandagi barcha oddiy matnlar (Text.data).
List<String> allTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toList();
