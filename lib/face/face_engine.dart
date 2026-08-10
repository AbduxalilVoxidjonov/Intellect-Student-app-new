/// YUZ TANISH DVIGATELI — rasm baytlaridan L2 normallashtirilgan vektorgacha.
///
/// Model TELEFONDA ishlaydi (server 1 GB RAM — u yerda model ishlatilmaydi).
/// Serverga faqat vektor + sifat o'lchovlari + siqilgan selfi ketadi, solishtirish
/// (kosinus) esa serverda bo'ladi.
///
/// Quvur (`analyze`):
///   1. baytlarni dekodlash (EXIF burilishi hisobga olinadi), uzun tomoni 640 ga;
///   2. YuNet detektori → yuzlar (0 ta / 2+ ta bo'lsa shu yerda to'xtaydi);
///   3. sifat darvozasi (`faceQualityReason`);
///   4. 5 nuqta bo'yicha tekislab 112×112 kesish (SFace shabloni);
///   5. SFace → 128 son → L2 normallashtirish;
///   6. yuz atrofidan kengroq kesilgan JPEG (admin ko'radi).
///
/// ⚠️ OG'IR ISH IZOLYATSIYADA: dekodlash, o'lcham o'zgartirish, tekislash va
/// JPEG siqish `compute` orqali alohida isolate'da bajariladi. INFERENCE esa
/// asosiy isolate'da qoladi — `flutter_onnxruntime` platforma kanali orqali
/// ishlaydi, kanal esa fon isolate'idan (maxsus `RootIsolateToken` uzatmasdan)
/// chaqirilmaydi. Buning uchun UI muzlamaydi: kanal chaqiruvi asinxron va
/// hisob-kitob native tomonda ketadi.
library;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'face_detector.dart';
import 'face_image.dart';
import 'face_math.dart';
import 'face_models.dart';
import 'face_reasons.dart';
import 'face_types.dart';
import 'ort_runner.dart';

// Ekran kodi uchun BITTA import yetadi.
export 'face_math.dart'
    show
        cosineSimilarity,
        l2Normalize,
        vectorFromBase64,
        vectorFromBytes,
        vectorToBase64,
        vectorToBytes;
export 'face_models.dart' show FaceModels;
export 'face_reasons.dart' show FaceReasons;
export 'face_types.dart'
    show FaceCapture, FaceQuality, FaceResult, FaceThresholds, faceQualityReason;

/// Rasmdan yuz vektorini oladigan dvigatel.
abstract class FaceEngine {
  /// Serverga yuboriladigan model identifikatori — vektor fazosining "versiyasi".
  String get modelVersion;

  /// Modelni yuklaydi. Bir necha marta chaqirilsa ham bir marta yuklanadi.
  Future<void> init();

  /// Rasmni tahlil qiladi. Xato bo'lsa ham ISTISNO TASHLAMAYDI —
  /// foydalanuvchiga ko'rsatiladigan sabab bilan [FaceResult] qaytaradi.
  Future<FaceResult> analyze(Uint8List imageBytes, FaceThresholds t);

  void dispose();
}

// ---------------------------------------------------------------------------
// Haqiqiy amalga oshiruv
// ---------------------------------------------------------------------------

class OnnxFaceEngine implements FaceEngine {
  /// Modelni ishga tushiradigan qatlam. Testlarda soxta runner beriladi.
  final OrtRunner _runner;

  /// `false` bo'lsa og'ir bosqichlar AYNI isolate'da bajariladi.
  /// Testlarda `false` — isolate ochish testni sekinlashtiradi va
  /// `compute` natijasi baribir bir xil.
  final bool useIsolate;

  /// Detektor ball chegarasi.
  final double scoreThreshold;

  Future<void>? _loading;
  bool _disposed = false;

  OnnxFaceEngine({
    OrtRunner? runner,
    this.useIsolate = true,
    this.scoreThreshold = YuNet.defaultScoreThreshold,
  }) : _runner = runner ?? FlutterOrtRunner();

  @override
  String get modelVersion => FaceModels.modelVersion;

  @override
  Future<void> init() {
    if (_disposed) throw StateError('OnnxFaceEngine allaqachon yopilgan');
    // Bir vaqtda ikki chaqiruv kelsa ikkalasi BITTA yuklashni kutadi.
    return _loading ??= _runner.load().onError((e, st) {
      _loading = null; // keyingi urinish qayta yuklashi uchun
      Error.throwWithStackTrace(e!, st);
    });
  }

  @override
  Future<FaceResult> analyze(Uint8List imageBytes, FaceThresholds t) async {
    try {
      await init();
    } catch (e) {
      debugPrint('FaceEngine: model yuklanmadi — $e');
      return FaceResult.fail(FaceReasons.engineFailed);
    }

    try {
      final prep = await _stage(prepareFaceInput, imageBytes);
      if (prep == null) return FaceResult.fail(FaceReasons.badImage);

      final outputs = await _runner.runDetector(prep.input);
      final boxes = decodeYuNet(outputs, scoreThreshold: scoreThreshold);

      if (boxes.isEmpty) {
        return FaceResult.fail(FaceReasons.noFace, FaceQuality.none);
      }
      if (boxes.length > 1) {
        return FaceResult.fail(
          FaceReasons.manyFaces,
          FaceQuality.none.copyWithFaces(boxes.length),
        );
      }

      // Letterbox masshtabini yechib, ishchi rasm koordinatalariga qaytaramiz.
      final face = boxes.first.scaled(1 / prep.scale);
      final crop = await _stage(
        cropAndMeasure,
        FaceCropRequest(
          rgb: prep.rgb,
          width: prep.width,
          height: prep.height,
          x: face.x,
          y: face.y,
          w: face.w,
          h: face.h,
          landmarks: face.landmarks,
        ),
      );

      final reason = faceQualityReason(crop.quality, t);
      if (reason != null) return FaceResult.fail(reason, crop.quality);

      final raw = await _runner.runRecognizer(crop.alignedInput);
      if (raw.length != FaceModels.vectorLength) {
        debugPrint(
          'FaceEngine: kutilmagan vektor uzunligi ${raw.length} '
          '(kutilgan ${FaceModels.vectorLength})',
        );
        return FaceResult.fail(FaceReasons.engineFailed, crop.quality);
      }

      return FaceResult.ok(
        FaceCapture(
          jpeg: crop.jpeg,
          vector: l2Normalize(raw),
          quality: crop.quality,
        ),
      );
    } catch (e, st) {
      // Bu yerga tushish = kutilmagan xato. Ekran qulamasin: sabab qaytadi.
      debugPrint('FaceEngine.analyze xato: $e\n$st');
      return FaceResult.fail(FaceReasons.engineFailed);
    }
  }

  Future<R> _stage<Q, R>(ComputeCallback<Q, R> fn, Q arg) =>
      useIsolate ? compute(fn, arg) : Future.sync(() => fn(arg));

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _loading = null;
    // Fire-and-forget: dispose() sinxron, native resurs bo'shashini kutmaymiz.
    _runner.close().catchError((Object e) {
      debugPrint('FaceEngine.dispose: $e');
    });
  }
}

// ---------------------------------------------------------------------------
// Isolate bosqichlari — TOP-LEVEL va SOF (compute uchun shart)
// ---------------------------------------------------------------------------

/// 1-bosqich natijasi: ishchi rasm + detektorga tayyor tenzor.
class FacePrepared {
  /// Ishchi rasm (uzun tomoni ≤ 640), zich RGB.
  final Uint8List rgb;
  final int width;
  final int height;

  /// Ishchi rasmni 640×640 ga joylashtirish masshtabi (`640-fazo = ishchi × scale`).
  final double scale;

  /// `[1,3,640,640]` BGR NCHW.
  final Float32List input;

  const FacePrepared({
    required this.rgb,
    required this.width,
    required this.height,
    required this.scale,
    required this.input,
  });
}

/// Baytlarni dekodlab, detektor kirishini tayyorlaydi. Dekodlab bo'lmasa `null`.
FacePrepared? prepareFaceInput(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null; // buzuq fayl — sabab bilan qaytamiz, istisno tashlamaymiz
  }
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;

  // Telefon kamerasi rasmni ko'pincha EXIF burchagi bilan yozadi — "pishirmasak"
  // yuz yonboshlagan bo'lib chiqadi va detektor topmaydi.
  var image = img.bakeOrientation(decoded);
  // 16-bit / palitrali / 4-kanalli rasmlarni bir ko'rinishga keltiramiz,
  // aks holda `getBytes` xom formatdagi baytlarni qaytaradi.
  if (image.format != img.Format.uint8 || image.numChannels != 3) {
    image = image.convert(format: img.Format.uint8, numChannels: 3);
  }

  final full = RgbImage(
    image.width,
    image.height,
    image.getBytes(order: img.ChannelOrder.rgb),
  );
  final work = fitWithin(full, YuNet.inputSize);
  final boxed = letterbox(work, YuNet.inputSize);

  return FacePrepared(
    rgb: work.bytes,
    width: work.width,
    height: work.height,
    scale: boxed.scale,
    input: rgbToNchw(boxed.image, bgr: true),
  );
}

/// 2-bosqich kirishi.
class FaceCropRequest {
  final Uint8List rgb;
  final int width;
  final int height;

  /// Yuz ramkasi — ishchi rasm koordinatalarida.
  final double x, y, w, h;

  /// 10 ta son — ishchi rasm koordinatalarida.
  final List<double> landmarks;

  const FaceCropRequest({
    required this.rgb,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.landmarks,
  });
}

/// 2-bosqich natijasi.
class FaceCropResult {
  final FaceQuality quality;

  /// `[1,3,112,112]` RGB NCHW — SFace kirishi.
  final Float32List alignedInput;

  /// Serverga yuboriladigan selfi.
  final Uint8List jpeg;

  const FaceCropResult({
    required this.quality,
    required this.alignedInput,
    required this.jpeg,
  });
}

/// Sifat metrikalarini o'lchaydi, yuzni tekislaydi va yuboriladigan JPEG'ni yasaydi.
///
/// ⚠️ Sifat rad etilsa ham tekislash/JPEG hisoblanadi — bu bir necha millisekund,
/// ammo isolate'ni ikki marta ochishdan (har biri o'nlab millisekund) arzonroq.
FaceCropResult cropAndMeasure(FaceCropRequest r) {
  final work = RgbImage(r.width, r.height, r.rgb);

  // Tiniqlik va yorug'lik — FAQAT yuz sohasida va 160px kulrangda o'lchanadi:
  // fon tiniq, yuz xira bo'lgan kadr aks holda o'tib ketardi.
  final gray = grayRegion(
    work,
    r.x.floor(),
    r.y.floor(),
    r.w.ceil(),
    r.h.ceil(),
    kQualitySize,
  );
  final pose = headPose(r.landmarks);
  final quality = FaceQuality(
    faces: 1,
    faceRatio: r.width <= 0 ? 0 : r.w / r.width,
    sharpness: laplacianVariance(gray),
    brightness: meanBrightness(gray),
    yaw: pose.yaw,
    roll: pose.roll,
  );

  final aligned = warpAffineRgb(
    work,
    similarityTransform(r.landmarks),
    FaceModels.recognizerSize,
    FaceModels.recognizerSize,
  );

  return FaceCropResult(
    quality: quality,
    alignedInput: rgbToNchw(aligned, bgr: false),
    jpeg: encodeFaceJpeg(work, r.x, r.y, r.w, r.h),
  );
}

/// Sifat o'lchanadigan kulrang kesimning uzun tomoni (piksel).
const int kQualitySize = 160;

/// Yuborilgan selfining uzun tomoni.
const int kJpegMaxSide = 640;

/// JPEG sifati.
const int kJpegQuality = 85;

/// Yuz atrofidan har tomonga qo'shiladigan zaxira (ramka o'lchamiga nisbatan).
const double kJpegMargin = 0.35;

/// Yuz atrofidan kengroq kesib, JPEG qiladi (admin shu rasmni ko'radi).
Uint8List encodeFaceJpeg(RgbImage work, double x, double y, double w, double h) {
  final mx = w * kJpegMargin, my = h * kJpegMargin;
  final x0 = (x - mx).floor().clamp(0, work.width - 1);
  final y0 = (y - my).floor().clamp(0, work.height - 1);
  final x1 = (x + w + mx).ceil().clamp(x0 + 1, work.width);
  final y1 = (y + h + my).ceil().clamp(y0 + 1, work.height);
  final cw = x1 - x0, ch = y1 - y0;

  final crop = Uint8List(cw * ch * 3);
  for (var row = 0; row < ch; row++) {
    final src = ((y0 + row) * work.width + x0) * 3;
    crop.setRange(row * cw * 3, (row + 1) * cw * 3, work.bytes, src);
  }
  final fitted = fitWithin(RgbImage(cw, ch, crop), kJpegMaxSide);

  final image = img.Image.fromBytes(
    width: fitted.width,
    height: fitted.height,
    bytes: fitted.bytes.buffer,
    bytesOffset: fitted.bytes.offsetInBytes,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
  return img.encodeJpg(image, quality: kJpegQuality);
}

// ---------------------------------------------------------------------------
// Testlar uchun soxta dvigatel
// ---------------------------------------------------------------------------

/// Model YO'Q — oldindan berilgan natijani qaytaradi.
///
/// Ekran/oqim testlarida ishlatiladi: kamera ekrani "sabab" holatini ham,
/// muvaffaqiyatni ham modelsiz sinab ko'ra oladi.
class FakeFaceEngine implements FaceEngine {
  /// Har `analyze` chaqiruvida qaytariladigan natija.
  FaceResult result;

  /// Sun'iy kechikish (ekrandagi kutish holatini sinash uchun).
  final Duration delay;

  @override
  final String modelVersion;

  /// `init()` necha marta HAQIQATAN yuklaganini ko'rsatadi (idempotentlik testi).
  int initCount = 0;

  /// `analyze()` necha marta chaqirilgani.
  int analyzeCount = 0;

  /// Oxirgi kelgan baytlar va chegaralar.
  Uint8List? lastBytes;
  FaceThresholds? lastThresholds;

  bool disposed = false;
  bool _initialized = false;

  FakeFaceEngine({
    FaceResult? result,
    this.delay = Duration.zero,
    this.modelVersion = FaceModels.modelVersion,
  }) : result = result ?? FaceResult.fail(FaceReasons.noFace, FaceQuality.none);

  /// Muvaffaqiyatli natija bilan tayyor dvigatel.
  factory FakeFaceEngine.success({
    Float32List? vector,
    Uint8List? jpeg,
    FaceQuality? quality,
  }) {
    Float32List v;
    if (vector != null) {
      v = vector;
    } else {
      v = Float32List(FaceModels.vectorLength);
      v[0] = 1;
    }
    return FakeFaceEngine(
      result: FaceResult.ok(
        FaceCapture(
          jpeg: jpeg ?? Uint8List(0),
          vector: l2Normalize(v),
          quality:
              quality ??
              const FaceQuality(
                faces: 1,
                faceRatio: 0.4,
                sharpness: 200,
                brightness: 130,
                yaw: 2,
                roll: 1,
              ),
        ),
      ),
    );
  }

  @override
  Future<void> init() async {
    if (disposed) throw StateError('FakeFaceEngine allaqachon yopilgan');
    if (_initialized) return;
    _initialized = true;
    initCount++;
  }

  @override
  Future<FaceResult> analyze(Uint8List imageBytes, FaceThresholds t) async {
    await init();
    analyzeCount++;
    lastBytes = imageBytes;
    lastThresholds = t;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }

  @override
  void dispose() {
    disposed = true;
    _initialized = false;
  }
}
