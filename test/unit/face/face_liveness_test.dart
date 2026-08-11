// Tiriklik qoidalari — SOF mantiq (kamera ham, tarmoq ham kerak emas).
//
// Bu yerdagi chegaralar SERVERDAGI `FaceLiveness.Check` bilan bir xil ma'noda
// bo'lishi shart, shuning uchun har bir qoida alohida tekshiriladi.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/face/face_engine.dart';
import 'package:student/services/face_liveness.dart';

FaceQuality _q({double yaw = 0, double ratio = 0.3}) => FaceQuality(
      faces: 1,
      faceRatio: ratio,
      sharpness: 300,
      brightness: 130,
      yaw: yaw,
      roll: 0,
    );

void main() {
  group('measure', () {
    test('burilishda yaw, masofada faceRatio o\'lchanadi', () {
      final q = _q(yaw: -20, ratio: 0.42);
      expect(Liveness.measure(Liveness.turnLeft, q), -20);
      expect(Liveness.measure(Liveness.turnRight, q), -20);
      expect(Liveness.measure(Liveness.moveCloser, q), 0.42);
      expect(Liveness.measure(Liveness.moveBack, q), 0.42);
    });
  });

  group('done — mijoz chegaralari', () {
    test('chapga burilish MANFIY yaw (server bilan bir xil ishora)', () {
      expect(Liveness.done(Liveness.turnLeft, -20, 0.3), isTrue);
      expect(Liveness.done(Liveness.turnLeft, -10, 0.3), isFalse);
      // O'ngga burilgan odam "chapga" ni bajargan bo'lib qolmasin.
      expect(Liveness.done(Liveness.turnLeft, 30, 0.3), isFalse);
    });

    test('o\'ngga burilish MUSBAT yaw', () {
      expect(Liveness.done(Liveness.turnRight, 20, 0.3), isTrue);
      expect(Liveness.done(Liveness.turnRight, -30, 0.3), isFalse);
    });

    test('masofa — boshlang\'ich nisbatga qarab', () {
      expect(Liveness.done(Liveness.moveCloser, 0.45, 0.3), isTrue); // 1.5x
      // 1.27x — server (1.25) o'tkazardi, mijoz (1.30) esa ZAXIRA qoldiradi.
      expect(Liveness.done(Liveness.moveCloser, 0.38, 0.3), isFalse);
      expect(Liveness.serverAccepts(Liveness.moveCloser, 0.38, 0.3), isTrue);
      expect(Liveness.done(Liveness.moveBack, 0.19, 0.3), isTrue); // 0.63x
      expect(Liveness.done(Liveness.moveBack, 0.25, 0.3), isFalse);
    });

    test('boshlang\'ich nisbat 0 bo\'lsa masofa hech qachon bajarilmaydi', () {
      expect(Liveness.done(Liveness.moveCloser, 0.9, 0), isFalse);
      expect(Liveness.done(Liveness.moveBack, 0.01, 0), isFalse);
    });

    test('NaN/cheksiz qiymat qabul qilinmaydi', () {
      expect(Liveness.done(Liveness.turnLeft, double.nan, 0.3), isFalse);
      expect(Liveness.done(Liveness.moveCloser, double.infinity, 0.3), isFalse);
    });

    test('notanish harakat — bajarilgan deb belgilanmaydi', () {
      expect(Liveness.done('blink', -90, 0.3), isFalse);
    });

    test('boshlang\'ich JUDA yaqin bo\'lsa qabul qilinmaydi', () {
      expect(Liveness.baselineOk(0.30), isTrue);
      expect(Liveness.baselineOk(Liveness.maxBaselineFaceRatio), isTrue);
      // 0.60 × 1.30 = 0.78 — yuz kadr kengligining 78% i, jismonan imkonsiz.
      expect(Liveness.baselineOk(0.60), isFalse);
      expect(Liveness.baselineOk(0), isFalse);
      expect(Liveness.baselineOk(double.nan), isFalse);
    });

    test('ruxsat etilgan boshlang\'ichda «yaqinlashish» ERISHSA bo\'ladi', () {
      // Chegaradagi eng yomon holat ham detektor topa oladigan oraliqda qolsin:
      // aks holda foydalanuvchi shu bosqichda qotib qolardi.
      final target = Liveness.maxBaselineFaceRatio * Liveness.closerFactor;
      expect(target, lessThan(0.7));
      expect(Liveness.done(Liveness.moveCloser, target, Liveness.maxBaselineFaceRatio),
          isTrue);
    });

    test('mijoz chegarasi serverdan QATTIQROQ', () {
      expect(Liveness.minTurnDegrees, greaterThan(Liveness.serverMinTurnDegrees));
      expect(Liveness.closerFactor, greaterThan(Liveness.serverCloserFactor));
      expect(Liveness.backFactor, lessThan(Liveness.serverBackFactor));
    });
  });

  group('finalFrameOk', () {
    final steps = [
      const LivenessStep(action: Liveness.turnLeft, ok: true, ms: 900, value: -25),
      const LivenessStep(action: Liveness.moveCloser, ok: true, ms: 800, value: 0.45),
    ];

    test('yakuniy kadr juda yaqin bo\'lsa — yuborilmaydi', () {
      // 0.45 >= 0.42 * 1.25 = 0.525 ✗ — server rad etardi.
      expect(Liveness.finalFrameOk(steps, 0.42), isFalse);
    });

    test('odatdagi masofada — mos', () {
      // 0.45 >= 0.30 * 1.25 = 0.375 ✓
      expect(Liveness.finalFrameOk(steps, 0.30), isTrue);
    });

    test('uzoqlashish harakati ham yakuniy kadrga nisbatan tekshiriladi', () {
      final back = [
        const LivenessStep(action: Liveness.moveBack, ok: true, ms: 700, value: 0.18),
      ];
      expect(Liveness.finalFrameOk(back, 0.30), isTrue); // 0.18 <= 0.24 ✓
      expect(Liveness.finalFrameOk(back, 0.20), isFalse); // 0.18 <= 0.16 ✗
    });

    test('faqat burilish bo\'lsa masofa tekshirilmaydi', () {
      final turns = [
        const LivenessStep(action: Liveness.turnLeft, ok: true, ms: 900, value: -25),
        const LivenessStep(action: Liveness.turnRight, ok: true, ms: 900, value: 25),
      ];
      expect(Liveness.finalFrameOk(turns, 0.3), isTrue);
    });

    test('yaroqsiz faceRatio — yuborilmaydi', () {
      expect(Liveness.finalFrameOk(steps, 0), isFalse);
      expect(Liveness.finalFrameOk(steps, double.nan), isFalse);
    });
  });

  group('JSON', () {
    test('massiv, TARTIB saqlanadi, ms va value SON bo\'lib chiqadi', () {
      final json = Liveness.toJsonString([
        const LivenessStep(action: Liveness.moveBack, ok: true, ms: 1400, value: 0.18),
        const LivenessStep(action: Liveness.turnLeft, ok: true, ms: 900, value: -27.512345),
      ]);
      final list = jsonDecode(json) as List;
      expect(list, hasLength(2));

      final first = list.first as Map<String, dynamic>;
      expect(first['action'], 'move_back');
      expect(first['ok'], isTrue);
      // ⚠️ Server `ms`/`value` ni FAQAT JSON Number sifatida qabul qiladi —
      // satr bo'lsa tiriklik tekshiruvi yiqiladi.
      expect(first['ms'], isA<num>());
      expect(first['value'], isA<num>());

      final second = list[1] as Map<String, dynamic>;
      expect(second['action'], 'turn_left');
      expect(second['value'], -27.5123); // yaxlitlangan
    });

    test('cheksiz qiymat JSON ni buzmaydi', () {
      final json = Liveness.toJsonString([
        const LivenessStep(action: Liveness.turnLeft, ok: true, ms: 500, value: double.nan),
      ]);
      expect((jsonDecode(json) as List).first['value'], 0);
    });
  });

  group('yorliqlar', () {
    test('har bir harakat uchun ko\'rsatma bor', () {
      for (final a in Liveness.all) {
        expect(Liveness.label(a), isNotEmpty);
        expect(Liveness.label(a), isNot("Ko'rsatmani bajaring"));
      }
    });

    test('serverdagi ro\'yxat bilan bir xil kalitlar', () {
      expect(Liveness.all, ['turn_left', 'turn_right', 'move_closer', 'move_back']);
    });
  });
}
