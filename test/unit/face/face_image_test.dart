import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/face/face_image.dart';
import 'package:student/face/face_math.dart';

/// Rasm amallari — model fayli KERAK EMAS, barcha rasm kod bilan yaratiladi.
void main() {
  group('resizeRgb', () {
    test('bir xil rangli rasm o\'lchamdan qat\'i nazar bir xil qoladi', () {
      final src = _solid(8, 8, 10, 20, 30);
      final out = resizeRgb(src, 3, 5);
      expect(out.width, 3);
      expect(out.height, 5);
      for (var i = 0; i < out.bytes.length; i += 3) {
        expect(out.bytes[i], 10);
        expect(out.bytes[i + 1], 20);
        expect(out.bytes[i + 2], 30);
      }
    });

    test('nol o\'lchamda bo\'sh rasm', () {
      expect(resizeRgb(_solid(4, 4, 1, 1, 1), 0, 5).isEmpty, isTrue);
      expect(resizeRgb(RgbImage.empty(), 5, 5).isEmpty, isTrue);
    });

    test('2× kattalashtirishda chekka piksellar saqlanadi', () {
      final src = RgbImage(
        2,
        1,
        Uint8List.fromList([0, 0, 0, 255, 255, 255]),
      );
      final out = resizeRgb(src, 4, 1);
      expect(out.bytes[0], 0); // chap chekka — qora
      expect(out.bytes[9], 255); // o'ng chekka — oq
    });
  });

  group('fitWithin', () {
    test('kichik rasm KATTALASHTIRILMAYDI', () {
      final src = _solid(100, 50, 1, 2, 3);
      expect(identical(fitWithin(src, 640), src), isTrue);
    });

    test('katta rasm nisbatni saqlab kichrayadi', () {
      final out = fitWithin(_solid(4000, 3000, 1, 2, 3), 640);
      expect(out.width, 640);
      expect(out.height, 480);
    });

    test('bo\'yiga cho\'zilgan rasmda uzun tomon — balandlik', () {
      final out = fitWithin(_solid(300, 1200, 1, 2, 3), 600);
      expect(out.height, 600);
      expect(out.width, 150);
    });
  });

  group('letterbox', () {
    test('kvadrat rasm to\'liq to\'ldiradi, masshtab to\'g\'ri', () {
      final r = letterbox(_solid(320, 320, 9, 9, 9), 640);
      expect(r.scale, 2.0);
      expect(r.image.width, 640);
      expect(r.image.height, 640);
      expect(r.image.bytes[0], 9);
      expect(r.image.bytes[r.image.bytes.length - 1], 9); // hamma joy to'lgan
    });

    test('to\'ldirish O\'NG va PASTDAN (chap-yuqori burchak siljimaydi)', () {
      final r = letterbox(_solid(640, 320, 200, 200, 200), 640);
      expect(r.scale, 1.0);
      // Yuqori chap — rasm
      expect(r.image.bytes[0], 200);
      // Pastki qator — qora to'ldirish
      final lastRow = (639 * 640) * 3;
      expect(r.image.bytes[lastRow], 0);
      // O'ng chekka birinchi qatorda ham rasm bor (kenglik to'la)
      expect(r.image.bytes[639 * 3], 200);
    });

    test('bo\'yiga rasmda o\'ng tomon qora bo\'ladi', () {
      final r = letterbox(_solid(320, 640, 200, 200, 200), 640);
      expect(r.scale, 1.0);
      expect(r.image.bytes[0], 200); // chap
      expect(r.image.bytes[500 * 3], 0); // o'ngdagi to'ldirish
    });

    test('bo\'sh kirishda ham 640×640 qora kadr qaytadi (qulamaydi)', () {
      final r = letterbox(RgbImage.empty(), 64);
      expect(r.image.width, 64);
      expect(r.image.bytes.every((b) => b == 0), isTrue);
    });
  });

  group('grayRegion', () {
    test('uzun tomon AYNAN target bo\'ladi (kichraytirish ham, kattalashtirish ham)', () {
      final src = _solid(400, 200, 100, 100, 100);
      expect(grayRegion(src, 0, 0, 400, 200, 160).width, 160);
      expect(grayRegion(src, 0, 0, 40, 20, 160).width, 160);
    });

    test('luma formulasi — oq 255, qora 0', () {
      expect(meanBrightness(grayRegion(_solid(10, 10, 255, 255, 255), 0, 0, 10, 10, 8)), 255);
      expect(meanBrightness(grayRegion(_solid(10, 10, 0, 0, 0), 0, 0, 10, 10, 8)), 0);
    });

    test('faqat SO\'RALGAN soha o\'lchanadi', () {
      // Chap yarmi qora, o'ng yarmi oq.
      final px = Uint8List(20 * 10 * 3);
      for (var y = 0; y < 10; y++) {
        for (var x = 10; x < 20; x++) {
          final i = (y * 20 + x) * 3;
          px[i] = px[i + 1] = px[i + 2] = 255;
        }
      }
      final src = RgbImage(20, 10, px);
      expect(meanBrightness(grayRegion(src, 0, 0, 10, 10, 8)), 0);
      expect(meanBrightness(grayRegion(src, 10, 0, 10, 10, 8)), 255);
    });

    test('soha rasmdan chiqib ketsa ham qulamaydi', () {
      final src = _solid(20, 20, 50, 50, 50);
      expect(grayRegion(src, -50, -50, 500, 500, 16).width, greaterThan(0));
      expect(grayRegion(src, 19, 19, 100, 100, 16).width, greaterThan(0));
    });

    test('nol o\'lchamli soha — bo\'sh', () {
      expect(grayRegion(_solid(10, 10, 1, 1, 1), 0, 0, 0, 0, 16).pixels, isEmpty);
    });
  });

  group('warpAffineRgb', () {
    test('birlik matritsa rasmni o\'zgartirmaydi', () {
      final src = _noise(16, 16);
      final out = warpAffineRgb(src, Mat2x3.identity, 16, 16);
      expect(out.bytes, src.bytes);
    });

    test('siljitish — piksel ko\'chadi', () {
      final src = _noise(16, 16);
      const shift = Mat2x3(1, 0, 2, 0, 1, 0); // o'ngga 2 piksel
      final out = warpAffineRgb(src, shift, 16, 16);
      expect(out.bytes[(5 * 16 + 7) * 3], src.bytes[(5 * 16 + 5) * 3]);
    });

    test('chegaradan tashqari — qora', () {
      final out = warpAffineRgb(_solid(8, 8, 200, 200, 200), Mat2x3.identity, 16, 16);
      expect(out.bytes[(0 * 16 + 0) * 3], 200);
      expect(out.bytes[(15 * 16 + 15) * 3], 0);
    });

    test('teskarilanmaydigan matritsa — bo\'sh natija', () {
      final out = warpAffineRgb(_noise(8, 8), const Mat2x3(0, 0, 0, 0, 0, 0), 8, 8);
      expect(out.isEmpty, isTrue);
    });

    test('similarityTransform bilan 112×112 kesim chiqadi', () {
      final src = _noise(200, 200);
      final m = similarityTransform(const [
        60, 80, 140, 80, //
        100, 110,
        70, 140,
        130, 140,
      ]);
      final out = warpAffineRgb(src, m, 112, 112);
      expect(out.width, 112);
      expect(out.height, 112);
      // Kesim ichida haqiqiy piksellar bor (butunlay qora emas).
      expect(out.bytes.any((b) => b > 0), isTrue);
    });
  });

  group('rgbToNchw', () {
    test('kanallar ajratiladi va tartib RGB', () {
      final src = RgbImage(2, 1, Uint8List.fromList([1, 2, 3, 4, 5, 6]));
      final t = rgbToNchw(src, bgr: false);
      expect(t, [1, 4, 2, 5, 3, 6]);
    });

    test('bgr: true bo\'lsa birinchi va uchinchi kanal almashadi', () {
      final src = RgbImage(2, 1, Uint8List.fromList([1, 2, 3, 4, 5, 6]));
      final t = rgbToNchw(src, bgr: true);
      expect(t, [3, 6, 2, 5, 1, 4]);
    });

    test('uzunlik = 3 · w · h va oraliq 0..255 saqlanadi (normallashtirish YO\'Q)', () {
      final t = rgbToNchw(_solid(4, 5, 255, 128, 0), bgr: false);
      expect(t.length, 3 * 4 * 5);
      expect(t[0], 255);
      expect(t[20], 128);
      expect(t[40], 0);
    });
  });
}

// ---------------------------------------------------------------------------

RgbImage _solid(int w, int h, int r, int g, int b) {
  final px = Uint8List(w * h * 3);
  for (var i = 0; i < w * h; i++) {
    px[i * 3] = r;
    px[i * 3 + 1] = g;
    px[i * 3 + 2] = b;
  }
  return RgbImage(w, h, px);
}

/// Determinilangan "shovqin" — tasodifiy emas, test qayta ishga tushganda bir xil.
RgbImage _noise(int w, int h) {
  final px = Uint8List(w * h * 3);
  for (var i = 0; i < w * h; i++) {
    px[i * 3] = (i * 37) % 251;
    px[i * 3 + 1] = (i * 61 + 7) % 251;
    px[i * 3 + 2] = (i * 97 + 13) % 251;
  }
  return RgbImage(w, h, px);
}
