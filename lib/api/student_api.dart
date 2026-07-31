import 'package:dio/dio.dart';
import '../models/models.dart';
import 'api_client.dart';

/// O'quvchi portali API — /api/student/* (studentPortal.ts bilan bir xil).
/// Rol: student (to'liq) / parent (o'qish + ba'zi amallar) / admin (?studentId= bilan o'qish).
class StudentApi {
  StudentApi._();

  static Map<String, dynamic>? _sid(String? studentId) => studentId != null ? {'studentId': studentId} : null;

  static Never _fail(Response res, [String? fallback]) {
    throw Exception(ApiClient.errorMessage(res, fallback));
  }

  // ---------- Profil / auth / meta ----------
  static Future<StudentProfile> me({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/me', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentProfile.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<UserSettings> settings({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/settings', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return UserSettings.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<UserSettings> saveSettings(Map<String, dynamic> body) async {
    final res = await ApiClient.dio.put('/student/settings', data: body);
    if (!ApiClient.ok(res)) _fail(res);
    return UserSettings.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await ApiClient.dio.put('/student/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (!ApiClient.ok(res)) _fail(res);
  }

  static Future<PortalMeta> meta() async {
    final res = await ApiClient.dio.get('/student/meta');
    if (!ApiClient.ok(res)) _fail(res);
    return PortalMeta.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<StudentSchoolInfo> school() async {
    final res = await ApiClient.dio.get('/student/school');
    if (!ApiClient.ok(res)) _fail(res);
    return StudentSchoolInfo.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- Uy joylashuvi ----------
  static Future<StudentLocation> location({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/location', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentLocation.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<void> updateLocation(double latitude, double longitude, {String? address}) async {
    final res = await ApiClient.dio.put('/student/location', data: {
      'latitude': latitude,
      'longitude': longitude,
      'address': address ?? '',
    });
    if (!ApiClient.ok(res)) _fail(res);
  }

  static Future<TelegramStatus> telegram({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/telegram', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return TelegramStatus.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- O'quv dasturi (curriculum roadmap) ----------
  static Future<List<StudentCurriculum>> curriculum({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/curriculum', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List).map((e) => StudentCurriculum.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  static Future<LessonContent> lesson(String itemId, {String? studentId}) async {
    final res = await ApiClient.dio.get('/student/curriculum/item/$itemId', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return LessonContent.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<List<String>> courseProgress(String courseId, {String? studentId}) async {
    final res = await ApiClient.dio.get('/student/curriculum/$courseId/progress', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List? ?? []).map((e) => e.toString()).toList();
  }

  static Future<void> setCourseProgress(String itemId, bool done, {String? studentId}) async {
    final res = await ApiClient.dio.post(
      '/student/curriculum/progress',
      data: {'itemId': itemId, 'done': done},
      queryParameters: _sid(studentId),
    );
    if (!ApiClient.ok(res)) _fail(res);
  }

  // ---------- Baholash statistikasi ----------
  static Future<List<StudentGradingGroup>> grading({String? month, String? studentId}) async {
    final res = await ApiClient.dio.get('/student/grading', queryParameters: {
      ...?_sid(studentId),
      if (month != null) 'month': month,
    });
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List).map((e) => StudentGradingGroup.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  // ---------- Dashboard ----------
  static Future<StudentDashboard> dashboard({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/dashboard', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentDashboard.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- Academic ----------
  static Future<StudentGradesReport> grades({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/grades', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentGradesReport.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<StudentNotebook> notebook({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/notebook', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentNotebook.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<StudentAttendanceFull> attendance({int quarter = 1, String? studentId}) async {
    final res = await ApiClient.dio.get('/student/attendance', queryParameters: {
      'quarter': quarter,
      ...?_sid(studentId),
    });
    if (!ApiClient.ok(res)) _fail(res);
    return StudentAttendanceFull.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<StudentDiscipline> discipline({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/discipline', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentDiscipline.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<StudentRating> rating({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/rating', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentRating.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<StudentSubjectsProgress> subjectsProgress({int quarter = 1, String? studentId}) async {
    final res = await ApiClient.dio.get('/student/subjects-progress', queryParameters: {
      'quarter': quarter,
      ...?_sid(studentId),
    });
    if (!ApiClient.ok(res)) _fail(res);
    return StudentSubjectsProgress.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<SubjectProgressDetail> subjectProgressDetail(
    String subjectId, {
    int quarter = 1,
    String? studentId,
  }) async {
    final res = await ApiClient.dio.get('/student/subjects-progress/$subjectId', queryParameters: {
      'quarter': quarter,
      ...?_sid(studentId),
    });
    if (!ApiClient.ok(res)) _fail(res);
    return SubjectProgressDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- Assignments ----------
  static Future<List<StudentAssignment>> assignments({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/assignments', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List).map((e) => StudentAssignment.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  static Future<StudentAssignmentDetail> assignment(String id, {String? studentId}) async {
    final res = await ApiClient.dio.get('/student/assignments/$id', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentAssignmentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<StudentAssignmentScores> assignmentScores({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/assignment-scores', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentAssignmentScores.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<SubmitResult> submitAssignment(
    String id, {
    List<TestAnswer>? answers,
    String? answerText,
    String? fileUrl,
  }) async {
    final res = await ApiClient.dio.post('/student/assignments/$id/submit', data: {
      if (answers != null) 'answers': answers.map((a) => a.toJson()).toList(),
      if (answerText != null) 'answerText': answerText,
      if (fileUrl != null) 'fileUrl': fileUrl,
    });
    if (!ApiClient.ok(res)) _fail(res);
    return SubmitResult.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<UploadedFile> uploadFile(
    List<int> bytes,
    String filename, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fd = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)});
    final res = await ApiClient.dio.post(
      '/student/uploads',
      data: fd,
      onSendProgress: onProgress,
    );
    if (!ApiClient.ok(res)) _fail(res);
    return UploadedFile.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- Finance ----------
  static Future<StudentFinance> finance({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/finance', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentFinance.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- Chat ----------
  static Future<List<StudentChatMessage>> chat({String? since, String? studentId}) async {
    final res = await ApiClient.dio.get('/student/chat', queryParameters: {
      if (since != null) 'since': since,
      ...?_sid(studentId),
    });
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List).map((e) => StudentChatMessage.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  static Future<StudentChatMessage> sendChat(String text) async {
    final res = await ApiClient.dio.post('/student/chat', data: {'text': text});
    if (!ApiClient.ok(res)) _fail(res);
    return StudentChatMessage.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- Bildirishnomalar ----------
  static Future<NotificationsResponse> notifications() async {
    final res = await ApiClient.dio.get('/student/notifications');
    if (!ApiClient.ok(res)) _fail(res);
    return NotificationsResponse.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<void> markNotificationsRead() async {
    final res = await ApiClient.dio.post('/student/notifications/read');
    if (!ApiClient.ok(res)) _fail(res);
  }

  static Future<void> confirmNotification(String id) async {
    final res = await ApiClient.dio.post('/student/notifications/$id/confirm');
    if (!ApiClient.ok(res)) _fail(res);
  }

  // ---------- Sertifikatlar ----------
  static Future<List<StudentCertificateDto>> certificates() async {
    final res = await ApiClient.dio.get('/student/certificates');
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List)
        .map((e) => StudentCertificateDto.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---------- Speaking (Azure talaffuz bahosi) ----------
  /// Audio (WAV) yuborib, Azure talaffuz bahosini olish (natija saqlanadi).
  static Future<SpeakingResult> submitSpeaking(String assignmentId, List<int> wavBytes) async {
    final fd = FormData.fromMap({
      'audio': MultipartFile.fromBytes(wavBytes, filename: 'speaking.wav'),
    });
    final res = await ApiClient.dio.post('/student/assignments/$assignmentId/speaking', data: fd);
    if (!ApiClient.ok(res)) _fail(res);
    return SpeakingResult.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Oldingi speaking natijasi (bor bo'lsa) — 204 bo'lsa null.
  static Future<SpeakingResult?> speaking(String assignmentId, {String? studentId}) async {
    final res = await ApiClient.dio.get('/student/assignments/$assignmentId/speaking', queryParameters: _sid(studentId));
    if (res.statusCode == 204 || res.data == null) return null;
    if (!ApiClient.ok(res)) _fail(res);
    return SpeakingResult.fromJson((res.data as Map).cast<String, dynamic>());
  }

  // ---------- Feedback ----------
  static Future<void> sendFeedback(
    String type,
    String text, {
    List<int>? imageBytes,
    String? imageName,
  }) async {
    final fd = FormData.fromMap({
      'type': type,
      'text': text,
      if (imageBytes != null) 'image': MultipartFile.fromBytes(imageBytes, filename: imageName ?? 'image.jpg'),
    });
    final res = await ApiClient.dio.post('/student/feedback', data: fd);
    if (!ApiClient.ok(res)) _fail(res);
  }

  // ---------- AI tekshiruv (Writing / Speaking) ----------
  /// Bugungi holat: kalitlar tayyorligi + limit/premium/blok.
  static Future<AiCheckStatus> aiCheckStatus({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/ai-check/status', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return AiCheckStatus.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Tekshiruvlar tarixi (eng yangi birinchi).
  static Future<List<AiCheckListItem>> aiCheckHistory({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/ai-check/history', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List)
        .map((e) => AiCheckListItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Bitta yozuv (to'liq — matn/ovoz/tahlil).
  static Future<AiCheck> aiCheckItem(String id, {String? studentId}) async {
    final res = await ApiClient.dio.get('/student/ai-check/history/$id', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return AiCheck.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Writing — matn yuboriladi, Gemini tahlil qiladi.
  /// [taskType]: `ielts_task1` | `ielts_task2` (bo'sh bo'lsa umumiy baholash).
  static Future<AiCheck> aiCheckWriting(String text, {String? prompt, String? taskType}) async {
    final res = await ApiClient.dio.post('/student/ai-check/writing', data: {
      'text': text,
      if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      if (taskType != null && taskType.isNotEmpty) 'taskType': taskType,
    });
    if (!ApiClient.ok(res)) _fail(res);
    return AiCheck.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Speaking — WAV ovoz yuboriladi (Azure + Gemini).
  static Future<AiCheck> aiCheckSpeaking(List<int> wavBytes, {String? prompt, String? referenceText}) async {
    final fd = FormData.fromMap({
      'audio': MultipartFile.fromBytes(wavBytes, filename: 'speaking.wav'),
      if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      if (referenceText != null && referenceText.isNotEmpty) 'referenceText': referenceText,
    });
    final res = await ApiClient.dio.post('/student/ai-check/speaking', data: fd);
    if (!ApiClient.ok(res)) _fail(res);
    return AiCheck.fromJson((res.data as Map).cast<String, dynamic>());
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
  static Future<List<StudentTestResult>> testResults({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/test-results', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return (res.data as List)
        .map((e) => StudentTestResult.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---------- Support (yordam darslari) ----------
  /// Bo'sh slotli support o'qituvchilar + o'quvchining o'z bronlari.
  static Future<StudentSupport> support({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/support', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    return StudentSupport.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Bo'sh slotni bron qilish.
  static Future<void> bookSupportSlot(String id) async {
    final res = await ApiClient.dio.post('/student/support/slots/$id/book');
    if (!ApiClient.ok(res)) _fail(res);
  }

  /// O'z bronini bekor qilish.
  static Future<void> cancelSupportSlot(String id) async {
    final res = await ApiClient.dio.post('/student/support/slots/$id/cancel');
    if (!ApiClient.ok(res)) _fail(res);
  }

  // ---------- Shartnoma ----------
  /// O'quvchi/ota-ona bilan tuzilgan shartnomalarning elektron nusxalari (yangisi birinchi).
  static Future<List<ContractDoc>> contracts({String? studentId}) async {
    final res = await ApiClient.dio.get('/student/contracts', queryParameters: _sid(studentId));
    if (!ApiClient.ok(res)) _fail(res);
    final data = res.data;
    if (data is! List) return const [];
    return data.map((e) => ContractDoc.fromJson((e as Map).cast<String, dynamic>())).toList();
  }
}
