import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/face/face_detector.dart';
import 'package:student/face/face_engine.dart';

/// HAQIQIY MODEL fayllari ustidagi tekshiruv.
///
/// ⚠️ NEGA "inference" testi yo'q: `flutter_onnxruntime` — platforma plagini,
/// uning native tomoni `flutter test` (Dart VM) ichida umuman yuklanmaydi.
/// Shuning uchun bu yerda modelning O'ZI tekshiriladi (bor-yo'qligi, bayt-baytiga
/// mos kelishi va grafikdagi tenzor nomlari koddagi konstantalar bilan bir xilligi),
/// quvurning qolgan qismi esa `face_engine_test.dart` da soxta runner bilan
/// to'liq o'tadi. Haqiqiy inference — qurilmadagi qo'lda sinov.
///
/// Model fayli bo'lmasa (masalan CI'ga assets yuklanmagan) testlar `skip`
/// bilan o'tkazib yuboriladi — quvurni yiqitmaydi.
void main() {
  final detector = File(FaceModels.detectorAsset);
  final recognizer = File(FaceModels.recognizerAsset);
  final have = detector.existsSync() && recognizer.existsSync();
  final skip = have ? null : 'Model fayllari yo\'q: ${FaceModels.detectorAsset}';

  group('modellar joyida va butun', () {
    test('YuNet: o\'lcham va sha256 (manba: assets/models/README.md)', () {
      final bytes = detector.readAsBytesSync();
      expect(bytes.length, 232589, reason: 'fayl almashib ketgan yoki kesilgan');
      expect(
        sha256.convert(bytes).toString(),
        '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
      );
    }, skip: skip);

    test('SFace int8: o\'lcham va sha256', () {
      final bytes = recognizer.readAsBytesSync();
      expect(bytes.length, 9896933);
      expect(
        sha256.convert(bytes).toString(),
        '2b0e941e6f16cc048c20aee0c8e31f569118f65d702914540f7bfdc14048d78a',
      );
    }, skip: skip);

    test('bundlanadigan hajm 15 MB dan oshmaydi', () {
      final total = detector.lengthSync() + recognizer.lengthSync();
      expect(total, lessThan(15 * 1024 * 1024));
    }, skip: skip);

    test('Git LFS ko\'rsatkichi emas (haqiqiy ONNX)', () {
      // LFS pointer — kichkina matn fayl; ONNX esa protobuf.
      final head = detector.openRead(0, 64).first;
      expect(detector.lengthSync(), greaterThan(100000));
      expect(
        head.then((b) => utf8.decode(b, allowMalformed: true)),
        completion(isNot(contains('git-lfs'))),
      );
    }, skip: skip);
  });

  group('koddagi tenzor nomlari MODELDAGI nomlar bilan bir xil', () {
    // ONNX protobuf ichida tenzor nomlari oddiy UTF-8 satr bo'lib yotadi.
    bool contains(File f, String name) {
      final bytes = f.readAsBytesSync();
      final needle = utf8.encode(name);
      outer:
      for (var i = 0; i + needle.length <= bytes.length; i++) {
        for (var j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) continue outer;
        }
        return true;
      }
      return false;
    }

    test('YuNet kirishi "${YuNet.inputName}"', () {
      expect(contains(detector, YuNet.inputName), isTrue);
    }, skip: skip);

    test('YuNet 12 ta chiqishi (cls/obj/bbox/kps × 8/16/32)', () {
      for (final s in YuNet.strides) {
        for (final p in const ['cls', 'obj', 'bbox', 'kps']) {
          expect(contains(detector, '${p}_$s'), isTrue, reason: '${p}_$s topilmadi');
        }
      }
    }, skip: skip);

    test('SFace kirish/chiqish nomlari', () {
      expect(contains(recognizer, FaceModels.recognizerInputName), isTrue);
      expect(contains(recognizer, FaceModels.recognizerOutputName), isTrue);
    }, skip: skip);
  });

  group('konfiguratsiya', () {
    test('pubspec assetlari ro\'yxatdan o\'tgan', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains(FaceModels.detectorAsset));
      expect(pubspec, contains(FaceModels.recognizerAsset));
    });

    test('modelVersion bo\'sh emas va model turini bildiradi', () {
      expect(FaceModels.modelVersion.trim(), isNotEmpty);
      expect(FaceModels.modelVersion, contains('sface'));
      // Serverda kalit sifatida ishlatiladi — probel/registr o'yinlari bo'lmasin.
      expect(FaceModels.modelVersion, matches(RegExp(r'^[a-z0-9.\-]+$')));
    });

    test('assets/models/README.md da manba va litsenziya yozilgan', () {
      final readme = File('assets/models/README.md');
      expect(readme.existsSync(), isTrue);
      final text = readme.readAsStringSync();
      expect(text, contains('MIT'));
      expect(text, contains('Apache'));
      expect(text, contains('opencv_zoo'));
      // sha256 testdagilar bilan bir xil bo'lsin.
      expect(
        text,
        contains('8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4'),
      );
      expect(
        text,
        contains('2b0e941e6f16cc048c20aee0c8e31f569118f65d702914540f7bfdc14048d78a'),
      );
    });
  });
}
