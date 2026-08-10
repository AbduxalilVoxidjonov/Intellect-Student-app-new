// FaceCheckScreen — kirishda yuz bilan tasdiqlash OQIMI.
//
// Kamera ham, ONNX modeli ham testda yo'q: ikkalasi ham interfeys ortida
// (`FaceCamera` / `FaceEngine`), shu sabab butun oqim — sifat darvozasi,
// tiriklik harakatlari, etalon vektor va serverga yuborish — soxta kadrlar
// bilan sinaladi.
//
// VAQT: `ms` o'lchovi `DateTime.now()` ga tayanadi, `tester.pump` esa uni
// SURMAYDI. Shuning uchun ekranga soat beriladi va u har kadrda 500 ms ga
// suriladi (haqiqiy telefondagi kadr tezligiga yaqin).

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/face/face_engine.dart';
import 'package:student/screens/face_check_screen.dart';
import 'package:student/services/device_identity.dart';
import 'package:student/services/face_camera.dart';
import 'package:student/services/session.dart';

import 'test_harness.dart';

// ---------------------------------------------------------------------------
// Yordamchilar
// ---------------------------------------------------------------------------

/// Kameradan keladigan kadr (FakeFaceCamera'ning sukut bo'yicha baytlari).
final Uint8List _frameBytes = Uint8List.fromList(const [1, 2, 3, 4]);

Float32List _vector() {
  final v = Float32List(128);
  v[0] = 1;
  return v;
}

FaceQuality _quality({double ratio = 0.3, double yaw = 0, double roll = 0}) => FaceQuality(
      faces: 1,
      faceRatio: ratio,
      sharpness: 300,
      brightness: 130,
      yaw: yaw,
      roll: roll,
    );

/// Sifat darvozasidan O'TGAN kadr.
FaceResult _ok({double ratio = 0.3, double yaw = 0}) => FaceResult.ok(
      FaceCapture(
        jpeg: Uint8List.fromList(const [7, 7, 7]),
        vector: _vector(),
        quality: _quality(ratio: ratio, yaw: yaw),
      ),
    );

/// Sifat darvozasidan o'tmagan, LEKIN o'lchovi bor kadr (yuz burilgan payt).
FaceResult _measured(String reason, {double ratio = 0.3, double yaw = 0}) =>
    FaceResult.fail(reason, _quality(ratio: ratio, yaw: yaw));

/// Yuz umuman topilmagan kadr.
FaceResult _noFace() => FaceResult.fail(FaceReasons.noFace, FaceQuality.none);

/// Kadrlarni SSENARIY bo'yicha qaytaradigan dvigatel.
///
/// Kamera kadrlari (`[1,2,3,4]`) va PROFIL RASMI baytlari ajratiladi — ikkalasi
/// ham `analyze` orqali o'tadi, lekin ma'nosi boshqa.
class _ScriptEngine implements FaceEngine {
  _ScriptEngine({required this.frames, this.photo});

  final FaceResult Function(int index) frames;
  final FaceResult Function()? photo;

  int frameCalls = 0;
  int photoCalls = 0;

  /// Profil rasmi qaysi chegaralar bilan tahlil qilingani (yumshoqroq bo'lishi kerak).
  FaceThresholds? photoThresholds;

  @override
  String get modelVersion => 'test-model-v1';

  @override
  Future<void> init() async {}

  @override
  Future<FaceResult> analyze(Uint8List bytes, FaceThresholds t) async {
    final isFrame = bytes.length == _frameBytes.length;
    if (!isFrame) {
      photoCalls++;
      photoThresholds = t;
      return photo?.call() ?? _noFace();
    }
    return frames(frameCalls++);
  }

  @override
  void dispose() {}
}

const String _statusOk = '''
{"enabled":true,"enrolled":false,"hasPhoto":true,"modelVersion":"test-model-v1",
 "threshold":0.6,"attemptsLeft":5,
 "quality":{"minSharpness":40,"minBrightness":55,"maxBrightness":215,
            "minFaceRatio":0.15,"maxYaw":25,"maxRoll":20},
 "requireLiveness":true}
''';

String _challengeJson({
  String nonce = 'n-1',
  List<String> actions = const ['turn_left', 'move_closer'],
  int ttl = 90,
}) =>
    jsonEncode({
      'nonce': nonce,
      'actions': actions,
      'ttlSeconds': ttl,
      'expiresAt': '2026-08-10T12:00:00',
    });

/// Cheklangan token bilan "kirgan" sessiya.
///
/// ⚠️ `tester.runAsync` SHART: `Session.init/login` `SharedPreferences` (platforma
/// kanali) bilan ishlaydi, kanal javobi esa soxta vaqt zonasida faqat `pump`
/// bilan yetib keladi — to'g'ridan-to'g'ri `await` qilinsa test QOTIB qoladi.
Future<Session> _faceSession(WidgetTester tester, FakeApi api) async {
  api.on(
    '/auth/login',
    '{"token":"limited","user":{"id":"u1","fullName":"Ali Valiyev","role":"student"},'
        '"faceRequired":true,"faceStatus":"enroll"}',
  );
  final s = await tester.runAsync(() async {
    final session = Session();
    await session.init();
    await session.login('ali@test.uz', 'parol');
    return session;
  });
  return s!;
}

/// Ekranni quradi; soat har kadrda 500 ms ga suriladi.
Widget _screen({
  required _ScriptEngine engine,
  required FakeFaceCamera camera,
  required Session session,
}) {
  var ms = 0;
  camera.onFrame = (_) => ms += 500;
  return wrapRoot(
    FaceCheckScreen(
      engine: engine,
      camera: camera,
      clock: () => DateTime.fromMillisecondsSinceEpoch(ms),
      pollInterval: const Duration(milliseconds: 100),
    ),
    session: session,
  );
}

Map<String, String> _formFields(RequestOptions o) {
  final data = o.data;
  if (data is! FormData) return const {};
  return {for (final e in data.fields) e.key: e.value};
}

void main() {
  // ⚠️ `loadRealFonts` FAQAT `setUpAll` da: u haqiqiy fayl o'qiydi, testWidgets
  // ichidagi soxta vaqt zonasida esa bunday `await` qotib qoladi.
  setUpAll(loadRealFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DeviceIdentity.resetCache();
  });

  // -------------------------------------------------------------------------
  testWidgets('ENROLL — etalon profil rasmidan olinadi va refVector yuboriladi',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson());
    api.on('/student/face/photo', '{"fake":"profil-rasmi-baytlari"}');
    api.on(
      '/student/face/verify',
      '{"ok":true,"status":"approved","reason":"","score":0.81,'
          '"attemptsLeft":4,"token":"FULL-JWT","enrolled":true}',
    );
    final session = await _faceSession(tester, api);

    final engine = _ScriptEngine(
      frames: (i) => switch (i) {
        // 0 — tekislash: sifat yaxshi, boshlang'ich faceRatio = 0.30
        0 => _ok(ratio: 0.3),
        // 1 — "chapga buring": sifat darvozasidan o'tmaydi (yuz burilgan),
        //     lekin O'LCHOV bor va u chegaradan o'tadi (-28°)
        1 => _measured(FaceReasons.notFrontal, yaw: -28, ratio: 0.3),
        // 2 — "yaqinroq keling": 0.30 → 0.50 (1.67x)
        2 => _ok(ratio: 0.5),
        // 3 — yakuniy kadr: odatdagi masofa
        _ => _ok(ratio: 0.3),
      },
      photo: () => _ok(ratio: 0.35),
    );

    await tester.pumpWidget(
        _screen(engine: engine, camera: FakeFaceCamera(), session: session));
    await settle(tester, frames: 25);
    expectNoRealErrors(tester);

    final verify = api.requestsFor('/student/face/verify');
    expect(verify, hasLength(1), reason: 'tekshiruv aynan bir marta yuborilsin');

    final f = _formFields(verify.single);
    expect(f['nonce'], 'n-1');
    expect(f['refVector'], isNotNull, reason: 'etalon yo\'q — profil rasmidan olinadi');
    expect(f['vector'], isNotEmpty);
    expect(f['modelVersion'], 'test-model-v1');
    expect(f['deviceId'], isNotEmpty);
    expect(engine.photoCalls, 1);

    // Profil rasmi YUMSHOQ chegaralar bilan tahlil qilinadi (eski surat
    // "sifatsiz" deb rad etilmasin).
    expect(engine.photoThresholds?.minSharpness, kProfilePhotoThresholds.minSharpness);

    // Rasm fayli — server FAQAT .jpg kengaytmasini qabul qiladi.
    final files = (verify.single.data as FormData).files;
    expect(files.single.key, 'image');
    expect(files.single.value.filename, endsWith('.jpg'));

    // Tiriklik: TARTIB, `ms` va O'LCHANGAN qiymat.
    final steps = jsonDecode(f['liveness']!) as List;
    expect(steps, hasLength(2));
    expect(steps[0]['action'], 'turn_left');
    expect(steps[0]['ok'], isTrue);
    expect(steps[0]['value'], -28);
    expect(steps[0]['ms'], greaterThanOrEqualTo(300));
    expect(steps[0]['ms'], lessThanOrEqualTo(20000));
    expect(steps[1]['action'], 'move_closer');
    expect(steps[1]['value'], 0.5);
    expect(steps[1]['ms'], isA<int>());

    // Sifat o'lchovlari — server kalitlari (registrga sezgir).
    final quality = jsonDecode(f['quality']!) as Map<String, dynamic>;
    expect(quality.keys,
        containsAll(['faces', 'sharpness', 'brightness', 'faceRatio', 'yaw', 'roll']));

    // TO'LIQ token saqlandi — ilova endi qobiqni ochadi.
    expect(session.token, 'FULL-JWT');
    expect(session.faceRequired, isFalse);
  });

  // -------------------------------------------------------------------------
  testWidgets('etalon BOR — profil rasmi umuman so\'ralmaydi', (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status',
        _statusOk.replaceAll('"enrolled":false', '"enrolled":true'));
    api.on('/student/face/challenge', _challengeJson(actions: ['turn_right']));
    api.on(
      '/student/face/verify',
      '{"ok":true,"status":"approved","reason":"","score":0.9,'
          '"attemptsLeft":4,"token":"FULL","enrolled":false}',
    );
    final session = await _faceSession(tester, api);

    final engine = _ScriptEngine(
      frames: (i) => switch (i) {
        0 => _ok(ratio: 0.3),
        1 => _measured(FaceReasons.notFrontal, yaw: 30),
        _ => _ok(ratio: 0.3),
      },
    );

    await tester.pumpWidget(
        _screen(engine: engine, camera: FakeFaceCamera(), session: session));
    await settle(tester, frames: 25);
    expectNoRealErrors(tester);

    expect(api.requestsFor('/student/face/photo'), isEmpty);
    expect(engine.photoCalls, 0);
    final f = _formFields(api.requestsFor('/student/face/verify').single);
    expect(f['refVector'], isNull);
    expect(session.token, 'FULL');
  });

  // -------------------------------------------------------------------------
  testWidgets('profil rasmida yuz topilmasa — refVector SIZ ketadi va "kutilmoqda" ko\'rinadi',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson(actions: ['move_back']));
    api.on('/student/face/photo', '{"fake":"rasm"}');
    api.on(
      '/student/face/verify',
      '{"ok":false,"status":"pending","reason":"Rasmingiz tekshiruvga yuborildi",'
          '"score":null,"attemptsLeft":4,"token":null,"enrolled":false}',
    );
    final session = await _faceSession(tester, api);

    final engine = _ScriptEngine(
      frames: (i) => switch (i) {
        0 => _ok(ratio: 0.30),
        1 => _ok(ratio: 0.18), // uzoqlashdi (0.6x)
        _ => _ok(ratio: 0.30), // yakuniy kadr — odatdagi masofa
      },
      photo: () => _noFace(), // profil rasmida yuz yo'q
    );

    await tester.pumpWidget(
        _screen(engine: engine, camera: FakeFaceCamera(), session: session));
    await settle(tester, frames: 25);
    expectNoRealErrors(tester);

    final f = _formFields(api.requestsFor('/student/face/verify').single);
    expect(f['refVector'], isNull, reason: 'yuz topilmagan rasmdan etalon yasalmaydi');
    expect(jsonDecode(f['liveness']!)[0]['action'], 'move_back');

    // Foydalanuvchiga NIMA bo'lgani tushuntiriladi.
    expect(find.textContaining('administrator'), findsOneWidget);
    expect(session.faceRequired, isTrue, reason: 'hali kirmadi');
    expect(find.text('Chiqish'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  testWidgets('harakat bajarilmasa keyingisiga O\'TILMAYDI va hech narsa yuborilmaydi',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson());
    final session = await _faceSession(tester, api);

    // Yuz doim to'g'ri qaragan — "chapga buring" hech qachon bajarilmaydi.
    final engine = _ScriptEngine(frames: (_) => _ok(ratio: 0.3));

    await tester.pumpWidget(
        _screen(engine: engine, camera: FakeFaceCamera(), session: session));
    await settle(tester, frames: 25);
    expectNoRealErrors(tester);

    expect(find.text('Boshingizni CHAPGA buring'), findsOneWidget);
    expect(find.text('Harakat 1 / 2'), findsOneWidget);
    expect(api.requestsFor('/student/face/verify'), isEmpty);
  });

  // -------------------------------------------------------------------------
  testWidgets('nonce muddati tugasa — YANGI topshiriq so\'raladi', (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    // TTL 10 s → 5 s zaxira ayiriladi, ya'ni ~10 kadrdan keyin eskiradi.
    api.on('/student/face/challenge', _challengeJson(ttl: 10));
    final session = await _faceSession(tester, api);

    final engine = _ScriptEngine(frames: (_) => _ok(ratio: 0.3)); // harakat bajarilmaydi

    await tester.pumpWidget(
        _screen(engine: engine, camera: FakeFaceCamera(), session: session));
    await settle(tester, frames: 30);
    expectNoRealErrors(tester);

    expect(api.requestsFor('/student/face/challenge').length, greaterThanOrEqualTo(2),
        reason: 'eskirgan nonce bilan yuborilgan javobni server rad etardi');
    expect(api.requestsFor('/student/face/verify'), isEmpty);
  });

  // -------------------------------------------------------------------------
  testWidgets('rad etildi — sabab va qolgan urinishlar ko\'rinadi', (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson(actions: ['turn_left']));
    api.on('/student/face/photo', '{"fake":"rasm"}');
    api.on(
      '/student/face/verify',
      '{"ok":false,"status":"rejected","reason":"Yuz mos kelmadi","score":0.31,'
          '"attemptsLeft":2,"token":null,"enrolled":false}',
    );
    final session = await _faceSession(tester, api);

    final engine = _ScriptEngine(
      frames: (i) => switch (i) {
        0 => _ok(ratio: 0.3),
        1 => _measured(FaceReasons.notFrontal, yaw: -25),
        _ => _ok(ratio: 0.3),
      },
      photo: () => _ok(),
    );

    await tester.pumpWidget(
        _screen(engine: engine, camera: FakeFaceCamera(), session: session));
    await settle(tester, frames: 25);
    expectNoRealErrors(tester);

    expect(find.text('Yuz mos kelmadi'), findsOneWidget);
    expect(find.text('Qolgan urinishlar: 2'), findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);
    expect(session.faceRequired, isTrue);
  });

  // -------------------------------------------------------------------------
  testWidgets('urinishlar tugagan (attemptsLeft: 0) — kamera umuman ochilmaydi',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk.replaceAll('"attemptsLeft":5', '"attemptsLeft":0'));
    final session = await _faceSession(tester, api);
    final camera = FakeFaceCamera();

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok()),
      camera: camera,
      session: session,
    ));
    await settle(tester, frames: 10);
    expectNoRealErrors(tester);

    expect(find.textContaining('Urinishlar soni oshdi'), findsOneWidget);
    expect(find.textContaining('Bir soatdan keyin'), findsOneWidget);
    expect(find.text('Qayta urinish'), findsNothing);
    expect(camera.startCount, 0, reason: 'foydalanuvchini bekorga selfi olishga majburlamaymiz');
  });

  // -------------------------------------------------------------------------
  testWidgets('modul o\'chirilgan (enabled: false) — qaytadan kirish taklif qilinadi',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk.replaceAll('"enabled":true', '"enabled":false'));
    final session = await _faceSession(tester, api);

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok()),
      camera: FakeFaceCamera(),
      session: session,
    ));
    await settle(tester, frames: 10);
    expectNoRealErrors(tester);

    expect(find.textContaining("o'chirilgan"), findsOneWidget);
    expect(find.text('Qaytadan kirish'), findsOneWidget);
    expect(api.requestsFor('/student/face/challenge'), isEmpty);
  });

  // -------------------------------------------------------------------------
  testWidgets('kamera ruxsati rad etildi — tushunarli ekran va qayta so\'rash',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    final session = await _faceSession(tester, api);
    final camera = FakeFaceCamera(status: FaceCameraStatus.denied);

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok()),
      camera: camera,
      session: session,
    ));
    await settle(tester, frames: 10);
    expectNoRealErrors(tester);

    expect(find.textContaining('ruxsat bering'), findsOneWidget);
    expect(find.text('Ruxsat berish'), findsOneWidget);

    // Endi ruxsat berildi — tugma oqimni davom ettiradi.
    camera.status = FaceCameraStatus.ready;
    await tester.tap(find.text('Ruxsat berish'));
    await settle(tester, frames: 5);
    expect(camera.startCount, 2);
    expect(find.text('Ruxsat berish'), findsNothing);
  });

  testWidgets('ruxsat butunlay rad etilgan — sozlamalar tugmasi', (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    final session = await _faceSession(tester, api);

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok()),
      camera: FakeFaceCamera(status: FaceCameraStatus.permanentlyDenied),
      session: session,
    ));
    await settle(tester, frames: 10);
    expectNoRealErrors(tester);

    expect(find.text('Sozlamalarni ochish'), findsOneWidget);
    expect(find.text('Ruxsat berish'), findsNothing);
  });

  // -------------------------------------------------------------------------
  testWidgets('sifat yomon — jonli maslahat ko\'rsatiladi, topshiriq so\'ralmaydi',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson());
    final session = await _faceSession(tester, api);

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _measured(FaceReasons.dark, ratio: 0.3)),
      camera: FakeFaceCamera(),
      session: session,
    ));
    await settle(tester, frames: 12);
    expectNoRealErrors(tester);

    expect(find.text(FaceReasons.dark), findsOneWidget);
    expect(find.text('Yuzingizni ramkaga joylashtiring'), findsOneWidget);
    expect(api.requestsFor('/student/face/challenge'), isEmpty);
  });

  // -------------------------------------------------------------------------
  testWidgets('tiriklik MAJBURIY emas va topshiriq olinmadi — selfi baribir ketadi',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status',
        _statusOk.replaceAll('"requireLiveness":true', '"requireLiveness":false'));
    // Topshiriq limiti (soatiga 15 ta) — foydalanuvchi shu sabab kira olmay
    // qolmasligi kerak.
    api.failOn('/student/face/challenge', status: 400, body: '{"message":"Urinishlar soni oshdi"}');
    api.on('/student/face/photo', '{"fake":"rasm"}');
    api.on(
      '/student/face/verify',
      '{"ok":true,"status":"approved","reason":"","score":0.77,'
          '"attemptsLeft":4,"token":"FULL","enrolled":true}',
    );
    final session = await _faceSession(tester, api);

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok(ratio: 0.3), photo: () => _ok()),
      camera: FakeFaceCamera(),
      session: session,
    ));
    await settle(tester, frames: 20);
    expectNoRealErrors(tester);

    final f = _formFields(api.requestsFor('/student/face/verify').single);
    expect(f['nonce'], isNull);
    expect(f['liveness'], isNull, reason: 'nonce yo\'q — soxta tiriklik ham yubormaymiz');
    expect(session.token, 'FULL');
  });

  // -------------------------------------------------------------------------
  testWidgets('status so\'rovi yiqildi — xato ekrani va "Qayta urinish"', (tester) async {
    final api = installFakeApi();
    api.failOn('/student/face/status');
    final session = await _faceSession(tester, api);

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok()),
      camera: FakeFaceCamera(),
      session: session,
    ));
    await settle(tester, frames: 10);
    expectNoRealErrors(tester);

    expect(find.text('Server xatosi'), findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);
    expect(find.text('Chiqish'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  testWidgets('ilova fonga o\'tib qaytsa — kamera qayta ochiladi va BOSHIDAN',
      (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson());
    final session = await _faceSession(tester, api);
    final camera = FakeFaceCamera();

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok(ratio: 0.3)),
      camera: camera,
      session: session,
    ));
    await settle(tester, frames: 10);
    expect(camera.startCount, 1);

    // Fonga o'tdi — kamera bo'shatiladi (tizim uni baribir tortib oladi).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester, frames: 3);
    expect(camera.stopCount, 1);

    // Qaytdi — qayta ochiladi va tekshiruv boshidan boshlanadi.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester, frames: 10);
    expectNoRealErrors(tester);
    expect(camera.startCount, 2);
    expect(find.text('Boshingizni CHAPGA buring'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  testWidgets('kichik ekranda (360dp) toshib ketmaydi', (tester) async {
    useSmallScreen(tester);

    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson());
    final session = await _faceSession(tester, api);

    await tester.pumpWidget(_screen(
      // Harakat bosqichida to'xtaydi — eng "to'la" ko'rinish (doira + karta +
      // progress + ikkita tugma).
      engine: _ScriptEngine(frames: (_) => _ok(ratio: 0.3)),
      camera: FakeFaceCamera(),
      session: session,
    ));
    await settle(tester, frames: 12);
    expectNoRealErrors(tester);
    expect(find.text('Boshingizni CHAPGA buring'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  testWidgets('"Chiqish" — sessiya tugatiladi va kamera yopiladi', (tester) async {
    final api = installFakeApi();
    api.on('/student/face/status', _statusOk);
    api.on('/student/face/challenge', _challengeJson());
    final session = await _faceSession(tester, api);
    final camera = FakeFaceCamera();

    await tester.pumpWidget(_screen(
      engine: _ScriptEngine(frames: (_) => _ok(ratio: 0.3)),
      camera: camera,
      session: session,
    ));
    await settle(tester, frames: 8);

    await tester.tap(find.text('Chiqish'));
    await settle(tester, frames: 5);
    expectNoRealErrors(tester);

    expect(session.isAuthed, isFalse);
    expect(camera.stopCount, greaterThanOrEqualTo(1));
    await tearDownTree(tester);
  });
}
