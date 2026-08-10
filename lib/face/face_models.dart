/// Modellar haqidagi YAGONA ma'lumot: assets yo'llari, tenzor nomlari va
/// serverga yuboriladigan `modelVersion` satri.
///
/// Manba va litsenziya: `assets/models/README.md`.
library;

class FaceModels {
  FaceModels._();

  /// Yuz DETEKTORI — YuNet (OpenCV Zoo, MIT), ~0.23 MB.
  static const String detectorAsset =
      'assets/models/face_detection_yunet_2023mar.onnx';

  /// Yuz EMBEDDINGI — SFace int8 (OpenCV Zoo, Apache-2.0), ~9.9 MB.
  static const String recognizerAsset =
      'assets/models/face_recognition_sface_2021dec_int8.onnx';

  /// SFace kirish tenzori nomi va o'lchami.
  static const String recognizerInputName = 'data';
  static const String recognizerOutputName = 'fc1';
  static const int recognizerSize = 112;

  /// Embedding o'lchami.
  static const int vectorLength = 128;

  /// ⚠️ SERVER SHU SATRNI TEKSHIRADI. Boshqa model (yoki boshqa tekislash /
  /// normallashtirish) bilan hisoblangan vektorlarni kosinus bilan
  /// solishtirib bo'lmaydi — ular boshqa fazoda yotadi.
  ///
  /// Quyidagilardan BIRORTASI o'zgarsa satr ham o'zgarishi SHART va serverdagi
  /// eski vektorlar qayta hisoblanishi kerak:
  ///   • SFace fayli (fp32 ↔ int8, boshqa sana),
  ///   • tekislash shabloni yoki `similarityTransform`,
  ///   • kanal tartibi / kirish oralig'i,
  ///   • detektor (yuz ramkasi/nuqtalari siljisa embedding ham siljiydi).
  static const String modelVersion = 'sface-2021dec-int8-v1';
}
