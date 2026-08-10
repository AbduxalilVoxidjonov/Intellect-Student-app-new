/// Selfi rad etilish SABABLARI — foydalanuvchiga ko'rsatiladigan matnlar.
///
/// ⚠️ YAGONA MANBA: server ham AYNAN shu matnlarni ishlatadi (u ham
/// `FaceQuality` JSON'ini qayta tekshiradi). Matnni o'zgartirsangiz —
/// serverdagi ro'yxatni ham o'zgartiring, aks holda bir xil holat uchun
/// ikki xil xabar chiqadi.
library;

class FaceReasons {
  FaceReasons._();

  /// Detektor kadrda umuman yuz topmadi.
  static const String noFace = 'Yuz topilmadi';

  /// Kadrda bir nechta yuz — kimni tekshirish kerakligi noaniq.
  static const String manyFaces = "Kadrda bir nechta odam";

  /// Yuz kadrga nisbatan juda kichik (`faceRatio` past).
  static const String tooFar = 'Yaqinroq keling';

  /// Laplas dispersiyasi past — qimirlagan yoki fokusga tushmagan rasm.
  static const String blurry = "Rasm xira — qimirlatmasdan qayta oling";

  /// O'rtacha yorug'lik past.
  static const String dark = "Yorug'roq joyda oling";

  /// O'rtacha yorug'lik juda yuqori (kuyib ketgan kadr).
  static const String bright = "Yorug'lik juda kuchli";

  /// Yuz burilgan yoki qiyshaygan (`yaw`/`roll` katta).
  static const String notFrontal = "Yuzni kameraga to'g'ri qarating";

  /// Rasm baytlarini umuman dekodlab bo'lmadi (buzuq fayl, qo'llab-quvvatlanmagan format).
  static const String badImage = "Rasmni o'qib bo'lmadi — qayta oling";

  /// Model yuklanmadi yoki inference xato berdi.
  static const String engineFailed = "Tekshiruv ishlamadi — qayta urinib ko'ring";

  /// Barcha sabablar — server bilan solishtirish va testlar uchun.
  static const List<String> all = [
    noFace,
    manyFaces,
    tooFar,
    blurry,
    dark,
    bright,
    notFrontal,
    badImage,
    engineFailed,
  ];
}
