/// ONNX Runtime ustidagi YUPQA qatlam.
///
/// Nega alohida: `flutter_onnxruntime` — platforma plagini, ya'ni `flutter test`
/// ichida (native tomon yo'q) umuman ishlamaydi. Dvigatel shu interfeysga
/// tayangani uchun butun quvur (dekodlash → detektor → sifat → tekislash →
/// embedding) modelsiz, soxta runner bilan testdan o'tadi.
library;

import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'face_detector.dart';
import 'face_models.dart';

/// Ikki modelni yuklab, ular ustida inference qiladigan qatlam.
abstract class OrtRunner {
  /// Modellarni yuklaydi. Ikkinchi marta chaqirilsa hech narsa qilmaydi.
  Future<void> load();

  /// YuNet: kirish `[1,3,640,640]` (BGR, NCHW, 0..255).
  /// Qaytadi: chiqish nomi → tekis `Float32List`.
  Future<Map<String, Float32List>> runDetector(Float32List input);

  /// SFace: kirish `[1,3,112,112]` (RGB, NCHW, 0..255). Qaytadi: 128 son.
  Future<Float32List> runRecognizer(Float32List input);

  Future<void> close();
}

/// `flutter_onnxruntime` ustidagi haqiqiy amalga oshiruv.
class FlutterOrtRunner implements OrtRunner {
  OrtSession? _detector;
  OrtSession? _recognizer;

  /// ⚠️ Oqim soni ATAYIN 2: telefonda barcha yadroni band qilish batareyani
  /// yeydi va issiqlikdan tezlik baribir tushadi; bu — bir martalik selfi
  /// tekshiruvi, sekundning ulushi ahamiyatsiz.
  static const int _threads = 2;

  @override
  Future<void> load() async {
    if (_detector != null && _recognizer != null) return;
    final ort = OnnxRuntime();
    final options = OrtSessionOptions(intraOpNumThreads: _threads);
    _detector ??= await ort.createSessionFromAsset(
      FaceModels.detectorAsset,
      options: options,
    );
    _recognizer ??= await ort.createSessionFromAsset(
      FaceModels.recognizerAsset,
      options: options,
    );
  }

  @override
  Future<Map<String, Float32List>> runDetector(Float32List input) async {
    final session = _detector;
    if (session == null) throw StateError('Detektor yuklanmagan — load() chaqiring');
    const s = YuNet.inputSize;
    return _run(session, YuNet.inputName, input, [1, 3, s, s], (outputs) async {
      final res = <String, Float32List>{};
      for (final e in outputs.entries) {
        res[e.key] = _toFloat32(await e.value.asFlattenedList());
      }
      return res;
    });
  }

  @override
  Future<Float32List> runRecognizer(Float32List input) async {
    final session = _recognizer;
    if (session == null) throw StateError('Embedding modeli yuklanmagan — load() chaqiring');
    const s = FaceModels.recognizerSize;
    return _run(session, FaceModels.recognizerInputName, input, [1, 3, s, s], (
      outputs,
    ) async {
      final out = outputs[FaceModels.recognizerOutputName] ?? outputs.values.first;
      return _toFloat32(await out.asFlattenedList());
    });
  }

  /// Kirish tenzorini yaratadi, ishga tushiradi va NATIVE resurslarni
  /// (kirish ham, chiqish ham) HAR DOIM bo'shatadi — xato bo'lsa ham.
  /// Bir necha marta selfi olinganda bu sizib ketsa xotira o'sib borardi.
  Future<T> _run<T>(
    OrtSession session,
    String inputName,
    Float32List input,
    List<int> shape,
    Future<T> Function(Map<String, OrtValue>) read,
  ) async {
    final tensor = await OrtValue.fromList(input, shape);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({inputName: tensor});
      return await read(outputs);
    } finally {
      for (final v in outputs?.values ?? const <OrtValue>[]) {
        try {
          await v.dispose();
        } catch (_) {
          // Bo'shatish xatosi natijaga ta'sir qilmaydi.
        }
      }
      try {
        await tensor.dispose();
      } catch (_) {
        // Yuqoridagi bilan bir xil sabab.
      }
    }
  }

  @override
  Future<void> close() async {
    final d = _detector, r = _recognizer;
    _detector = null;
    _recognizer = null;
    await d?.close();
    await r?.close();
  }

  static Float32List _toFloat32(List<dynamic> data) {
    final out = Float32List(data.length);
    for (var i = 0; i < data.length; i++) {
      final v = data[i];
      out[i] = v is num ? v.toDouble() : 0.0;
    }
    return out;
  }
}
