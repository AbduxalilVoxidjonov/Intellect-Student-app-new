import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:student/face/face_detector.dart';

/// Testlar uchun SUN'IY ma'lumot: YuNet chiqishi va rasm — hammasi kod bilan
/// yaratiladi, repoga bitta ham katta fayl qo'shilmaydi.

/// Sun'iy yuz tavsifi (640×640 model fazosida).
class SynthFace {
  final double cx, cy, w, h, score;
  final int stride;
  final List<double>? landmarks;

  const SynthFace({
    required this.cx,
    required this.cy,
    this.w = 200,
    this.h = 250,
    this.score = 0.99,
    this.stride = 32,
    this.landmarks,
  });

  /// Frontal yuzning odatiy 5 nuqtasi (yaw ≈ 0, roll ≈ 0).
  List<double> get points =>
      landmarks ??
      [
        cx - w * 0.2, cy - h * 0.1, // o'ng ko'z
        cx + w * 0.2, cy - h * 0.1, // chap ko'z
        cx, cy + h * 0.05, // burun
        cx - w * 0.15, cy + h * 0.22, // og'iz o'ng
        cx + w * 0.15, cy + h * 0.22, // og'iz chap
      ];
}

/// [faces] dan YuNet chiqishiga o'xshash 12 ta tenzor yasaydi.
///
/// Dekodlash formulasi teskarisiga qurilgan: `cx = (c + bbox0)·stride`,
/// `w = exp(bbox2)·stride`, `score = sqrt(cls·obj)`.
Map<String, Float32List> synthYuNetOutputs(
  List<SynthFace> faces, {
  int inputSize = YuNet.inputSize,
}) {
  final out = <String, Float32List>{};
  for (final s in YuNet.strides) {
    final n = (inputSize ~/ s) * (inputSize ~/ s);
    out['cls_$s'] = Float32List(n);
    out['obj_$s'] = Float32List(n);
    out['bbox_$s'] = Float32List(n * 4);
    out['kps_$s'] = Float32List(n * 10);
  }

  for (final f in faces) {
    final s = f.stride;
    final cols = inputSize ~/ s;
    final c = (f.cx / s).floor().clamp(0, cols - 1);
    final r = (f.cy / s).floor().clamp(0, cols - 1);
    final i = r * cols + c;

    out['cls_$s']![i] = f.score;
    out['obj_$s']![i] = f.score;
    out['bbox_$s']![i * 4] = f.cx / s - c;
    out['bbox_$s']![i * 4 + 1] = f.cy / s - r;
    out['bbox_$s']![i * 4 + 2] = math.log(f.w / s);
    out['bbox_$s']![i * 4 + 3] = math.log(f.h / s);

    final lm = f.points;
    for (var k = 0; k < 5; k++) {
      out['kps_$s']![i * 10 + k * 2] = lm[k * 2] / s - c;
      out['kps_$s']![i * 10 + k * 2 + 1] = lm[k * 2 + 1] / s - r;
    }
  }
  return out;
}

/// Determinilangan "tiniq" rasm: mayda shaxmat naqshi + gradient.
///
/// Naqsh ATAYIN 4 pikselli — 160px gacha kichraytirilganda ham struktura
/// saqlanadi va Laplas dispersiyasi yuqori chiqadi (ya'ni "xira" deb rad
/// etilmaydi). O'rtacha yorug'lik ~130.
Uint8List synthSharpPng(int width, int height, {int dark = 95, int light = 165}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final on = ((x ~/ 4) + (y ~/ 4)) % 2 == 0;
      final v = on ? light : dark;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return img.encodePng(image);
}

/// Bir xil rangli rasm — "xira" (Laplas ≈ 0) va yorug'ligi boshqariladigan.
Uint8List synthFlatPng(int width, int height, int level) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(level, level, level));
  return img.encodePng(image);
}
