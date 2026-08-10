import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/face/face_detector.dart';

import 'face_fixtures.dart';

/// YuNet dekodlash — model KERAK EMAS: chiqish tenzorlari sun'iy yig'iladi
/// (dekodlash formulasining teskarisi bilan), keyin dekodlangani solishtiriladi.
void main() {
  group('decodeYuNet', () {
    test('bo\'sh chiqishda yuz topilmaydi', () {
      expect(decodeYuNet(synthYuNetOutputs(const [])), isEmpty);
    });

    test('bitta yuz aynan berilgan joyda topiladi', () {
      final outs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 300, w: 200, h: 250),
      ]);
      final faces = decodeYuNet(outs);
      expect(faces.length, 1);
      final f = faces.first;
      expect(f.x, closeTo(320 - 100, 0.5));
      expect(f.y, closeTo(300 - 125, 0.5));
      expect(f.w, closeTo(200, 0.5));
      expect(f.h, closeTo(250, 0.5));
      expect(f.score, closeTo(0.99, 1e-5));
    });

    test('nuqtalar ham to\'g\'ri dekodlanadi', () {
      const face = SynthFace(cx: 320, cy: 300, w: 200, h: 250);
      final faces = decodeYuNet(synthYuNetOutputs(const [face]));
      final got = faces.first.landmarks;
      final want = face.points;
      for (var i = 0; i < 10; i++) {
        expect(got[i], closeTo(want[i], 0.5), reason: 'nuqta[$i]');
      }
    });

    test('har uch stride ishlaydi', () {
      for (final s in const [8, 16, 32]) {
        final faces = decodeYuNet(
          synthYuNetOutputs([SynthFace(cx: 200, cy: 200, w: 80, h: 100, stride: s)]),
        );
        expect(faces.length, 1, reason: 'stride $s');
        expect(faces.first.w, closeTo(80, 0.6), reason: 'stride $s');
      }
    });

    test('ball chegarasidan past yuz tashlanadi', () {
      final outs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 300, score: 0.5),
      ]);
      expect(decodeYuNet(outs, scoreThreshold: 0.7), isEmpty);
      expect(decodeYuNet(outs, scoreThreshold: 0.4).length, 1);
    });

    test('ikki alohida yuz — ikkalasi ham qoladi', () {
      final outs = synthYuNetOutputs(const [
        SynthFace(cx: 150, cy: 200, w: 120, h: 150),
        SynthFace(cx: 480, cy: 200, w: 120, h: 150),
      ]);
      expect(decodeYuNet(outs).length, 2);
    });

    test('ustma-ust tushgan takrorlar NMS bilan bittaga tushadi', () {
      // Bir xil yuz uch xil stride'da — model amalda shunday qiladi.
      final outs = synthYuNetOutputs(const [
        SynthFace(cx: 320, cy: 300, w: 200, h: 250, stride: 8, score: 0.9),
        SynthFace(cx: 322, cy: 302, w: 202, h: 252, stride: 16, score: 0.95),
        SynthFace(cx: 318, cy: 298, w: 198, h: 248, stride: 32, score: 0.99),
      ]);
      final faces = decodeYuNet(outs);
      expect(faces.length, 1);
      // Eng baland balli qoladi.
      expect(faces.first.score, closeTo(0.99, 1e-5));
    });

    test('natija ball bo\'yicha kamayish tartibida', () {
      final outs = synthYuNetOutputs(const [
        SynthFace(cx: 120, cy: 150, w: 100, h: 120, score: 0.8),
        SynthFace(cx: 500, cy: 150, w: 100, h: 120, score: 0.95),
      ]);
      final faces = decodeYuNet(outs, scoreThreshold: 0.5);
      expect(faces.length, 2);
      expect(faces.first.score, greaterThan(faces.last.score));
    });

    test('topK ro\'yxatni cheklaydi', () {
      final outs = synthYuNetOutputs(const [
        SynthFace(cx: 100, cy: 100, w: 80, h: 80, score: 0.99),
        SynthFace(cx: 300, cy: 100, w: 80, h: 80, score: 0.95),
        SynthFace(cx: 500, cy: 100, w: 80, h: 80, score: 0.90),
      ]);
      expect(decodeYuNet(outs, scoreThreshold: 0.5, topK: 2).length, 2);
    });

    test('chiqish yetishmasa o\'sha stride tashlanadi, qulamaydi', () {
      final outs = synthYuNetOutputs(const [SynthFace(cx: 320, cy: 300)]);
      outs.remove('kps_32');
      expect(decodeYuNet(outs), isEmpty);
    });

    test('kalta (buzuq) tenzor ham qulatmaydi', () {
      final outs = synthYuNetOutputs(const [SynthFace(cx: 320, cy: 300)]);
      outs['bbox_32'] = Float32List(4);
      expect(() => decodeYuNet(outs), returnsNormally);
    });

    test('cls/obj 0..1 dan tashqarida bo\'lsa ham ball NaN bo\'lmaydi', () {
      final outs = synthYuNetOutputs(const []);
      outs['cls_32']![0] = 5;
      outs['obj_32']![0] = -3;
      final faces = decodeYuNet(outs, scoreThreshold: 0);
      expect(faces.every((f) => !f.score.isNaN), isTrue);
    });
  });

  group('iou', () {
    FaceBox box(double x, double y, double w, double h) =>
        FaceBox(x: x, y: y, w: w, h: h, score: 1, landmarks: List.filled(10, 0));

    test('bir xil ramka → 1', () {
      expect(iou(box(0, 0, 10, 10), box(0, 0, 10, 10)), closeTo(1, 1e-9));
    });

    test('kesishmaydigan ramkalar → 0', () {
      expect(iou(box(0, 0, 10, 10), box(50, 50, 10, 10)), 0);
    });

    test('yarim ustma-ust', () {
      // 10×10 va 10×10, 5 piksel siljigan: kesishuv 50, birlashma 150.
      expect(iou(box(0, 0, 10, 10), box(5, 0, 10, 10)), closeTo(1 / 3, 1e-9));
    });

    test('nol o\'lchamli ramka → 0', () {
      expect(iou(box(0, 0, 0, 0), box(0, 0, 10, 10)), 0);
    });
  });

  group('nonMaxSuppression', () {
    FaceBox box(double x, double score) =>
        FaceBox(x: x, y: 0, w: 10, h: 10, score: score, landmarks: List.filled(10, 0));

    test('bo\'sh ro\'yxat', () {
      expect(nonMaxSuppression(const [], 0.3, 10), isEmpty);
    });

    test('kirish ro\'yxati O\'ZGARMAYDI', () {
      final input = [box(0, 0.5), box(100, 0.9)];
      nonMaxSuppression(input, 0.3, 10);
      expect(input.first.score, 0.5);
    });

    test('chegara 1 bo\'lsa hech nima tashlanmaydi', () {
      expect(nonMaxSuppression([box(0, 0.9), box(0, 0.8)], 1.0, 10).length, 2);
    });
  });

  group('FaceBox', () {
    test('scaled hamma koordinatani ko\'paytiradi, ballni tegmaydi', () {
      final f = FaceBox(
        x: 10,
        y: 20,
        w: 30,
        h: 40,
        score: 0.9,
        landmarks: List.generate(10, (i) => i.toDouble()),
      );
      final s = f.scaled(2);
      expect(s.x, 20);
      expect(s.h, 80);
      expect(s.landmarks[3], 6);
      expect(s.score, 0.9);
    });

    test('exp/log borib-kelishi — o\'lcham buzilmaydi', () {
      // Dekodlashda `w = exp(bbox)·stride`; fixture teskarisini yozadi.
      const w = 137.0;
      expect(math.exp(math.log(w / 32)) * 32, closeTo(w, 1e-9));
    });
  });
}
