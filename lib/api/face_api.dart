import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../face/face_engine.dart' show FaceThresholds;
import '../services/face_liveness.dart';
import 'api_client.dart';

/// YUZ BILAN TASDIQLASH API — `/api/student/face/*`.
///
/// Bu to'rtta endpoint **cheklangan token** (login javobidagi `faceRequired`
/// tokeni, 15 daqiqa) bilan ham ishlaydi; qolgan hamma so'rov 401 qaytaradi.
///
/// `StudentApi` bilan bir xil siyosat: server kutilmagan tana yuborsa ham xom
/// `TypeError` emas, tushunarli xato yoki zaxira qiymat chiqadi.
class FaceApi {
  FaceApi._();

  static Never _fail(Response res, [String? fallback]) {
    throw Exception(ApiClient.errorMessage(res, fallback));
  }

  static Map<String, dynamic> _map(Response res) {
    if (!ApiClient.ok(res)) _fail(res);
    final data = res.data;
    if (data is! Map) throw Exception("Server javobi noto'g'ri");
    return data.cast<String, dynamic>();
  }

  /// Chegaralar, holat va urinishlar soni.
  static Future<FaceStatusInfo> status() async =>
      FaceStatusInfo.fromJson(_map(await ApiClient.dio.get('/student/face/status')));

  /// Tiriklik topshirig'i: nonce + TARTIBLANGAN harakatlar (bir marta ishlatiladi).
  static Future<FaceChallengeInfo> challenge() async =>
      FaceChallengeInfo.fromJson(_map(await ApiClient.dio.post('/student/face/challenge')));

  /// O'quvchining PROFIL rasmi (etalon vektorni shundan hisoblaymiz).
  ///
  /// Rasm yo'q bo'lsa server 404 beradi — bu XATO EMAS, shuning uchun `null`
  /// qaytadi va chaqiruvchi `refVector` siz davom etadi.
  static Future<Uint8List?> photo() async {
    final res = await ApiClient.dio.get<List<int>>(
      '/student/face/photo',
      options: Options(responseType: ResponseType.bytes),
    );
    if (!ApiClient.ok(res)) return null;
    final data = res.data;
    if (data == null || data.isEmpty) return null;
    return Uint8List.fromList(data);
  }

  /// Selfini tekshirishga yuboradi (multipart).
  ///
  /// ⚠️ Fayl nomi `.jpg` bilan tugashi SHART — server aynan kengaytmaga qaraydi.
  /// ⚠️ Rad etish ham, "kutilmoqda" ham HTTP **200** bilan keladi; 400 faqat
  ///    texnik xato (bo'sh vektor, 2 MB dan katta rasm) degani.
  static Future<FaceVerifyResult> verify({
    required Uint8List jpeg,
    required String vector,
    String? refVector,
    required String qualityJson,
    required String nonce,
    required List<LivenessStep> liveness,
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required String modelVersion,
    String? integrityToken,
  }) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(jpeg, filename: 'selfie.jpg'),
      'vector': vector,
      if (refVector != null && refVector.isNotEmpty) 'refVector': refVector,
      'quality': qualityJson,
      if (nonce.isNotEmpty) 'nonce': nonce,
      if (nonce.isNotEmpty) 'liveness': Liveness.toJsonString(liveness),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'appVersion': appVersion,
      'modelVersion': modelVersion,
      if (integrityToken != null && integrityToken.isNotEmpty)
        'integrityToken': integrityToken,
    });
    final res = await ApiClient.dio.post('/student/face/verify', data: form);
    return FaceVerifyResult.fromJson(_map(res));
  }
}

// ---------------------------------------------------------------------------
// Javob modellari
// ---------------------------------------------------------------------------

double _d(dynamic v, double dflt) {
  if (v is num) return v.toDouble().isFinite ? v.toDouble() : dflt;
  if (v is String) {
    final p = double.tryParse(v.trim());
    if (p != null && p.isFinite) return p;
  }
  return dflt;
}

int _i(dynamic v, int dflt) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? dflt;
  return dflt;
}

bool _b(dynamic v, {bool dflt = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.trim().toLowerCase() == 'true';
  return dflt;
}

String _s(dynamic v) => v is String ? v : (v == null ? '' : v.toString());

/// `GET /student/face/status`.
class FaceStatusInfo {
  /// Modul markazda yoqilganmi. `false` bo'lsa tekshiruvning ma'nosi yo'q.
  final bool enabled;

  /// Etalon (shablon) allaqachon saqlanganmi. `false` — birinchi marta,
  /// ya'ni profil rasmidan `refVector` hisoblash kerak.
  final bool enrolled;

  /// Profilda rasm bormi (etalon hisoblash mumkinmi).
  final bool hasPhoto;

  /// Server kutayotgan model versiyasi (bo'sh — tekshirilmaydi).
  final String modelVersion;

  /// Kosinus chegarasi — FAQAT ko'rsatish uchun, qaror serverda.
  final double threshold;

  /// Shu soatda qolgan urinishlar.
  final int attemptsLeft;

  /// Selfi sifati chegaralari (dvigatelga beriladi).
  final FaceThresholds quality;

  /// Tiriklik harakatlari majburiymi.
  final bool requireLiveness;

  const FaceStatusInfo({
    required this.enabled,
    required this.enrolled,
    required this.hasPhoto,
    required this.modelVersion,
    required this.threshold,
    required this.attemptsLeft,
    required this.quality,
    required this.requireLiveness,
  });

  factory FaceStatusInfo.fromJson(Map<String, dynamic> j) {
    final q = j['quality'];
    return FaceStatusInfo(
      enabled: _b(j['enabled'], dflt: true),
      enrolled: _b(j['enrolled']),
      hasPhoto: _b(j['hasPhoto']),
      modelVersion: _s(j['modelVersion']),
      threshold: _d(j['threshold'], 0.6),
      attemptsLeft: _i(j['attemptsLeft'], 0),
      // Chegaralar SERVERDA turadi (kalibrlash uchun ilovani qayta chiqarish
      // shart bo'lmasin) — buzuq maydon bo'lsa dvigatelning zaxirasi olinadi.
      quality: FaceThresholds.fromJson(q is Map ? q.cast<String, dynamic>() : null),
      requireLiveness: _b(j['requireLiveness'], dflt: true),
    );
  }
}

/// `POST /student/face/challenge`.
class FaceChallengeInfo {
  final String nonce;

  /// Bajarilishi kerak bo'lgan harakatlar — TARTIB muhim.
  final List<String> actions;

  /// Nonce necha soniya yaroqli.
  final int ttlSeconds;

  const FaceChallengeInfo({
    required this.nonce,
    required this.actions,
    required this.ttlSeconds,
  });

  factory FaceChallengeInfo.fromJson(Map<String, dynamic> j) {
    final raw = j['actions'];
    final actions = raw is List
        ? raw.map(_s).where((a) => a.isNotEmpty).toList()
        : <String>[];
    return FaceChallengeInfo(
      nonce: _s(j['nonce']),
      actions: actions,
      // Server 90 soniya beradi; javobda bo'lmasa ham xavfsiz qiymat.
      ttlSeconds: _i(j['ttlSeconds'], 90).clamp(10, 600),
    );
  }
}

/// `POST /student/face/verify`.
class FaceVerifyResult {
  final bool ok;

  /// `approved` | `rejected` | `pending`.
  final String status;

  /// Rad etilgan bo'lsa — foydalanuvchiga ko'rsatiladigan o'zbekcha sabab.
  final String reason;

  /// Kosinus (solishtiruv bo'lgan bo'lsa).
  final double? score;

  final int attemptsLeft;

  /// TO'LIQ token — faqat `ok:true` da keladi.
  final String? token;

  /// Shu selfi etalon sifatida saqlandimi.
  final bool enrolled;

  const FaceVerifyResult({
    required this.ok,
    required this.status,
    required this.reason,
    required this.score,
    required this.attemptsLeft,
    required this.token,
    required this.enrolled,
  });

  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusPending = 'pending';

  bool get isPending => status == statusPending;

  factory FaceVerifyResult.fromJson(Map<String, dynamic> j) {
    final t = j['token'];
    return FaceVerifyResult(
      ok: _b(j['ok']),
      status: _s(j['status']).trim().toLowerCase(),
      reason: _s(j['reason']).trim(),
      score: j['score'] is num ? (j['score'] as num).toDouble() : null,
      attemptsLeft: _i(j['attemptsLeft'], 0),
      token: t is String && t.isNotEmpty ? t : null,
      enrolled: _b(j['enrolled']),
    );
  }
}

/// Sifat o'lchovlarini serverga yuboriladigan JSON satrga aylantiradi.
///
/// ⚠️ Kalitlar SERVERDA registrga sezgir o'qiladi (`faces`, `sharpness`,
/// `brightness`, `faceRatio`, `yaw`, `roll`) — `FaceQuality.toJson` aynan
/// shularni beradi, shuning uchun bu yerda faqat `jsonEncode` qilinadi.
String qualityToJson(Map<String, dynamic> quality) => jsonEncode(quality);
