/// Yuz dvigatelining OMMAVIY turlari va sifat darvozasi.
///
/// Bularni `face_engine.dart` qayta eksport qiladi — ekran kodida faqat
/// `import 'package:student/face/face_engine.dart';` yetadi.
library;

import 'dart:typed_data';

import 'face_reasons.dart';

// ---------------------------------------------------------------------------
// Sifat o'lchovlari
// ---------------------------------------------------------------------------

/// Selfi sifati o'lchovlari — serverga JSON bo'lib yuboriladi va u yerda ham
/// tekshiriladi (klientga ishonib bo'lmaydi: so'rov qo'lda ham yuborilishi mumkin).
class FaceQuality {
  /// Topilgan yuzlar soni.
  final int faces;

  /// Yuz kengligi / kadr kengligi (0..1).
  final double faceRatio;

  /// Laplas dispersiyasi (katta = tiniqroq).
  final double sharpness;

  /// O'rtacha yorug'lik 0..255.
  final double brightness;

  /// Gradus, chapga/o'ngga burilish.
  final double yaw;

  /// Gradus, qiyshayish.
  final double roll;

  const FaceQuality({
    required this.faces,
    required this.faceRatio,
    required this.sharpness,
    required this.brightness,
    required this.yaw,
    required this.roll,
  });

  /// Yuz umuman topilmagan holat.
  static const FaceQuality none = FaceQuality(
    faces: 0,
    faceRatio: 0,
    sharpness: 0,
    brightness: 0,
    yaw: 0,
    roll: 0,
  );

  /// Faqat yuzlar sonini almashtirgan nusxa — "kadrda bir nechta odam"
  /// holatida qolgan o'lchovlar hisoblanmaydi (qaysi yuzniki bo'lardi?).
  FaceQuality copyWithFaces(int faces) => FaceQuality(
    faces: faces,
    faceRatio: faceRatio,
    sharpness: sharpness,
    brightness: brightness,
    yaw: yaw,
    roll: roll,
  );

  /// ⚠️ Sonlar YAXLITLANADI: JSON'da 17 xonali "0.2770000100135803" turishi
  /// serverdagi loglarni ham, taqqoslashni ham qiyinlashtiradi. Yaxlitlash
  /// darvoza qaroriga ta'sir qilmaydi (chegaralar bundan ancha yirik).
  Map<String, dynamic> toJson() => {
    'faces': faces,
    'faceRatio': _round(faceRatio, 4),
    'sharpness': _round(sharpness, 2),
    'brightness': _round(brightness, 2),
    'yaw': _round(yaw, 2),
    'roll': _round(roll, 2),
  };

  static double _round(double v, int digits) {
    if (!v.isFinite) return 0;
    final f = [1.0, 10.0, 100.0, 1000.0, 10000.0][digits];
    return (v * f).roundToDouble() / f;
  }

  @override
  String toString() => 'FaceQuality${toJson()}';
}

// ---------------------------------------------------------------------------
// Natija
// ---------------------------------------------------------------------------

/// Muvaffaqiyatli tahlil natijasi.
class FaceCapture {
  /// Serverga yuboriladigan siqilgan selfi (uzun tomoni ~640px, ~q85).
  /// Butun kadr emas — yuz atrofidan kengroq kesilgan qism (admin shuni ko'radi).
  final Uint8List jpeg;

  /// L2 normallashtirilgan embedding (SFace — 128 o'lcham).
  final Float32List vector;

  final FaceQuality quality;

  const FaceCapture({
    required this.jpeg,
    required this.vector,
    required this.quality,
  });
}

/// Natija: muvaffaqiyat yoki O'ZBEKCHA sabab.
class FaceResult {
  final FaceCapture? capture;

  /// `null` bo'lmasa — foydalanuvchiga ko'rsatiladigan matn ([FaceReasons]).
  final String? reason;

  /// Sabab bilan birga kelgan o'lchovlar (bo'lsa) — ekranda "nimasi yomon"
  /// ni ko'rsatish yoki logga yozish uchun. Muvaffaqiyatda `capture.quality`.
  final FaceQuality? quality;

  const FaceResult._(this.capture, this.reason, this.quality);

  factory FaceResult.ok(FaceCapture capture) =>
      FaceResult._(capture, null, capture.quality);

  factory FaceResult.fail(String reason, [FaceQuality? quality]) =>
      FaceResult._(null, reason, quality);

  bool get ok => capture != null;
}

// ---------------------------------------------------------------------------
// Chegaralar
// ---------------------------------------------------------------------------

/// Server `GET /student/face/status` dan keladigan chegaralar.
///
/// ⚠️ Chegaralar SERVERDA turadi — kalibrlash uchun ilovani qayta chiqarish
/// kerak bo'lmasin. Server javob bermasa [fallback] ishlatiladi.
class FaceThresholds {
  final double minSharpness, minBrightness, maxBrightness, minFaceRatio, maxYaw, maxRoll;

  const FaceThresholds({
    required this.minSharpness,
    required this.minBrightness,
    required this.maxBrightness,
    required this.minFaceRatio,
    required this.maxYaw,
    required this.maxRoll,
  });

  /// Server javob bermasa ishlatiladigan qiymatlar.
  ///
  /// Kalibrlash: 160px kulrang yuz kesimida o'lchangan (`grayRegion` bilan) —
  /// tiniq portret ~530, 5x5 xiralik ~96, 9x9 xiralik ~28 berdi, shuning uchun
  /// chegara 40 (kuchli xiralikni to'sadi, yengil xiralikni o'tkazadi).
  ///
  /// minFaceRatio 0.15 → 0.12: kamera doirasi kattaytirilgandan keyin
  /// (260–340px) bir xil masofadagi yuz nisbatan kichikroq ko'rinadi.
  static const FaceThresholds fallback = FaceThresholds(
    minSharpness: 40,
    minBrightness: 55,
    maxBrightness: 215,
    minFaceRatio: 0.12,
    maxYaw: 25,
    maxRoll: 20,
  );

  /// Serverdan kelgan JSON. Maydon yo'q/`null`/xato tur bo'lsa — [fallback]
  /// dagi qiymat olinadi (bitta buzuq maydon butun tekshiruvni to'xtatmasin).
  factory FaceThresholds.fromJson(Map<String, dynamic>? j) {
    final m = j ?? const <String, dynamic>{};
    return FaceThresholds(
      minSharpness: _d(m['minSharpness'], fallback.minSharpness),
      minBrightness: _d(m['minBrightness'], fallback.minBrightness),
      maxBrightness: _d(m['maxBrightness'], fallback.maxBrightness),
      minFaceRatio: _d(m['minFaceRatio'], fallback.minFaceRatio),
      maxYaw: _d(m['maxYaw'], fallback.maxYaw),
      maxRoll: _d(m['maxRoll'], fallback.maxRoll),
    );
  }

  Map<String, dynamic> toJson() => {
    'minSharpness': minSharpness,
    'minBrightness': minBrightness,
    'maxBrightness': maxBrightness,
    'minFaceRatio': minFaceRatio,
    'maxYaw': maxYaw,
    'maxRoll': maxRoll,
  };

  static double _d(dynamic v, double dflt) {
    if (v is num) {
      final d = v.toDouble();
      return d.isFinite ? d : dflt;
    }
    if (v is String) {
      final d = double.tryParse(v.trim());
      return (d != null && d.isFinite) ? d : dflt;
    }
    return dflt;
  }
}

// ---------------------------------------------------------------------------
// Sifat darvozasi — YAGONA joy
// ---------------------------------------------------------------------------

/// O'lchovlarni chegaralarga solishtiradi. `null` — hammasi joyida.
///
/// ⚠️ TARTIB MUHIM (foydalanuvchi FAQAT BITTA xabar ko'radi):
/// yuz soni → masofa → **yorug'lik** → tiniqlik → burilish.
///
/// Yorug'lik tiniqlikdan OLDIN tekshiriladi ATAYIN: qorong'i kadrda kontrast
/// past bo'lgani uchun Laplas dispersiyasi ham tushib ketadi (o'lchov: bir xil
/// rasmni qorong'ilashtirganda 533 → 44). Tartib teskari bo'lsa foydalanuvchi
/// "Rasm xira" degan xabarni olib, telefonni qimirlatmaslikka urinardi —
/// aslida chiroqni yoqishi kerak edi.
String? faceQualityReason(FaceQuality q, FaceThresholds t) {
  if (q.faces == 0) return FaceReasons.noFace;
  if (q.faces > 1) return FaceReasons.manyFaces;
  if (q.faceRatio < t.minFaceRatio) return FaceReasons.tooFar;
  if (q.brightness < t.minBrightness) return FaceReasons.dark;
  if (q.brightness > t.maxBrightness) return FaceReasons.bright;
  if (q.sharpness < t.minSharpness) return FaceReasons.blurry;
  if (q.yaw.abs() > t.maxYaw || q.roll.abs() > t.maxRoll) {
    return FaceReasons.notFrontal;
  }
  return null;
}
