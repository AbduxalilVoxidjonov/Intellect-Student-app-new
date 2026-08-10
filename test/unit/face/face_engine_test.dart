import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/face/face_engine.dart';
import 'package:student/face/face_image.dart';
import 'package:student/face/ort_runner.dart';

import 'face_fixtures.dart';

/// BUTUN quvur testi — ONNX modeli KERAK EMAS.
///
/// `OrtRunner` almashtiriladi: detektor o'rniga sun'iy tenzorlar, embedding
/// o'rniga kirishdan determinilangan tarzda hisoblangan vektor. Shu tufayli
/// dekodlash → sifat → tekislash → normallashtirish zanjiri to'liq tekshiriladi.
void main() {
  const t = FaceThresholds.fallback;

  group('FakeFaceEngine', () {
    test('sukut bo\'yicha "Yuz topilmadi" qaytaradi', () async {
      final e = FakeFaceEngine();
      final r = await e.analyze(Uint8List(0), t);
      expect(r.ok, isFalse);
      expect(r.reason, FaceReasons.noFace);
    });

    test('muvaffaqiyat: vektor normallashgan, sabab yo\'q', () async {
      final e = FakeFaceEngine.success();
      final r = await e.analyze(Uint8List(0), t);
      expect(r.ok, isTrue);
      expect(r.reason, isNull);
      expect(r.capture!.vector.length, FaceModels.vectorLength);
      expect(cosineSimilarity(r.capture!.vector, r.capture!.vector), closeTo(1, 1e-6));
    });

    test('kirish baytlari va chegaralar eslab qolinadi', () async {
      final e = FakeFaceEngine();
      final bytes = Uint8List.fromList([1, 2, 3]);
      await e.analyze(bytes, t);
      expect(e.lastBytes, bytes);
      expect(e.lastThresholds, same(t));
      expect(e.analyzeCount, 1);
    });

    test('init IDEMPOTENT — ikki marta chaqirilsa bir marta yuklanadi', () async {
      final e = FakeFaceEngine();
      await e.init();
      await e.init();
      await e.analyze(Uint8List(0), t);
      expect(e.initCount, 1);
    });

    test('natijani almashtirish mumkin (ekran holatlarini sinash uchun)', () async {
      final e = FakeFaceEngine();
      e.result = FaceResult.fail(FaceReasons.tooFar);
      expect((await e.analyze(Uint8List(0), t)).reason, FaceReasons.tooFar);
    });

    test('dispose dan keyin analyze xato bermaydi-yu, init qayta hisoblanadi', () async {
      final e = FakeFaceEngine()..dispose();
      expect(e.disposed, isTrue);
      await expectLater(e.analyze(Uint8List(0), t), throwsStateError);
    });

    test('modelVersion serverdagi satr bilan bir xil', () {
      expect(FakeFaceEngine().modelVersion, FaceModels.modelVersion);
    });
  });

  group('OnnxFaceEngine — to\'liq quvur (soxta runner bilan)', () {
    late _ScriptedRunner runner;
    late OnnxFaceEngine engine;

    // 640×480 rasm → letterbox masshtabi 1, ya'ni model fazosi = ishchi rasm.
    final sharp = synthSharpPng(640, 480);

    setUp(() {
      runner = _ScriptedRunner();
      engine = OnnxFaceEngine(runner: runner, useIsolate: false);
    });

    tearDown(() => engine.dispose());

    test('muvaffaqiyat: vektor, JPEG va sifat qaytadi', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final r = await engine.analyze(sharp, t);

      expect(r.reason, isNull, reason: 'kutilmagan rad: ${r.reason}');
      expect(r.ok, isTrue);
      final c = r.capture!;
      expect(c.vector.length, FaceModels.vectorLength);
      expect(cosineSimilarity(c.vector, c.vector), closeTo(1, 1e-6));
      expect(c.jpeg.length, greaterThan(100));
      // JPEG imzosi
      expect(c.jpeg[0], 0xFF);
      expect(c.jpeg[1], 0xD8);
      expect(c.quality.faces, 1);
      expect(c.quality.faceRatio, closeTo(220 / 640, 0.01));
    });

    test('modelga ketgan tenzorlar to\'g\'ri o\'lchamda', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      await engine.analyze(sharp, t);
      expect(runner.lastDetectorInput!.length, 3 * 640 * 640);
      expect(runner.lastRecognizerInput!.length, 3 * 112 * 112);
      // 0..255 oralig'i saqlanadi (normallashtirish modelda emas).
      expect(runner.lastRecognizerInput!.reduce((a, b) => a > b ? a : b), lessThan(256));
    });

    test('BIR XIL rasm → BIR XIL vektor (determinilangan)', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final a = await engine.analyze(sharp, t);
      final b = await engine.analyze(sharp, t);
      expect(a.ok && b.ok, isTrue);
      expect(cosineSimilarity(a.capture!.vector, b.capture!.vector), closeTo(1, 1e-9));
      expect(a.capture!.quality.toJson(), b.capture!.quality.toJson());
    });

    test('yuz topilmadi', () async {
      runner.detectorOutputs = synthYuNetOutputs(const []);
      final r = await engine.analyze(sharp, t);
      expect(r.reason, FaceReasons.noFace);
      expect(runner.recognizerCalls, 0, reason: 'behuda inference qilinmasin');
    });

    test('kadrda bir nechta odam', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 150, cy: 240, w: 150, h: 180),
        SynthFace(cx: 500, cy: 240, w: 150, h: 180),
      ]);
      final r = await engine.analyze(sharp, t);
      expect(r.reason, FaceReasons.manyFaces);
      expect(r.quality!.faces, 2);
      expect(runner.recognizerCalls, 0);
    });

    test('yuz juda kichik — "Yaqinroq keling"', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 60, h: 75),
      ]);
      final r = await engine.analyze(sharp, t);
      expect(r.reason, FaceReasons.tooFar);
      expect(runner.recognizerCalls, 0);
    });

    test('bir xil rangli (xira) rasm — "xira"', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final r = await engine.analyze(synthFlatPng(640, 480, 130), t);
      expect(r.reason, FaceReasons.blurry);
      expect(r.quality!.sharpness, lessThan(t.minSharpness));
    });

    test('qorong\'i rasm — "Yorug\'roq joyda oling"', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final r = await engine.analyze(synthSharpPng(640, 480, dark: 5, light: 30), t);
      expect(r.reason, FaceReasons.dark);
    });

    test('kuyib ketgan rasm — "Yorug\'lik juda kuchli"', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final r = await engine.analyze(synthSharpPng(640, 480, dark: 225, light: 250), t);
      expect(r.reason, FaceReasons.bright);
    });

    test('yuz burilgan — "to\'g\'ri qarating"', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(
          cx: 320,
          cy: 240,
          w: 220,
          h: 280,
          // Burun o'ng ko'zga juda yaqin → katta yaw.
          landmarks: [270, 210, 370, 210, 285, 255, 290, 300, 350, 300],
        ),
      ]);
      final r = await engine.analyze(sharp, t);
      expect(r.reason, FaceReasons.notFrontal);
      expect(r.quality!.yaw.abs(), greaterThan(t.maxYaw));
    });

    test('buzuq baytlar — "Rasmni o\'qib bo\'lmadi"', () async {
      final r = await engine.analyze(Uint8List.fromList([1, 2, 3, 4, 5]), t);
      expect(r.reason, FaceReasons.badImage);
      expect(runner.detectorCalls, 0);
    });

    test('bo\'sh baytlar ham qulatmaydi', () async {
      expect((await engine.analyze(Uint8List(0), t)).reason, FaceReasons.badImage);
    });

    test('model yuklanmasa — "Tekshiruv ishlamadi"', () async {
      runner.failLoad = true;
      final r = await engine.analyze(sharp, t);
      expect(r.reason, FaceReasons.engineFailed);
    });

    test('inference xatosi ISTISNO tashlamaydi, sabab qaytaradi', () async {
      runner.failDetector = true;
      final r = await engine.analyze(sharp, t);
      expect(r.reason, FaceReasons.engineFailed);
    });

    test('vektor uzunligi kutilmagan bo\'lsa rad etadi (jim o\'tkazmaydi)', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      runner.vectorLength = 64;
      final r = await engine.analyze(sharp, t);
      expect(r.reason, FaceReasons.engineFailed);
    });

    test('init IDEMPOTENT — bir necha analyze bitta load qiladi', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      await engine.analyze(sharp, t);
      await engine.analyze(sharp, t);
      expect(runner.loadCalls, 1);
    });

    test('dispose runnerni yopadi va qayta ishlatib bo\'lmaydi', () async {
      engine.dispose();
      expect(runner.closed, isTrue);
      expect(engine.init, throwsStateError);
    });

    test('KATTA rasm 640 gacha kichrayadi (koordinatalar mos qoladi)', () async {
      // 1280×960 → ishchi rasm 640×480, letterbox masshtabi 1.
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final r = await engine.analyze(synthSharpPng(1280, 960), t);
      expect(r.ok, isTrue, reason: r.reason);
      expect(r.capture!.quality.faceRatio, closeTo(220 / 640, 0.01));
    });

    test('KICHIK rasm letterbox bilan kattalashadi va nisbat saqlanadi', () async {
      // 320×240 → letterbox masshtabi 2, ya'ni 640 fazosidagi 220px yuz
      // ishchi rasmda 110px, kadr kengligi 320 → nisbat o'sha 0.34.
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final r = await engine.analyze(synthSharpPng(320, 240), t);
      expect(r.ok, isTrue, reason: r.reason);
      expect(r.capture!.quality.faceRatio, closeTo(220 / 640, 0.02));
    });

    test('isolate rejimida ham AYNI natija', () async {
      runner.detectorOutputs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 240, w: 220, h: 280),
      ]);
      final inline = await engine.analyze(sharp, t);

      final isolated = OnnxFaceEngine(runner: runner, useIsolate: true);
      final r = await isolated.analyze(sharp, t);
      isolated.dispose();

      expect(r.ok, isTrue, reason: r.reason);
      expect(r.capture!.quality.toJson(), inline.capture!.quality.toJson());
      expect(cosineSimilarity(r.capture!.vector, inline.capture!.vector), closeTo(1, 1e-9));
    });
  });

  group('bosqich funksiyalari (isolate ichida ishlaydiganlar)', () {
    test('prepareFaceInput buzuq baytda null', () {
      expect(prepareFaceInput(Uint8List.fromList([9, 9, 9])), isNull);
    });

    test('prepareFaceInput 640×640 tenzor beradi', () {
      final p = prepareFaceInput(synthSharpPng(800, 600))!;
      expect(p.input.length, 3 * 640 * 640);
      expect(p.width, 640);
      expect(p.height, 480);
      expect(p.scale, closeTo(1, 1e-9));
    });

    test('cropAndMeasure sifat + 112×112 tenzor + JPEG qaytaradi', () {
      final p = prepareFaceInput(synthSharpPng(640, 480))!;
      final c = cropAndMeasure(
        FaceCropRequest(
          rgb: p.rgb,
          width: p.width,
          height: p.height,
          x: 210,
          y: 100,
          w: 220,
          h: 280,
          landmarks: const [
            276, 172, 364, 172, //
            320, 254,
            287, 302,
            353, 302,
          ],
        ),
      );
      expect(c.alignedInput.length, 3 * 112 * 112);
      expect(c.quality.faces, 1);
      expect(c.quality.brightness, greaterThan(100));
      expect(c.quality.sharpness, greaterThan(50));
      expect(c.jpeg[0], 0xFF);
    });

    test('encodeFaceJpeg yuz atrofidan KENGROQ kesadi', () {
      final p = prepareFaceInput(synthSharpPng(640, 480))!;
      final work = _rgb(p);
      final tight = encodeFaceJpeg(work, 300, 200, 40, 40);
      final wide = encodeFaceJpeg(work, 100, 50, 400, 380);
      // Kengroq soha — kattaroq fayl.
      expect(wide.length, greaterThan(tight.length));
    });

    test('encodeFaceJpeg rasm chetidagi yuzda ham qulamaydi', () {
      final p = prepareFaceInput(synthSharpPng(640, 480))!;
      final jpeg = encodeFaceJpeg(_rgb(p), -30, -20, 100, 120);
      expect(jpeg.length, greaterThan(100));
    });
  });
}

/// `FacePrepared` dagi tekis baytlardan ishchi rasm.
RgbImage _rgb(FacePrepared p) => RgbImage(p.width, p.height, p.rgb);

// ---------------------------------------------------------------------------
// Soxta runner — model o'rniga determinilangan javob
// ---------------------------------------------------------------------------

class _ScriptedRunner implements OrtRunner {
  Map<String, Float32List> detectorOutputs = const {};
  int vectorLength = FaceModels.vectorLength;

  bool failLoad = false;
  bool failDetector = false;
  bool closed = false;

  int loadCalls = 0;
  int detectorCalls = 0;
  int recognizerCalls = 0;

  Float32List? lastDetectorInput;
  Float32List? lastRecognizerInput;

  @override
  Future<void> load() async {
    loadCalls++;
    if (failLoad) throw StateError('model topilmadi');
  }

  @override
  Future<Map<String, Float32List>> runDetector(Float32List input) async {
    detectorCalls++;
    lastDetectorInput = input;
    if (failDetector) throw StateError('inference xatosi');
    return detectorOutputs;
  }

  @override
  Future<Float32List> runRecognizer(Float32List input) async {
    recognizerCalls++;
    lastRecognizerInput = input;
    // Kirishdan DETERMINILANGAN vektor: bir xil kesim → bir xil vektor.
    final v = Float32List(vectorLength);
    for (var i = 0; i < input.length; i++) {
      v[i % vectorLength] += input[i];
    }
    return v;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
