import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/face/face_math.dart';

/// SOF matematika testlari — model fayli KERAK EMAS.
///
/// "Golden" qiymatlar OpenCV/numpy'dagi bir xil implementatsiyadan olingan
/// (`getSimilarityTransformMatrix` porti OpenCV chiqargan 112×112 kesim bilan
/// piksel-bapiksel solishtirildi, max farq 1).
void main() {
  group('meanBrightness', () {
    test('bo\'sh tasvirda 0', () {
      expect(meanBrightness(GrayImage.empty()), 0);
    });

    test('bir xil rangda o\'sha qiymat', () {
      final img = GrayImage(4, 4, Uint8List.fromList(List.filled(16, 200)));
      expect(meanBrightness(img), 200);
    });

    test('aralash qiymatlarning o\'rtachasi', () {
      final img = GrayImage(2, 2, Uint8List.fromList([0, 100, 200, 255]));
      expect(meanBrightness(img), closeTo(138.75, 1e-9));
    });

    test('determinilangan gradient — numpy bilan bir xil', () {
      expect(meanBrightness(_gradient(32, 32)), closeTo(126.4072265625, 1e-9));
    });
  });

  group('laplacianVariance', () {
    test('3×3 dan kichik tasvirda 0', () {
      expect(laplacianVariance(GrayImage(2, 2, Uint8List(4))), 0);
      expect(laplacianVariance(GrayImage.empty()), 0);
    });

    test('tekis tasvirda 0 — o\'zgarish yo\'q', () {
      final flat = GrayImage(8, 8, Uint8List.fromList(List.filled(64, 128)));
      expect(laplacianVariance(flat), 0);
    });

    test('chiziqli gradient ham 0 beradi (Laplas ikkinchi tartibli)', () {
      final px = Uint8List(8 * 8);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          px[y * 8 + x] = (x * 10).clamp(0, 255);
        }
      }
      expect(laplacianVariance(GrayImage(8, 8, px)), closeTo(0, 1e-9));
    });

    test('shovqinli tasvir tekisdan ANCHA katta', () {
      final flat = GrayImage(32, 32, Uint8List.fromList(List.filled(1024, 128)));
      final noisy = _checker(32, 32, 1, 60, 190);
      expect(laplacianVariance(noisy), greaterThan(1000));
      expect(laplacianVariance(noisy), greaterThan(laplacianVariance(flat)));
    });

    test('determinilangan gradient — numpy bilan bir xil (golden)', () {
      expect(laplacianVariance(_gradient(32, 32)), closeTo(16659.9533284, 1e-4));
    });
  });

  group('l2Normalize', () {
    test('uzunligi 1 ga tushadi', () {
      final v = Float32List.fromList([3, 4]);
      final n = l2Normalize(v);
      expect(n[0], closeTo(0.6, 1e-6));
      expect(n[1], closeTo(0.8, 1e-6));
      expect(math.sqrt(n[0] * n[0] + n[1] * n[1]), closeTo(1, 1e-6));
    });

    test('KIRISH o\'zgarmaydi (yangi ro\'yxat qaytadi)', () {
      final v = Float32List.fromList([3, 4]);
      l2Normalize(v);
      expect(v[0], 3);
      expect(v[1], 4);
    });

    test('nol vektor NaN bermaydi', () {
      final n = l2Normalize(Float32List(8));
      expect(n.every((e) => e == 0), isTrue);
    });

    test('allaqachon normallashgan vektor o\'zgarmaydi', () {
      final v = l2Normalize(Float32List.fromList([1, 2, 3, 4]));
      final again = l2Normalize(v);
      for (var i = 0; i < v.length; i++) {
        expect(again[i], closeTo(v[i], 1e-6));
      }
    });
  });

  group('cosineSimilarity', () {
    test('bir xil vektor → 1', () {
      final v = l2Normalize(Float32List.fromList([1, 2, 3]));
      expect(cosineSimilarity(v, v), closeTo(1, 1e-6));
    });

    test('teskari vektor → -1', () {
      final a = Float32List.fromList([1, 0]);
      final b = Float32List.fromList([-1, 0]);
      expect(cosineSimilarity(a, b), closeTo(-1, 1e-6));
    });

    test('ortogonal → 0', () {
      expect(
        cosineSimilarity(Float32List.fromList([1, 0]), Float32List.fromList([0, 5])),
        closeTo(0, 1e-6),
      );
    });

    test('uzunlik farq qilsa xato', () {
      expect(
        () => cosineSimilarity(Float32List(3), Float32List(4)),
        throwsArgumentError,
      );
    });

    test('nol vektor bilan 0 (NaN emas)', () {
      expect(cosineSimilarity(Float32List(3), Float32List.fromList([1, 2, 3])), 0);
    });
  });

  group('vektor ↔ baytlar', () {
    test('borib-kelish qiymatni saqlaydi', () {
      final v = l2Normalize(Float32List.fromList([1, -2, 3.5, 0, 42]));
      final back = vectorFromBytes(vectorToBytes(v));
      expect(back.length, v.length);
      for (var i = 0; i < v.length; i++) {
        expect(back[i], v[i]);
      }
    });

    test('bayt uzunligi 4× vektor', () {
      expect(vectorToBytes(Float32List(128)).length, 512);
    });

    test('base64 borib-kelishi', () {
      final v = l2Normalize(Float32List.fromList(List.generate(128, (i) => i - 64.0)));
      final back = vectorFromBase64(vectorToBase64(v));
      for (var i = 0; i < v.length; i++) {
        expect(back[i], v[i]);
      }
    });

    test('4 ga bo\'linmaydigan bayt — xato', () {
      expect(() => vectorFromBytes(Uint8List(7)), throwsArgumentError);
    });

    test('little-endian tartibi qotirilgan (server ham shunday o\'qiydi)', () {
      // 1.0f = 0x3F800000 → little-endian: 00 00 80 3F
      final b = vectorToBytes(Float32List.fromList([1.0]));
      expect(b, [0x00, 0x00, 0x80, 0x3F]);
    });
  });

  group('Mat2x3', () {
    test('identity nuqtani o\'zgartirmaydi', () {
      expect(Mat2x3.identity.mapX(3, 7), 3);
      expect(Mat2x3.identity.mapY(3, 7), 7);
    });

    test('teskari matritsa nuqtani qaytaradi', () {
      const m = Mat2x3(2, 0, 10, 0, 2, -5);
      final inv = m.invert()!;
      final x = m.mapX(7, 9), y = m.mapY(7, 9);
      expect(inv.mapX(x, y), closeTo(7, 1e-9));
      expect(inv.mapY(x, y), closeTo(9, 1e-9));
    });

    test('buzilgan (determinant 0) matritsa teskarilanmaydi', () {
      expect(const Mat2x3(1, 2, 0, 2, 4, 0).invert(), isNull);
    });
  });

  group('svd2x2', () {
    test('A = U · diag(s) · Vᵀ qayta yig\'iladi', () {
      for (final a in [
        [3.0, 1.0, 1.0, 2.0],
        [0.0, -4.0, 5.0, 0.0],
        [1.0, 0.0, 0.0, 1.0],
        [-2.0, 7.0, 3.0, -1.0],
      ]) {
        final r = svd2x2(a[0], a[1], a[2], a[3]);
        final m = _mul(r.u, _mul([r.s[0], 0, 0, r.s[1]], r.vt));
        for (var i = 0; i < 4; i++) {
          expect(m[i], closeTo(a[i], 1e-9), reason: 'A=$a');
        }
        expect(r.s[0], greaterThanOrEqualTo(r.s[1]));
        expect(r.s[1], greaterThanOrEqualTo(0));
      }
    });
  });

  group('similarityTransform (yuzni tekislash)', () {
    // Golden: OpenCV `getSimilarityTransformMatrix` ning numpy portidan,
    // haqiqiy YuNet nuqtalari bilan (lena.jpg).
    const lena = [
      273.9, 266.6, //
      334.0, 273.7,
      315.7, 314.2,
      272.4, 340.9,
      317.6, 347.0,
    ];

    test('golden matritsa (OpenCV bilan bir xil)', () {
      final m = similarityTransform(lena);
      expect(m.a, closeTo(0.5453090052, 1e-8));
      expect(m.b, closeTo(0.0701902431, 1e-8));
      expect(m.c, closeTo(-130.7020282363, 1e-6));
      expect(m.d, closeTo(-0.0701902431, 1e-8));
      expect(m.e, closeTo(0.5453090052, 1e-8));
      expect(m.f, closeTo(-75.0681315307, 1e-6));
    });

    test('nuqtalar 112×112 shabloni ATROFIGA tushadi', () {
      final m = similarityTransform(lena);
      const expected = [
        37.370827, 51.086142, //
        70.642249, 50.739402,
        63.505799, 74.108898,
        41.767999, 91.707886,
        66.844126, 91.861672,
      ];
      for (var i = 0; i < 5; i++) {
        expect(m.mapX(lena[i * 2], lena[i * 2 + 1]), closeTo(expected[i * 2], 1e-4));
        expect(
          m.mapY(lena[i * 2], lena[i * 2 + 1]),
          closeTo(expected[i * 2 + 1], 1e-4),
        );
      }
    });

    test('ikkinchi golden — simmetrik "yuz"', () {
      final m = similarityTransform(const [
        0.0, 0.0, //
        100.0, 0.0,
        50.0, 50.0,
        10.0, 100.0,
        90.0, 100.0,
      ]);
      expect(m.a, closeTo(0.3844878571, 1e-8));
      expect(m.b, closeTo(0.0021341209, 1e-8));
      expect(m.c, closeTo(36.6951010989, 1e-6));
      expect(m.d, closeTo(-0.0021341209, 1e-8));
      expect(m.e, closeTo(0.3844878571, 1e-8));
      expect(m.f, closeTo(52.7831131868, 1e-6));
    });

    test('shablonning O\'ZI berilsa — deyarli birlik almashtirish', () {
      final m = similarityTransform(kSfaceRefPoints);
      for (var i = 0; i < 5; i++) {
        final x = kSfaceRefPoints[i * 2], y = kSfaceRefPoints[i * 2 + 1];
        expect(m.mapX(x, y), closeTo(x, 1e-3));
        expect(m.mapY(x, y), closeTo(y, 1e-3));
      }
    });

    test('masshtab: nuqtalar 2× katta bo\'lsa matritsa 2× kichik', () {
      final m1 = similarityTransform(lena);
      final m2 = similarityTransform([for (final v in lena) v * 2]);
      expect(m2.a, closeTo(m1.a / 2, 1e-8));
      expect(m2.e, closeTo(m1.e / 2, 1e-8));
    });

    test('nuqtalar soni noto\'g\'ri bo\'lsa xato', () {
      expect(() => similarityTransform(const [1, 2, 3]), throwsArgumentError);
    });
  });

  group('headPose', () {
    // Frontal "yuz": ko'zlar gorizontal, burun ko'zlar orasida.
    List<double> face({
      double rex = 40,
      double rey = 50,
      double lex = 80,
      double ley = 50,
      double nx = 60,
      double ny = 70,
    }) => [rex, rey, lex, ley, nx, ny, 45, 90, 75, 90];

    test('frontal yuz → yaw va roll ~0', () {
      final p = headPose(face());
      expect(p.yaw.abs(), lessThan(0.5));
      expect(p.roll.abs(), lessThan(0.5));
    });

    test('boshni qiyshaytirish rollni oshiradi', () {
      final p = headPose(face(rey: 40, ley: 60)); // chap ko'z pastroq
      expect(p.roll, greaterThan(20));
    });

    test('teskari qiyshayish — teskari belgi', () {
      final p = headPose(face(rey: 60, ley: 40));
      expect(p.roll, lessThan(-20));
    });

    test('burun kadrda chapga siljisa yaw musbat, o\'ngga siljisa manfiy', () {
      expect(headPose(face(nx: 48)).yaw, greaterThan(10));
      expect(headPose(face(nx: 72)).yaw, lessThan(-10));
    });

    test('yaw ±90 dan chiqmaydi (burun ko\'zdan tashqarida bo\'lsa ham)', () {
      expect(headPose(face(nx: -500)).yaw, closeTo(90, 1e-6));
      expect(headPose(face(nx: 900)).yaw, closeTo(-90, 1e-6));
    });

    test('ko\'zlar ustma-ust tushsa 0 (bo\'lishda NaN chiqmasin)', () {
      final p = headPose(face(lex: 40, ley: 50));
      expect(p.yaw, 0);
      expect(p.roll, 0);
    });

    test('nuqtalar soni noto\'g\'ri bo\'lsa xato', () {
      expect(() => headPose(const [1, 2]), throwsArgumentError);
    });
  });
}

// ---------------------------------------------------------------------------
// Yordamchilar — test rasmlari KOD bilan yaratiladi (repoga fayl qo'shilmaydi)
// ---------------------------------------------------------------------------

GrayImage _gradient(int w, int h) {
  final px = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      px[y * w + x] = (x * 7 + y * 13) % 251;
    }
  }
  return GrayImage(w, h, px);
}

GrayImage _checker(int w, int h, int cell, int a, int b) {
  final px = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      px[y * w + x] = ((x ~/ cell + y ~/ cell) % 2 == 0) ? a : b;
    }
  }
  return GrayImage(w, h, px);
}

List<double> _mul(List<double> a, List<double> b) => [
  a[0] * b[0] + a[1] * b[2],
  a[0] * b[1] + a[1] * b[3],
  a[2] * b[0] + a[3] * b[2],
  a[2] * b[1] + a[3] * b[3],
];
