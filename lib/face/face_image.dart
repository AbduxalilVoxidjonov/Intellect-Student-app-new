/// Rasm ustidagi SOF amallar: o'lchamni o'zgartirish, kulrangga o'tkazish,
/// affin bo'yicha kesish (warp) va modelga beriladigan NCHW tenzor.
///
/// ⚠️ Bu yerda `package:image` YO'Q — hammasi tekis `Uint8List` ustida ishlaydi,
/// shuning uchun izolyatsiya (isolate) ga uzatish arzon va testlash oson.
library;

import 'dart:typed_data';

import 'face_math.dart';

/// Zich joylashgan RGB tasvir (3 bayt/piksel).
class RgbImage {
  final int width;
  final int height;

  /// `[r,g,b, r,g,b, ...]`, uzunligi `width * height * 3`.
  final Uint8List bytes;

  RgbImage(this.width, this.height, this.bytes)
    : assert(bytes.length == width * height * 3, 'bytes.length != w*h*3');

  factory RgbImage.empty() => RgbImage(0, 0, Uint8List(0));

  bool get isEmpty => width <= 0 || height <= 0;
}

/// Bilinear interpolyatsiya bilan o'lchamni o'zgartirish.
RgbImage resizeRgb(RgbImage src, int outW, int outH) {
  if (outW <= 0 || outH <= 0 || src.isEmpty) return RgbImage.empty();
  final out = Uint8List(outW * outH * 3);
  final sw = src.width, sh = src.height;
  // Piksel MARKAZLARI bo'yicha moslash (OpenCV INTER_LINEAR bilan bir xil):
  // aks holda kichraytirishda rasm yarim piksel siljib qolardi.
  final fx = sw / outW, fy = sh / outH;
  for (var y = 0; y < outH; y++) {
    final syf = ((y + 0.5) * fy - 0.5).clamp(0.0, (sh - 1).toDouble());
    final y0 = syf.floor();
    final y1 = y0 + 1 < sh ? y0 + 1 : y0;
    final wy = syf - y0;
    for (var x = 0; x < outW; x++) {
      final sxf = ((x + 0.5) * fx - 0.5).clamp(0.0, (sw - 1).toDouble());
      final x0 = sxf.floor();
      final x1 = x0 + 1 < sw ? x0 + 1 : x0;
      final wx = sxf - x0;

      final i00 = (y0 * sw + x0) * 3;
      final i01 = (y0 * sw + x1) * 3;
      final i10 = (y1 * sw + x0) * 3;
      final i11 = (y1 * sw + x1) * 3;
      final o = (y * outW + x) * 3;
      for (var c = 0; c < 3; c++) {
        final top = src.bytes[i00 + c] * (1 - wx) + src.bytes[i01 + c] * wx;
        final bot = src.bytes[i10 + c] * (1 - wx) + src.bytes[i11 + c] * wx;
        out[o + c] = (top * (1 - wy) + bot * wy).round().clamp(0, 255);
      }
    }
  }
  return RgbImage(outW, outH, out);
}

/// Rasmni uzun tomoni [maxSide] dan oshmaydigan qilib kichraytiradi.
/// Allaqachon kichik bo'lsa — o'zi qaytadi (kattalashtirilmaydi).
RgbImage fitWithin(RgbImage src, int maxSide) {
  if (src.isEmpty) return src;
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxSide) return src;
  final s = maxSide / longest;
  final w = (src.width * s).round().clamp(1, maxSide);
  final h = (src.height * s).round().clamp(1, maxSide);
  return resizeRgb(src, w, h);
}

/// Kulranglashtirish (ITU-R BT.601 luma — OpenCV `COLOR_RGB2GRAY` bilan bir xil).
int lumaOf(int r, int g, int b) =>
    (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

/// Tasvirning [x],[y],[w],[h] sohasini kulrangga o'tkazib, uzun tomoni AYNAN
/// [target] bo'ladigan qilib o'lchamini o'zgartiradi.
///
/// ⚠️ Kichraytirish ham, KATTALASHTIRISH ham qilinadi — aks holda tiniqlik
/// (Laplas dispersiyasi) qurilmadan qurilmaga taqqoslab bo'lmas edi: 400px
/// yuz bilan 100px yuzning dispersiyasi tabiatan boshqacha chiqadi.
GrayImage grayRegion(RgbImage src, int x, int y, int w, int h, int target) {
  if (src.isEmpty || w <= 0 || h <= 0 || target <= 0) return GrayImage.empty();
  // Soha rasmdan chiqib ketmasin.
  final x0 = x.clamp(0, src.width - 1);
  final y0 = y.clamp(0, src.height - 1);
  final x1 = (x + w).clamp(x0 + 1, src.width);
  final y1 = (y + h).clamp(y0 + 1, src.height);
  final rw = x1 - x0, rh = y1 - y0;

  final scale = target / (rw > rh ? rw : rh);
  final outW = (rw * scale).round().clamp(1, target);
  final outH = (rh * scale).round().clamp(1, target);

  final out = Uint8List(outW * outH);
  final fx = rw / outW, fy = rh / outH;
  for (var oy = 0; oy < outH; oy++) {
    final syf = (y0 + (oy + 0.5) * fy - 0.5).clamp(
      y0.toDouble(),
      (y1 - 1).toDouble(),
    );
    final sy0 = syf.floor();
    final sy1 = sy0 + 1 < y1 ? sy0 + 1 : sy0;
    final wy = syf - sy0;
    for (var ox = 0; ox < outW; ox++) {
      final sxf = (x0 + (ox + 0.5) * fx - 0.5).clamp(
        x0.toDouble(),
        (x1 - 1).toDouble(),
      );
      final sx0 = sxf.floor();
      final sx1 = sx0 + 1 < x1 ? sx0 + 1 : sx0;
      final wx = sxf - sx0;

      final i00 = (sy0 * src.width + sx0) * 3;
      final i01 = (sy0 * src.width + sx1) * 3;
      final i10 = (sy1 * src.width + sx0) * 3;
      final i11 = (sy1 * src.width + sx1) * 3;

      var v = 0.0;
      const coef = [0.299, 0.587, 0.114];
      for (var c = 0; c < 3; c++) {
        final top = src.bytes[i00 + c] * (1 - wx) + src.bytes[i01 + c] * wx;
        final bot = src.bytes[i10 + c] * (1 - wx) + src.bytes[i11 + c] * wx;
        v += coef[c] * (top * (1 - wy) + bot * wy);
      }
      out[oy * outW + ox] = v.round().clamp(0, 255);
    }
  }
  return GrayImage(outW, outH, out);
}

/// Affin bo'yicha kesish. [m] — MANBADAN natijaga o'tkazuvchi matritsa
/// (OpenCV `warpAffine` bilan bir xil kelishuv: ichkarida teskarisi olinadi va
/// har bir natija pikseli manbadan bilinear namuna oladi).
///
/// Chegaradan tashqari nuqtalar — qora (0). Matritsa teskarilanmasa bo'sh rasm.
RgbImage warpAffineRgb(RgbImage src, Mat2x3 m, int outW, int outH) {
  if (src.isEmpty || outW <= 0 || outH <= 0) return RgbImage.empty();
  final inv = m.invert();
  if (inv == null) return RgbImage.empty();
  final out = Uint8List(outW * outH * 3);
  final sw = src.width, sh = src.height;
  for (var y = 0; y < outH; y++) {
    for (var x = 0; x < outW; x++) {
      final px = x + 0.0, py = y + 0.0;
      final sx = inv.mapX(px, py);
      final sy = inv.mapY(px, py);
      if (sx < 0 || sy < 0 || sx > sw - 1 || sy > sh - 1) continue; // qora
      final x0 = sx.floor(), y0 = sy.floor();
      final x1 = x0 + 1 < sw ? x0 + 1 : x0;
      final y1 = y0 + 1 < sh ? y0 + 1 : y0;
      final wx = sx - x0, wy = sy - y0;
      final i00 = (y0 * sw + x0) * 3;
      final i01 = (y0 * sw + x1) * 3;
      final i10 = (y1 * sw + x0) * 3;
      final i11 = (y1 * sw + x1) * 3;
      final o = (y * outW + x) * 3;
      for (var c = 0; c < 3; c++) {
        final top = src.bytes[i00 + c] * (1 - wx) + src.bytes[i01 + c] * wx;
        final bot = src.bytes[i10 + c] * (1 - wx) + src.bytes[i11 + c] * wx;
        out[o + c] = (top * (1 - wy) + bot * wy).round().clamp(0, 255);
      }
    }
  }
  return RgbImage(outW, outH, out);
}

/// Rasmni [size]×[size] kvadratga joylashtiradi: nisbat saqlanadi, bo'sh joy
/// O'NG va PASTDAN qora bilan to'ldiriladi.
///
/// ⚠️ To'ldirish aynan o'ng/past — OpenCV `FaceDetectorYN` ham shunday qiladi
/// (`copyMakeBorder(0, bottom, 0, right)`), shuning uchun koordinatalarni
/// qaytarish uchun faqat masshtabga bo'lish yetadi (siljish yo'q).
///
/// Qaytadi: to'ldirilgan rasm va qo'llanilgan masshtab (`natija = asl × scale`).
({RgbImage image, double scale}) letterbox(RgbImage src, int size) {
  if (src.isEmpty || size <= 0) {
    return (image: RgbImage(size, size, Uint8List(size * size * 3)), scale: 1);
  }
  final longest = src.width > src.height ? src.width : src.height;
  final scale = size / longest;
  final w = (src.width * scale).round().clamp(1, size);
  final h = (src.height * scale).round().clamp(1, size);
  final resized = (w == src.width && h == src.height) ? src : resizeRgb(src, w, h);

  final out = Uint8List(size * size * 3); // 0 = qora
  for (var y = 0; y < h; y++) {
    out.setRange(
      y * size * 3,
      y * size * 3 + w * 3,
      resized.bytes,
      y * w * 3,
    );
  }
  return (image: RgbImage(size, size, out), scale: scale);
}

/// RGB → NCHW `Float32List` (0..255 oralig'i saqlanadi — ikkala model ham
/// normallashtirishni O'ZI kutmaydi).
///
/// [bgr] `true` bo'lsa kanallar B,G,R tartibida yoziladi (YuNet OpenCV'da BGR
/// rasm bilan o'qitilgan); `false` — R,G,B (SFace `swapRB=true` bilan chaqiriladi,
/// ya'ni unga RGB tushadi).
Float32List rgbToNchw(RgbImage img, {required bool bgr}) {
  final n = img.width * img.height;
  final out = Float32List(n * 3);
  final b = img.bytes;
  final c0 = bgr ? 2 : 0;
  final c2 = bgr ? 0 : 2;
  for (var i = 0; i < n; i++) {
    out[i] = b[i * 3 + c0].toDouble();
    out[n + i] = b[i * 3 + 1].toDouble();
    out[2 * n + i] = b[i * 3 + c2].toDouble();
  }
  return out;
}
