import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// KAMERA — INTERFEYS ORTIDA.
///
/// NEGA: `flutter test` da haqiqiy kamera yo'q (platforma kanali javob bermaydi),
/// ya'ni yuz tekshiruvi ekranini kamerasiz sinab bo'lmasdi. Ekran faqat shu
/// interfeysni biladi, testda esa [FakeFaceCamera] oldindan tayyorlangan
/// kadrlarni beradi — `FakeFaceEngine` bilan bir xil yondashuv.
///
/// Kadr **kodlangan rasm baytlari** (JPEG) bo'lib qaytadi, chunki yuz dvigateli
/// (`FaceEngine.analyze`) aynan shuni kutadi.
abstract class FaceCamera {
  /// Kamerani ishga tushiradi (ruxsat so'raladi). Natija — nima bo'lganini
  /// ekranga tushuntirish uchun.
  Future<FaceCameraStatus> start();

  /// Kadr olishga tayyormi.
  bool get isReady;

  /// Jonli ko'rinish widgeti. Tayyor bo'lmasa bo'sh joy qaytarishi mumkin.
  Widget preview();

  /// Bitta kadr (JPEG). Olib bo'lmasa `null` — chaqiruvchi keyingi kadrni kutadi.
  Future<Uint8List?> frame();

  /// Resurslarni bo'shatadi. Bir necha marta chaqirilsa ham xavfsiz.
  Future<void> stop();
}

/// Kamerani ishga tushirish natijasi.
enum FaceCameraStatus {
  /// Tayyor — kadr olsa bo'ladi.
  ready,

  /// Foydalanuvchi ruxsat bermadi (lekin qayta so'rasa bo'ladi).
  denied,

  /// "Boshqa so'rama" — endi faqat tizim sozlamalaridan yoqiladi.
  permanentlyDenied,

  /// Kamera umuman yo'q yoki ishga tushmadi (emulyator, band qurilma).
  unavailable,
}

// ---------------------------------------------------------------------------
// Haqiqiy kamera
// ---------------------------------------------------------------------------

/// `camera` paketi ustidagi yupqa qatlam.
///
/// ⚠️ KADR OLISH USULI — `takePicture()`, tasvir OQIMI (`startImageStream`) EMAS.
/// Sabab: oqim xom YUV/BGRA kadr beradi, dvigatel esa kodlangan rasm kutadi;
/// xom kadrni o'zimiz JPEG qilsak, kameraning BURILISHINI (sensor orientatsiyasi
/// old kamerada 270°) ham qo'lda hisoblashga to'g'ri kelardi — noto'g'ri burchak
/// esa yuzni topilmaydigan qiladi va yaw ISHORASINI teskari o'girib, "chapga
/// buring" ni buzardi. `takePicture()` faylni to'g'ri burilgan holda yozadi.
class DeviceFaceCamera implements FaceCamera {
  /// Kadr o'lchami: `medium` (~480-720p) — yuz o'lchash uchun yetarli, lekin
  /// `high` dan sezilarli tez (har kadrda ~2 baravar kam bayt kodlanadi).
  final ResolutionPreset resolution;

  CameraController? _controller;
  bool _stopped = false;

  DeviceFaceCamera({this.resolution = ResolutionPreset.medium});

  @override
  bool get isReady => _controller?.value.isInitialized == true && !_stopped;

  @override
  Future<FaceCameraStatus> start() async {
    _stopped = false;

    // 1) Ruxsat. `camera` paketi ham so'raydi, lekin u "rad etildi" bilan
    //    "boshqa so'rama" ni AJRATMAYDI — foydalanuvchiga esa aynan shu farq
    //    kerak (qayta so'raymizmi yoki sozlamalarga yuboramizmi).
    try {
      var st = await Permission.camera.status;
      if (!st.isGranted) st = await Permission.camera.request();
      if (st.isPermanentlyDenied || st.isRestricted) {
        return FaceCameraStatus.permanentlyDenied;
      }
      if (!st.isGranted) return FaceCameraStatus.denied;
    } catch (e) {
      // Ruxsat qatlami ishlamasa (masalan qo'llab-quvvatlanmagan platforma)
      // to'xtab qolmaymiz — kameraning o'zi baribir ruxsat so'raydi.
      debugPrint('FaceCamera: ruxsat tekshiruvi ishlamadi — $e');
    }

    // 2) Old kamera.
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return FaceCameraStatus.unavailable;
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(front, resolution, enableAudio: false);
      await ctrl.initialize();
      // Ilova ekrandan ketgan bo'lsa (foydalanuvchi orqaga bosdi) — bo'shatamiz.
      if (_stopped) {
        await ctrl.dispose();
        return FaceCameraStatus.unavailable;
      }
      _controller = ctrl;
      // Selfida chaqnash kerak emas; qo'llab-quvvatlanmasa jim o'tamiz.
      try {
        await ctrl.setFlashMode(FlashMode.off);
      } catch (_) {}
      return FaceCameraStatus.ready;
    } on CameraException catch (e) {
      debugPrint('FaceCamera: ${e.code} ${e.description}');
      final code = e.code.toLowerCase();
      if (code.contains('denied') || code.contains('permission')) {
        // iOS'da "boshqa so'rama" shu kod bilan keladi.
        return code.contains('withoutprompt') || code.contains('restricted')
            ? FaceCameraStatus.permanentlyDenied
            : FaceCameraStatus.denied;
      }
      return FaceCameraStatus.unavailable;
    } catch (e) {
      debugPrint('FaceCamera: ishga tushmadi — $e');
      return FaceCameraStatus.unavailable;
    }
  }

  @override
  Widget preview() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return const SizedBox.shrink();
    // Ekranda kadr KVADRAT doira ichida ko'rsatiladi. Yalang'och `CameraPreview`
    // tor-tiqilinch (tight) o'lchamga tushib qolsa rasmni CHO'ZADI — yuz keng
    // bo'lib ko'rinadi va foydalanuvchi masofani noto'g'ri tanlaydi. Shu sabab
    // kadrning haqiqiy nisbati saqlanib, ortiqchasi kesiladi ("cover").
    //
    // ⚠️ `previewSize` LANDSCAPE tartibida keladi (kenglik/balandlik almashgan) —
    // portret ko'rinish uchun ular almashtiriladi. Nisbat noma'lum bo'lsa
    // odatdagi ko'rinishga qaytamiz.
    final size = ctrl.value.previewSize;
    if (size == null || size.width <= 0 || size.height <= 0) {
      return CameraPreview(ctrl);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(ctrl),
      ),
    );
  }

  @override
  Future<Uint8List?> frame() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _stopped) return null;
    // Oldingi kadr hali qaytmagan bo'lsa `takePicture` istisno tashlaydi —
    // navbat kutamiz (chaqiruvchi keyingi aylanishda qayta so'raydi).
    if (ctrl.value.isTakingPicture) return null;
    XFile? shot;
    try {
      shot = await ctrl.takePicture();
      return await shot.readAsBytes();
    } catch (e) {
      debugPrint('FaceCamera.frame: $e');
      return null;
    } finally {
      // ⚠️ Har kadr vaqtinchalik FAYL yaratadi. Tozalanmasa tekshiruv davomida
      // o'nlab surat keshda qolib ketardi (va ular — foydalanuvchining yuzi).
      if (shot != null) {
        try {
          final f = File(shot.path);
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    final ctrl = _controller;
    _controller = null;
    if (ctrl == null) return;
    try {
      await ctrl.dispose();
    } catch (e) {
      debugPrint('FaceCamera.stop: $e');
    }
  }

  /// Tizim sozlamalarini ochadi — ruxsat "boshqa so'rama" bo'lganda yagona yo'l.
  static Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('FaceCamera.openSettings: $e');
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Testlar uchun soxta kamera
// ---------------------------------------------------------------------------

/// Kamera YO'Q — oldindan berilgan baytlarni qaytaradi (`FakeFaceEngine` kabi).
class FakeFaceCamera implements FaceCamera {
  /// `start()` nima qaytarsin.
  FaceCameraStatus status;

  /// Har `frame()` chaqiruvida qaytariladigan baytlar.
  Uint8List bytes;

  /// `frame()` `null` qaytarsin (kadr olinmayapti holatini sinash uchun).
  bool frameFails = false;

  /// Har `frame()` da chaqiriladi — testda "vaqt o'tdi" deb soatni surish yoki
  /// keyingi kadr sifatini o'zgartirish uchun.
  void Function(int frameIndex)? onFrame;

  int startCount = 0;
  int frameCount = 0;
  int stopCount = 0;

  FakeFaceCamera({
    this.status = FaceCameraStatus.ready,
    Uint8List? bytes,
  }) : bytes = bytes ?? Uint8List.fromList(const [1, 2, 3, 4]);

  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<FaceCameraStatus> start() async {
    startCount++;
    _ready = status == FaceCameraStatus.ready;
    return status;
  }

  @override
  Widget preview() => const SizedBox.expand();

  @override
  Future<Uint8List?> frame() async {
    if (!_ready) return null;
    onFrame?.call(frameCount);
    frameCount++;
    return frameFails ? null : bytes;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _ready = false;
  }
}
