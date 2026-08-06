import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/models.dart';
import 'api_client.dart';

/// O'quvchi portali API — /api/student/* (studentPortal.ts bilan bir xil).
/// Rol: student (to'liq) / parent (o'qish + ba'zi amallar) / admin (?studentId= bilan o'qish).
///
/// BARCHA metodlar javobni uchta yordamchi orqali o'qiydi (`_obj` / `_arr` / `_void`),
/// shuning uchun himoya IZCHIL: server kutilmagan tana (`null`, HTML, massiv o'rniga
/// obyekt) yuborsa ham xom `TypeError` emas, tushunarli xato yoki bo'sh ro'yxat chiqadi.
class StudentApi {
  StudentApi._();

  static Map<String, dynamic>? _sid(String? studentId) => studentId != null ? {'studentId': studentId} : null;

  static Never _fail(Response res, [String? fallback]) {
    throw Exception(ApiClient.errorMessage(res, fallback));
  }

  /// OBYEKT javob: holat kodi + tana `Map` ekanini tekshiradi.
  /// Ilgari har metodda `res.data as Map` yozilardi — server 200 bilan HTML yoki
  /// `null` qaytarsa `TypeError` (Error!) chiqib, ekranlardagi `catch (e)` uni
  /// ushlamas va ilova qulardi.
  static T _obj<T>(Response res, T Function(Map<String, dynamic>) fromJson) {
    if (!ApiClient.ok(res)) _fail(res);
    final data = res.data;
    if (data is! Map) throw Exception('Server javobi noto\'g\'ri');
    return fromJson(data.cast<String, dynamic>());
  }

  /// RO'YXAT javob: tana `List` bo'lmasa (server `null` yoki obyekt yubordi) —
  /// bo'sh ro'yxat. Ro'yxat ichidagi begona elementlar e'tiborsiz qoldiriladi.
  static List<T> _arr<T>(Response res, T Function(Map<String, dynamic>) fromJson) {
    if (!ApiClient.ok(res)) _fail(res);
    final data = res.data;
    if (data is! List) return <T>[];
    return data.whereType<Map>().map((e) => fromJson(e.cast<String, dynamic>())).toList();
  }

  /// Javob tanasi kerak emas — faqat holat kodi tekshiriladi.
  static void _void(Response res) {
    if (!ApiClient.ok(res)) _fail(res);
  }

  /// Oddiy satrlar ro'yxati (ID'lar) — model yo'q.
  static List<String> _strArr(Response res) {
    if (!ApiClient.ok(res)) _fail(res);
    final data = res.data;
    if (data is! List) return <String>[];
    return data.map((e) => e.toString()).toList();
  }

  // ---------- Profil / auth / meta ----------
  static Future<StudentProfile> me({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/me', queryParameters: _sid(studentId)), StudentProfile.fromJson);

  static Future<UserSettings> settings({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/settings', queryParameters: _sid(studentId)), UserSettings.fromJson);

  static Future<UserSettings> saveSettings(Map<String, dynamic> body) async =>
      _obj(await ApiClient.dio.put('/student/settings', data: body), UserSettings.fromJson);

  static Future<void> changePassword(String currentPassword, String newPassword) async => _void(
        await ApiClient.dio.put('/student/password', data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

  static Future<PortalMeta> meta() async =>
      _obj(await ApiClient.dio.get('/student/meta'), PortalMeta.fromJson);

  static Future<StudentSchoolInfo> school() async =>
      _obj(await ApiClient.dio.get('/student/school'), StudentSchoolInfo.fromJson);

  // ---------- Uy joylashuvi ----------
  static Future<StudentLocation> location({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/location', queryParameters: _sid(studentId)), StudentLocation.fromJson);

  static Future<void> updateLocation(double latitude, double longitude, {String? address}) async => _void(
        await ApiClient.dio.put('/student/location', data: {
          'latitude': latitude,
          'longitude': longitude,
          'address': address ?? '',
        }),
      );

  static Future<TelegramStatus> telegram({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/telegram', queryParameters: _sid(studentId)), TelegramStatus.fromJson);

  // ---------- O'quv dasturi (curriculum roadmap) ----------
  static Future<List<StudentCurriculum>> curriculum({String? studentId}) async => _arr(
        await ApiClient.dio.get('/student/curriculum', queryParameters: _sid(studentId)),
        StudentCurriculum.fromJson,
      );

  static Future<LessonContent> lesson(String itemId, {String? studentId}) async => _obj(
        await ApiClient.dio.get('/student/curriculum/item/$itemId', queryParameters: _sid(studentId)),
        LessonContent.fromJson,
      );

  static Future<List<String>> courseProgress(String courseId, {String? studentId}) async => _strArr(
        await ApiClient.dio.get('/student/curriculum/$courseId/progress', queryParameters: _sid(studentId)),
      );

  static Future<void> setCourseProgress(String itemId, bool done, {String? studentId}) async => _void(
        await ApiClient.dio.post(
          '/student/curriculum/progress',
          data: {'itemId': itemId, 'done': done},
          queryParameters: _sid(studentId),
        ),
      );

  // ---------- Baholash statistikasi ----------
  static Future<List<StudentGradingGroup>> grading({String? month, String? studentId}) async => _arr(
        await ApiClient.dio.get('/student/grading', queryParameters: {
          ...?_sid(studentId),
          if (month != null) 'month': month,
        }),
        StudentGradingGroup.fromJson,
      );

  // ---------- Guruhlar ----------
  /// O'quvchining guruhlari — faol ham, tugagan/chiqilgan ham (`state` bilan).
  /// Manba: `StudentGroup` a'zoliklari; yozuv umuman bo'lmasa server `ClassName` bo'yicha
  /// guruhni qaytaradi (eski bazalarda o'quvchi "guruhsiz" ko'rinib qolmasin).
  static Future<List<StudentGroupInfo>> groups({String? studentId}) async =>
      _arr(await ApiClient.dio.get('/student/groups', queryParameters: _sid(studentId)), StudentGroupInfo.fromJson);

  // ---------- Dashboard ----------
  static Future<StudentDashboard> dashboard({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/dashboard', queryParameters: _sid(studentId)), StudentDashboard.fromJson);

  // ---------- Academic ----------
  static Future<StudentGradesReport> grades({String? studentId}) async => _obj(
        await ApiClient.dio.get('/student/grades', queryParameters: _sid(studentId)),
        StudentGradesReport.fromJson,
      );

  static Future<StudentNotebook> notebook({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/notebook', queryParameters: _sid(studentId)), StudentNotebook.fromJson);

  static Future<StudentAttendanceFull> attendance({int quarter = 1, String? studentId}) async => _obj(
        await ApiClient.dio.get('/student/attendance', queryParameters: {'quarter': quarter, ...?_sid(studentId)}),
        StudentAttendanceFull.fromJson,
      );

  static Future<StudentRating> rating({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/rating', queryParameters: _sid(studentId)), StudentRating.fromJson);

  // ---------- Finance ----------
  static Future<StudentFinance> finance({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/finance', queryParameters: _sid(studentId)), StudentFinance.fromJson);

  // ---------- Chat ----------
  static Future<List<StudentChatMessage>> chat({String? since, String? studentId}) async => _arr(
        await ApiClient.dio.get('/student/chat', queryParameters: {
          if (since != null) 'since': since,
          ...?_sid(studentId),
        }),
        StudentChatMessage.fromJson,
      );

  static Future<StudentChatMessage> sendChat(String text) async =>
      _obj(await ApiClient.dio.post('/student/chat', data: {'text': text}), StudentChatMessage.fromJson);

  // ---------- Bildirishnomalar ----------
  static Future<NotificationsResponse> notifications() async =>
      _obj(await ApiClient.dio.get('/student/notifications'), NotificationsResponse.fromJson);

  static Future<void> markNotificationsRead() async =>
      _void(await ApiClient.dio.post('/student/notifications/read'));

  static Future<void> confirmNotification(String id) async =>
      _void(await ApiClient.dio.post('/student/notifications/$id/confirm'));

  /// Push qurilma tokenini serverga ro'yxatdan o'tkazadi.
  /// Endpoint `student` VA `parent` rollariga ochiq — ota-onaning qurilmasini
  /// farzandining akkauntiga server o'zi bog'laydi, shuning uchun ilova tomonda
  /// rolga qarab shart QO'YILMAYDI. Chaqiruvchi (PushService) xatoni yutadi.
  static Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
    String? appId,
  }) async =>
      _void(
        await ApiClient.dio.post('/student/notifications/register', data: {
          'token': token,
          'platform': platform,
          if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
          if (appId != null && appId.isNotEmpty) 'appId': appId,
        }),
      );

  /// Qurilma tokenini o'chiradi (logout). Server topilmasa ham 200 qaytaradi.
  static Future<void> unregisterDevice(String token) async => _void(
        await ApiClient.dio.delete('/student/notifications/register', queryParameters: {'token': token}),
      );

  // ---------- Sertifikatlar ----------
  static Future<List<StudentCertificateDto>> certificates() async =>
      _arr(await ApiClient.dio.get('/student/certificates'), StudentCertificateDto.fromJson);

  /// Sertifikat faylini baytlar ko'rinishida yuklab oladi.
  /// DIQQAT: endpoint token talab qiladi — uni brauzerda ochib bo'lmaydi (401),
  /// shuning uchun fayl shu klient orqali olinadi va qurilmaga saqlanadi.
  static Future<List<int>> certificateBytes(String id) async {
    final res = await ApiClient.dio.get<List<int>>(
      '/student/certificates/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    // `ResponseType.bytes` tufayli XATO javobi ham bayt bo'lib keladi va serverning
    // `message` i yo'qolardi (403 "limit tugadi" ham umumiy matn bo'lib chiqardi).
    if (!ApiClient.ok(res)) throw Exception(_bytesMessage(res.data) ?? "Sertifikatni yuklab bo'lmadi");
    return res.data ?? const <int>[];
  }

  /// Bayt javobdan serverning `message` matnini ajratadi (JSON bo'lmasa — `null`).
  static String? _bytesMessage(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map && decoded['message'] is String) {
        final m = (decoded['message'] as String).trim();
        if (m.isNotEmpty) return m;
      }
    } catch (_) {
      // PDF/rasm baytlari — matn emas, e'tiborsiz qoldiramiz.
    }
    return null;
  }

  // ---------- Feedback ----------
  static Future<void> sendFeedback(String type, String text, {List<int>? imageBytes, String? imageName}) async {
    final fd = FormData.fromMap({
      'type': type,
      'text': text,
      if (imageBytes != null) 'image': MultipartFile.fromBytes(imageBytes, filename: imageName ?? 'image.jpg'),
    });
    _void(await ApiClient.dio.post('/student/feedback', data: fd));
  }

  // ---------- AI tekshiruv (Writing / Speaking) ----------
  /// Bugungi holat: kalitlar tayyorligi + limit/premium/blok.
  static Future<AiCheckStatus> aiCheckStatus({String? studentId}) async => _obj(
        await ApiClient.dio.get('/student/ai-check/status', queryParameters: _sid(studentId)),
        AiCheckStatus.fromJson,
      );

  /// Tekshiruvlar tarixi (eng yangi birinchi).
  static Future<List<AiCheckListItem>> aiCheckHistory({String? studentId}) async => _arr(
        await ApiClient.dio.get('/student/ai-check/history', queryParameters: _sid(studentId)),
        AiCheckListItem.fromJson,
      );

  /// Bitta yozuv (to'liq — matn/ovoz/tahlil).
  static Future<AiCheck> aiCheckItem(String id, {String? studentId}) async => _obj(
        await ApiClient.dio.get('/student/ai-check/history/$id', queryParameters: _sid(studentId)),
        AiCheck.fromJson,
      );

  /// Writing — matn yuboriladi, Gemini tahlil qiladi.
  /// [taskType]: `ielts_task1` | `ielts_task2` (bo'sh bo'lsa umumiy baholash).
  static Future<AiCheck> aiCheckWriting(String text, {String? prompt, String? taskType}) async => _obj(
        await ApiClient.dio.post('/student/ai-check/writing', data: {
          'text': text,
          if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
          if (taskType != null && taskType.isNotEmpty) 'taskType': taskType,
        }),
        AiCheck.fromJson,
      );

  /// Speaking — WAV ovoz yuboriladi (Azure + Gemini).
  static Future<AiCheck> aiCheckSpeaking(List<int> wavBytes, {String? prompt, String? referenceText}) async {
    final fd = FormData.fromMap({
      'audio': MultipartFile.fromBytes(wavBytes, filename: 'speaking.wav'),
      if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      if (referenceText != null && referenceText.isNotEmpty) 'referenceText': referenceText,
    });
    return _obj(await ApiClient.dio.post('/student/ai-check/speaking', data: fd), AiCheck.fromJson);
  }

  // ---------- Dars topshirig'i urinishi ----------
  /// Dars bo'limi yakunlanganda natijani saqlaydi (har chaqiruv — yangi urinish).
  /// [section]: `exercise` | `test` | `view`. Xato YUTILADI — natija ko'rsatilishi bunga bog'liq emas.
  static Future<void> saveCourseAttempt({
    required String itemId,
    required String section,
    String? exerciseKind,
    required int correct,
    required int total,
    required int durationSec,
    List<AttemptAnswer>? answers,
  }) async {
    try {
      await ApiClient.dio.post('/student/curriculum/attempt', data: {
        'itemId': itemId,
        'section': section,
        if (exerciseKind != null && exerciseKind.isNotEmpty) 'exerciseKind': exerciseKind,
        'correct': correct,
        'total': total,
        'durationSec': durationSec,
        if (answers != null) 'answers': answers.map((a) => a.toJson()).toList(),
      });
    } catch (_) {
      // Natija ko'rsatilishi saqlanishga bog'liq emas.
    }
  }

  // ---------- Test natijalari (O'quv bo'limi testlari) ----------
  /// O'quvchining barcha test natijalari (sana desc, rank/total bilan).
  static Future<List<StudentTestResult>> testResults({String? studentId}) async => _arr(
        await ApiClient.dio.get('/student/test-results', queryParameters: _sid(studentId)),
        StudentTestResult.fromJson,
      );

  // ---------- Onlayn test (PDF savollar + javob kiritish) ----------
  /// O'quvchining faol guruhlaridagi onlayn testlar (yangisi tepada).
  static Future<List<OnlineTest>> onlineTests({String? studentId}) async =>
      _arr(await ApiClient.dio.get('/student/online-tests', queryParameters: _sid(studentId)), OnlineTest.fromJson);

  /// Bitta test tafsiloti (o'z javoblari, o'rni; javob kaliti faqat vaqt tugagach).
  static Future<OnlineTestDetail> onlineTest(String id, {String? studentId}) async => _obj(
        await ApiClient.dio.get('/student/online-tests/$id', queryParameters: _sid(studentId)),
        OnlineTestDetail.fromJson,
      );

  /// Javoblarni yuborish ("ABCDA…", javobsiz savol — '-'). Bir marta topshiriladi.
  static Future<OnlineTestDetail> submitOnlineTest(String id, String answers) async => _obj(
        await ApiClient.dio.post('/student/online-tests/$id/submit', data: {'answers': answers}),
        OnlineTestDetail.fromJson,
      );

  // ---------- Support (yordam darslari) ----------
  /// Bo'sh slotli support o'qituvchilar + o'quvchining o'z bronlari.
  static Future<StudentSupport> support({String? studentId}) async =>
      _obj(await ApiClient.dio.get('/student/support', queryParameters: _sid(studentId)), StudentSupport.fromJson);

  /// Bo'sh slotni bron qilish.
  static Future<void> bookSupportSlot(String id) async =>
      _void(await ApiClient.dio.post('/student/support/slots/$id/book'));

  /// O'z bronini bekor qilish.
  static Future<void> cancelSupportSlot(String id) async =>
      _void(await ApiClient.dio.post('/student/support/slots/$id/cancel'));

  // ---------- Shartnoma ----------
  /// O'quvchi/ota-ona bilan tuzilgan shartnomalarning elektron nusxalari (yangisi birinchi).
  static Future<List<ContractDoc>> contracts({String? studentId}) async =>
      _arr(await ApiClient.dio.get('/student/contracts', queryParameters: _sid(studentId)), ContractDoc.fromJson);

  /// Shartnoma PDF'ini baytlar ko'rinishida oladi.
  /// DIQQAT: `pdfUrl` ("/uploads/...") to'g'ridan-to'g'ri OCHILMAYDI — `/uploads`
  /// tokensiz 404 qaytaradi. Fayl faqat shu avtorizatsiyalangan endpointdan olinadi.
  static Future<List<int>> contractPdfBytes(String id, {String? studentId}) async {
    final res = await ApiClient.dio.get<List<int>>(
      '/student/contracts/$id/pdf',
      queryParameters: _sid(studentId),
      options: Options(responseType: ResponseType.bytes),
    );
    if (!ApiClient.ok(res)) throw Exception(_bytesMessage(res.data) ?? "Shartnomani yuklab bo'lmadi");
    return res.data ?? const <int>[];
  }
}
