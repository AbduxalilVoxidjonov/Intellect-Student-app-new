import 'package:flutter_test/flutter_test.dart';
import 'package:student/face/face_reasons.dart';
import 'package:student/face/face_types.dart';

/// Sifat darvozasi va serverdan keladigan chegaralar.
void main() {
  const good = FaceQuality(
    faces: 1,
    faceRatio: 0.40,
    sharpness: 200,
    brightness: 130,
    yaw: 3,
    roll: 2,
  );
  const t = FaceThresholds.fallback;

  group('FaceQuality.toJson', () {
    test('barcha kalitlar bor (server shu nomlarni kutadi)', () {
      final j = good.toJson();
      expect(j.keys.toSet(), {
        'faces',
        'faceRatio',
        'sharpness',
        'brightness',
        'yaw',
        'roll',
      });
    });

    test('sonlar yaxlitlanadi — uzun dumlar ketadi', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.27700001001358032,
        sharpness: 533.21567,
        brightness: 128.74999,
        yaw: -23.456789,
        roll: 6.7891,
      );
      final j = q.toJson();
      expect(j['faceRatio'], 0.277);
      expect(j['sharpness'], 533.22);
      expect(j['brightness'], 128.75);
      expect(j['yaw'], -23.46);
      expect(j['roll'], 6.79);
    });

    test('chekli bo\'lmagan qiymat 0 ga aylanadi (JSON buzilmasin)', () {
      final j = FaceQuality(
        faces: 1,
        faceRatio: double.nan,
        sharpness: double.infinity,
        brightness: 100,
        yaw: 0,
        roll: 0,
      ).toJson();
      expect(j['faceRatio'], 0);
      expect(j['sharpness'], 0);
    });

    test('faces butun son bo\'lib qoladi', () {
      expect(good.toJson()['faces'], isA<int>());
    });

    test('copyWithFaces faqat sonini almashtiradi', () {
      final q = good.copyWithFaces(3);
      expect(q.faces, 3);
      expect(q.brightness, good.brightness);
    });
  });

  group('FaceThresholds.fromJson', () {
    test('to\'liq JSON o\'qiladi', () {
      final th = FaceThresholds.fromJson(const {
        'minSharpness': 10,
        'minBrightness': 20,
        'maxBrightness': 230,
        'minFaceRatio': 0.2,
        'maxYaw': 15,
        'maxRoll': 12,
      });
      expect(th.minSharpness, 10);
      expect(th.maxBrightness, 230);
      expect(th.minFaceRatio, 0.2);
      expect(th.maxRoll, 12);
    });

    test('null JSON — hammasi fallback', () {
      final th = FaceThresholds.fromJson(null);
      expect(th.minSharpness, t.minSharpness);
      expect(th.maxYaw, t.maxYaw);
    });

    test('bo\'sh JSON — hammasi fallback', () {
      expect(FaceThresholds.fromJson(const {}).minBrightness, t.minBrightness);
    });

    test('yetishmagan maydon FAQAT o\'zi fallback bo\'ladi', () {
      final th = FaceThresholds.fromJson(const {'minSharpness': 99});
      expect(th.minSharpness, 99);
      expect(th.minBrightness, t.minBrightness);
    });

    test('xato tur (matn, ro\'yxat, null) fallbackka tushadi', () {
      final th = FaceThresholds.fromJson(const {
        'minSharpness': 'salom',
        'minBrightness': [1, 2],
        'maxBrightness': null,
        'minFaceRatio': true,
      });
      expect(th.minSharpness, t.minSharpness);
      expect(th.minBrightness, t.minBrightness);
      expect(th.maxBrightness, t.maxBrightness);
      expect(th.minFaceRatio, t.minFaceRatio);
    });

    test('son bo\'lgan MATN o\'qiladi (server satr yuborsa ham ishlasin)', () {
      expect(FaceThresholds.fromJson(const {'maxYaw': '17.5'}).maxYaw, 17.5);
      expect(FaceThresholds.fromJson(const {'maxYaw': ' 18 '}).maxYaw, 18);
    });

    test('NaN/Infinity fallbackka tushadi', () {
      final th = FaceThresholds.fromJson({
        'minSharpness': double.nan,
        'maxRoll': double.infinity,
      });
      expect(th.minSharpness, t.minSharpness);
      expect(th.maxRoll, t.maxRoll);
    });

    test('toJson → fromJson borib-kelishi', () {
      final back = FaceThresholds.fromJson(t.toJson());
      expect(back.minSharpness, t.minSharpness);
      expect(back.minFaceRatio, t.minFaceRatio);
      expect(back.maxRoll, t.maxRoll);
    });
  });

  group('faceQualityReason — har chegara uchun alohida', () {
    test('yaxshi selfi — sabab yo\'q', () {
      expect(faceQualityReason(good, t), isNull);
    });

    test('yuz yo\'q', () {
      expect(faceQualityReason(FaceQuality.none, t), FaceReasons.noFace);
    });

    test('bir nechta yuz', () {
      expect(faceQualityReason(good.copyWithFaces(2), t), FaceReasons.manyFaces);
    });

    test('juda uzoq', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.05,
        sharpness: 200,
        brightness: 130,
        yaw: 0,
        roll: 0,
      );
      expect(faceQualityReason(q, t), FaceReasons.tooFar);
    });

    test('qorong\'i', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.4,
        sharpness: 200,
        brightness: 20,
        yaw: 0,
        roll: 0,
      );
      expect(faceQualityReason(q, t), FaceReasons.dark);
    });

    test('juda yorug\'', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.4,
        sharpness: 200,
        brightness: 250,
        yaw: 0,
        roll: 0,
      );
      expect(faceQualityReason(q, t), FaceReasons.bright);
    });

    test('xira', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.4,
        sharpness: 5,
        brightness: 130,
        yaw: 0,
        roll: 0,
      );
      expect(faceQualityReason(q, t), FaceReasons.blurry);
    });

    test('burilgan (yaw)', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.4,
        sharpness: 200,
        brightness: 130,
        yaw: -40,
        roll: 0,
      );
      expect(faceQualityReason(q, t), FaceReasons.notFrontal);
    });

    test('qiyshaygan (roll)', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.4,
        sharpness: 200,
        brightness: 130,
        yaw: 0,
        roll: 35,
      );
      expect(faceQualityReason(q, t), FaceReasons.notFrontal);
    });

    test('QORONG\'I kadr "xira" emas, "yorug\'roq" deydi — tartib shu uchun', () {
      // Qorong'ida kontrast tushib, Laplas dispersiyasi ham pastga tushadi:
      // ikkala chegara birdan buzilsa foydalanuvchi CHIROQNI yoqishi kerak.
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.4,
        sharpness: 10,
        brightness: 25,
        yaw: 0,
        roll: 0,
      );
      expect(faceQualityReason(q, t), FaceReasons.dark);
    });

    test('yuz soni masofadan MUHIMROQ (tartib buzilmasin)', () {
      const q = FaceQuality(
        faces: 2,
        faceRatio: 0.01,
        sharpness: 0,
        brightness: 0,
        yaw: 90,
        roll: 90,
      );
      expect(faceQualityReason(q, t), FaceReasons.manyFaces);
    });

    test('chegaraning O\'ZIDA o\'tadi (qat\'iy taqqoslash)', () {
      const q = FaceQuality(
        faces: 1,
        faceRatio: 0.15,
        sharpness: 40,
        brightness: 55,
        yaw: 25,
        roll: 20,
      );
      expect(faceQualityReason(q, t), isNull);
    });

    test('server chegarasi qattiqroq bo\'lsa rad etadi', () {
      const strict = FaceThresholds(
        minSharpness: 1000,
        minBrightness: 0,
        maxBrightness: 255,
        minFaceRatio: 0,
        maxYaw: 90,
        maxRoll: 90,
      );
      expect(faceQualityReason(good, strict), FaceReasons.blurry);
    });
  });

  group('FaceResult', () {
    test('fail — ok false, sabab bor', () {
      final r = FaceResult.fail(FaceReasons.noFace, FaceQuality.none);
      expect(r.ok, isFalse);
      expect(r.capture, isNull);
      expect(r.reason, FaceReasons.noFace);
      expect(r.quality, isNotNull);
    });

    test('sabablar ro\'yxati takrorlanmaydi (server bilan solishtiriladi)', () {
      expect(FaceReasons.all.toSet().length, FaceReasons.all.length);
      expect(FaceReasons.all.every((s) => s.trim().isNotEmpty), isTrue);
    });
  });
}
