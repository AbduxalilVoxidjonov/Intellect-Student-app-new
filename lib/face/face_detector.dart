/// YuNet (OpenCV Zoo, MIT) chiqishini dekodlash — SOF funksiyalar.
///
/// Model faqat xom tenzorlar qaytaradi; "qayerda yuz bor" degan javob shu
/// yerda hisoblanadi. Mantiq OpenCV `FaceDetectorYNImpl::postProcess` dan
/// bir xilma-bir ko'chirilgan (`modules/objdetect/src/face_detect.cpp`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Topilgan bitta yuz.
class FaceBox {
  /// Chap-yuqori burchak va o'lchamlar (kirish tasviri koordinatalarida).
  final double x, y, w, h;

  /// `sqrt(cls · obj)` — 0..1.
  final double score;

  /// 10 ta son: o'ng ko'z, chap ko'z, burun uchi, og'iz o'ng burchagi, chap burchagi.
  final List<double> landmarks;

  const FaceBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.score,
    required this.landmarks,
  });

  double get right => x + w;
  double get bottom => y + h;
  double get area => w <= 0 || h <= 0 ? 0 : w * h;

  /// Barcha koordinatalarni [k] ga ko'paytiradi (letterbox masshtabini qaytarish).
  FaceBox scaled(double k) => FaceBox(
    x: x * k,
    y: y * k,
    w: w * k,
    h: h * k,
    score: score,
    landmarks: [for (final v in landmarks) v * k],
  );

  @override
  String toString() =>
      'FaceBox(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${w.toStringAsFixed(1)}×${h.toStringAsFixed(1)}, '
      'score=${score.toStringAsFixed(3)})';
}

/// Model va dekodlash konstantalari.
class YuNet {
  YuNet._();

  /// Model kvadrat 640×640 kirish bilan QOTIRILGAN (2023mar). Dinamik emas —
  /// boshqa o'lcham berilsa ONNX Runtime xato qaytaradi.
  static const int inputSize = 640;

  static const List<int> strides = [8, 16, 32];

  static const String inputName = 'input';

  /// ⚠️ OpenCV `FaceDetectorYN::create` dagi standart qiymat bilan bir xil.
  /// Pasaytirish XAVFLI: soxta topilmalar ko'payadi va ular darhol
  /// "Kadrda bir nechta odam" bo'lib, to'g'ri selfini rad etadi.
  /// (O'lchov: yaxshi yoritilgan portret 0.91 dan yuqori ball oladi.)
  static const double defaultScoreThreshold = 0.9;
  static const double defaultNmsThreshold = 0.3;
  static const int defaultTopK = 50;
}

/// YuNet chiqishini yuzlar ro'yxatiga aylantiradi.
///
/// [outputs] — model chiqishi nomlari bo'yicha: `cls_8/16/32`, `obj_…`,
/// `bbox_…`, `kps_…`. Koordinatalar MODEL kirishining (640×640) o'lchamida
/// bo'ladi — letterbox masshtabini chaqiruvchi qaytaradi.
///
/// Chiqish kutilganidan qisqa bo'lsa (buzuq model / boshqa versiya) — o'sha
/// stride jimgina tashlab ketiladi, butun tahlil qulamaydi.
List<FaceBox> decodeYuNet(
  Map<String, Float32List> outputs, {
  int inputSize = YuNet.inputSize,
  double scoreThreshold = YuNet.defaultScoreThreshold,
  double nmsThreshold = YuNet.defaultNmsThreshold,
  int topK = YuNet.defaultTopK,
}) {
  final found = <FaceBox>[];

  for (final stride in YuNet.strides) {
    final cls = outputs['cls_$stride'];
    final obj = outputs['obj_$stride'];
    final bbox = outputs['bbox_$stride'];
    final kps = outputs['kps_$stride'];
    if (cls == null || obj == null || bbox == null || kps == null) continue;

    final cols = inputSize ~/ stride;
    final rows = cols;
    final anchors = rows * cols;
    if (cls.length < anchors ||
        obj.length < anchors ||
        bbox.length < anchors * 4 ||
        kps.length < anchors * 10) {
      continue;
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final clsV = cls[i].clamp(0.0, 1.0);
        final objV = obj[i].clamp(0.0, 1.0);
        final score = math.sqrt(clsV * objV);
        if (score < scoreThreshold) continue;

        final cx = (c + bbox[i * 4]) * stride;
        final cy = (r + bbox[i * 4 + 1]) * stride;
        final w = math.exp(bbox[i * 4 + 2]) * stride;
        final h = math.exp(bbox[i * 4 + 3]) * stride;

        final lm = List<double>.filled(10, 0);
        for (var n = 0; n < 5; n++) {
          lm[n * 2] = (kps[i * 10 + n * 2] + c) * stride;
          lm[n * 2 + 1] = (kps[i * 10 + n * 2 + 1] + r) * stride;
        }

        found.add(
          FaceBox(x: cx - w / 2, y: cy - h / 2, w: w, h: h, score: score, landmarks: lm),
        );
      }
    }
  }

  return nonMaxSuppression(found, nmsThreshold, topK);
}

/// Ustma-ust tushgan ramkalarni siyraklashtirish (Greedy NMS).
/// Ro'yxat ball bo'yicha KAMAYISH tartibida qaytadi.
List<FaceBox> nonMaxSuppression(List<FaceBox> boxes, double iouThreshold, int topK) {
  if (boxes.isEmpty) return const [];
  final sorted = [...boxes]..sort((a, b) => b.score.compareTo(a.score));
  final keep = <FaceBox>[];
  for (final b in sorted) {
    var ok = true;
    for (final k in keep) {
      if (iou(b, k) > iouThreshold) {
        ok = false;
        break;
      }
    }
    if (ok) {
      keep.add(b);
      if (topK > 0 && keep.length >= topK) break;
    }
  }
  return keep;
}

/// Ikki ramkaning kesishuv/birlashma nisbati (0..1).
double iou(FaceBox a, FaceBox b) {
  final x1 = math.max(a.x, b.x);
  final y1 = math.max(a.y, b.y);
  final x2 = math.min(a.right, b.right);
  final y2 = math.min(a.bottom, b.bottom);
  final iw = x2 - x1, ih = y2 - y1;
  if (iw <= 0 || ih <= 0) return 0;
  final inter = iw * ih;
  final union = a.area + b.area - inter;
  if (union <= 0) return 0;
  return inter / union;
}
