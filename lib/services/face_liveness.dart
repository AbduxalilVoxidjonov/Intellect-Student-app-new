import 'dart:convert';

import '../face/face_engine.dart' show FaceQuality;

/// TIRIKLIK TEKSHIRUVI — qoidalar va o'lchov (SOF mantiq, testlangan).
///
/// Server tasodifiy 2 ta harakat beradi va ularning HAR BIRI uchun O'LCHANGAN
/// qiymatni qayta tekshiradi (`FaceLiveness.Check`), ya'ni `ok:true` deb yolg'on
/// yozib bo'lmaydi. Shu sabab bu yerdagi chegaralar serverdagilar bilan bir xil
/// ma'noda bo'lishi SHART — faqat mijoz tomonda ATAYIN qattiqroq (pastga qarang).
class Liveness {
  Liveness._();

  // -------------------------------------------------------------------------
  // Harakatlar — serverdagi ro'yxat bilan AYNAN bir xil kalitlar
  // -------------------------------------------------------------------------

  static const String turnLeft = 'turn_left';
  static const String turnRight = 'turn_right';
  static const String moveCloser = 'move_closer';
  static const String moveBack = 'move_back';

  /// Server yuborishi mumkin bo'lgan barcha harakatlar.
  static const List<String> all = [turnLeft, turnRight, moveCloser, moveBack];

  /// Ekrandagi ko'rsatma.
  static String label(String action) => switch (action) {
        turnLeft => 'Boshingizni CHAPGA buring',
        turnRight => "Boshingizni O'NGGA buring",
        moveCloser => 'Telefonni YAQINROQ tuting',
        moveBack => 'Telefonni UZOQROQ tuting',
        _ => 'Ko\'rsatmani bajaring',
      };

  /// Qo'shimcha izoh (ko'rsatma ostida kichik matn).
  static String hint(String action) => switch (action) {
        turnLeft || turnRight => "Yuzingiz kadrdan chiqib ketmasin",
        moveCloser => "Yuzingiz kadrni to'ldirsin",
        moveBack => 'Yuzingiz kichrayguncha uzoqlashtiring',
        _ => '',
      };

  // -------------------------------------------------------------------------
  // Chegaralar
  // -------------------------------------------------------------------------

  /// SERVER chegaralari (`FaceLiveness.MinTurnDegrees/CloserFactor/BackFactor`).
  static const double serverMinTurnDegrees = 12;
  static const double serverCloserFactor = 1.25;
  static const double serverBackFactor = 0.8;

  /// MIJOZ chegaralari — ATAYIN qattiqroq.
  ///
  /// NEGA: server masofa harakatlarini YAKUNIY selfi kadridagi `faceRatio` ga
  /// nisbatan tekshiradi, biz esa harakat boshidagi kadrga nisbatan o'lchaymiz.
  /// Ikki kadr bir xil emas (foydalanuvchi biroz qimirlaydi), shuning uchun
  /// zaxira qoldiriladi — aks holda ekranda "bajarildi" deb turgan harakat
  /// serverda rad etilib, foydalanuvchi sababini tushunmasdi.
  static const double minTurnDegrees = 18;
  static const double closerFactor = 1.45;
  static const double backFactor = 0.68;

  /// Bir harakat uchun eng qisqa/eng uzun vaqt (server `ms` ni shu oraliqda
  /// kutadi: `300 <= ms <= 20000`).
  static const int minActionMs = 300;
  static const int maxActionMs = 20000;

  // -------------------------------------------------------------------------
  // O'lchov
  // -------------------------------------------------------------------------

  /// Harakat uchun MA'NOLI o'lchov: burilishda — yaw (gradus, chapga burilish
  /// MANFIY), masofada — `faceRatio` (0..1).
  static double measure(String action, FaceQuality q) => switch (action) {
        turnLeft || turnRight => q.yaw,
        _ => q.faceRatio,
      };

  /// Harakat MIJOZ chegaralari bo'yicha bajarildimi.
  ///
  /// [baseline] — harakat boshlanishidagi `faceRatio` (faqat masofa uchun).
  static bool done(String action, double value, double baseline) {
    if (!value.isFinite) return false;
    return switch (action) {
      turnLeft => value <= -minTurnDegrees,
      turnRight => value >= minTurnDegrees,
      moveCloser => baseline > 0 && value >= baseline * closerFactor,
      moveBack => baseline > 0 && value <= baseline * backFactor,
      _ => false,
    };
  }

  /// SERVER shu qiymatni qabul qiladimi — [FaceQuality.faceRatio] ni yakuniy
  /// selfidan olib tekshiramiz (serverdagi mantiqning aynan o'zi).
  static bool serverAccepts(String action, double value, double baseline) {
    if (!value.isFinite) return false;
    return switch (action) {
      turnLeft => value <= -serverMinTurnDegrees,
      turnRight => value >= serverMinTurnDegrees,
      moveCloser => baseline > 0 && value >= baseline * serverCloserFactor,
      moveBack => baseline > 0 && value <= baseline * serverBackFactor,
      _ => false,
    };
  }

  /// YAKUNIY KADR mos keladimi.
  ///
  /// ⚠️ ENG NOZIK JOY: server masofa harakatlarini yuborilgan SELFI kadridagi
  /// `faceRatio` ga nisbatan o'lchaydi. Ya'ni foydalanuvchi "yaqinlashish" ni
  /// bajarib, keyin selfini juda yaqindan olsa — nisbat buzilib, harakat
  /// rad etilardi. Shuning uchun yakuniy kadrni shu funksiya tasdiqlamaguncha
  /// yubormaymiz ("odatdagi masofada turing" deb ko'rsatma beramiz).
  static bool finalFrameOk(List<LivenessStep> steps, double faceRatio) {
    if (!faceRatio.isFinite || faceRatio <= 0) return false;
    for (final s in steps) {
      if (s.action == moveCloser || s.action == moveBack) {
        if (!serverAccepts(s.action, s.value, faceRatio)) return false;
      }
    }
    return true;
  }

  /// Serverga yuboriladigan JSON (massiv, TARTIB muhim).
  static String toJsonString(List<LivenessStep> steps) =>
      jsonEncode(steps.map((s) => s.toJson()).toList());
}

/// Bitta bajarilgan harakat.
class LivenessStep {
  final String action;
  final bool ok;

  /// Harakat boshlanishidan bajarilgunicha o'tgan vaqt (ms).
  final int ms;

  /// O'LCHANGAN qiymat: burilishda gradus (yaw), masofada `faceRatio`.
  final double value;

  const LivenessStep({
    required this.action,
    required this.ok,
    required this.ms,
    required this.value,
  });

  /// ⚠️ `ms` va `value` — SON bo'lishi shart (server satrni qabul qilmaydi),
  /// `value` esa yaxlitlanadi: xom `-27.499999523162842` loglarni o'qishni
  /// qiyinlashtiradi, qarorga esa ta'sir qilmaydi.
  Map<String, dynamic> toJson() => {
        'action': action,
        'ok': ok,
        'ms': ms,
        'value': _round(value),
      };

  static double _round(double v) {
    if (!v.isFinite) return 0;
    return (v * 10000).roundToDouble() / 10000;
  }
}
