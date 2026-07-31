// Avtomatik generatsiya qilingan (studentPortal.ts asosida) — o'quvchi portali modellari.
// Barcha DTO'lar bir xil nomlar bilan (PascalCase), maydonlar camelCase.

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
bool _b(dynamic v) => v == true;

double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();
int? _in(dynamic v) => v == null ? null : (v as num).toInt();
String? _sn(dynamic v) => v?.toString();

Map<String, dynamic> _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? {};

List<String> _strList(dynamic v) => (v as List?)?.map((e) => e.toString()).toList() ?? [];

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) =>
    (v as List?)?.map((e) => fromJson(_map(e))).toList() ?? [];

/// Record<number|string, number> -> Map<String, double> (JSON kaliti doim string keladi).
Map<String, double> _numMap(dynamic v) {
  final m = <String, double>{};
  if (v is Map) {
    v.forEach((k, val) => m[k.toString()] = _d(val));
  }
  return m;
}

/// Record<string, Record<number|string, number>> -> Map<String, Map<String, double>>.
Map<String, Map<String, double>> _nestedNumMap(dynamic v) {
  final m = <String, Map<String, double>>{};
  if (v is Map) {
    v.forEach((k, val) => m[k.toString()] = _numMap(val));
  }
  return m;
}

Map<String, String>? _strMap(dynamic v) {
  if (v is Map) {
    final m = <String, String>{};
    v.forEach((k, val) => m[k.toString()] = val?.toString() ?? '');
    return m;
  }
  return null;
}

// ---------- Profil ----------
class StudentProfile {
  final String id;
  final String fullName;
  final String className;
  final String birthDate;
  final String gender;
  final String parentFullName;
  final String parentPhone;
  final String enrollmentDate;
  final String? photoUrl;
  final String? parentPhotoUrl;

  StudentProfile({
    required this.id,
    required this.fullName,
    required this.className,
    required this.birthDate,
    required this.gender,
    required this.parentFullName,
    required this.parentPhone,
    required this.enrollmentDate,
    this.photoUrl,
    this.parentPhotoUrl,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        id: _s(j['id']),
        fullName: _s(j['fullName']),
        className: _s(j['className']),
        birthDate: _s(j['birthDate']),
        gender: _s(j['gender']),
        parentFullName: _s(j['parentFullName']),
        parentPhone: _s(j['parentPhone']),
        enrollmentDate: _s(j['enrollmentDate']),
        photoUrl: _sn(j['photoUrl']),
        parentPhotoUrl: _sn(j['parentPhotoUrl']),
      );
}

class LessonTime {
  final int period;
  final String startTime;
  final String endTime;

  LessonTime({required this.period, required this.startTime, required this.endTime});

  factory LessonTime.fromJson(Map<String, dynamic> j) => LessonTime(
        period: _i(j['period']),
        startTime: _s(j['startTime']),
        endTime: _s(j['endTime']),
      );
}

class AbsenceReasonMeta {
  final String id;
  final String name;
  final String short;
  final bool isLate;

  AbsenceReasonMeta({required this.id, required this.name, required this.short, required this.isLate});

  factory AbsenceReasonMeta.fromJson(Map<String, dynamic> j) => AbsenceReasonMeta(
        id: _s(j['id']),
        name: _s(j['name']),
        short: _s(j['short']),
        isLate: _b(j['isLate']),
      );
}

class PortalMeta {
  final List<LessonTime> lessonTimes;
  final List<AbsenceReasonMeta> absenceReasons;
  final int currentQuarter;
  final int currentWeek;

  PortalMeta({
    required this.lessonTimes,
    required this.absenceReasons,
    required this.currentQuarter,
    required this.currentWeek,
  });

  factory PortalMeta.fromJson(Map<String, dynamic> j) => PortalMeta(
        lessonTimes: _list(j['lessonTimes'], LessonTime.fromJson),
        absenceReasons: _list(j['absenceReasons'], AbsenceReasonMeta.fromJson),
        currentQuarter: _i(j['currentQuarter']),
        currentWeek: _i(j['currentWeek']),
      );
}

class HomeworkItem {
  final String date;
  final int period;
  final String subjectId;
  final String subjectName;
  final String topic;
  final String? homework;
  final bool conducted;
  final double? grade;
  final String? reasonId;
  final String? reasonName;
  final bool isLate;

  HomeworkItem({
    required this.date,
    required this.period,
    required this.subjectId,
    required this.subjectName,
    required this.topic,
    this.homework,
    required this.conducted,
    this.grade,
    this.reasonId,
    this.reasonName,
    required this.isLate,
  });

  factory HomeworkItem.fromJson(Map<String, dynamic> j) => HomeworkItem(
        date: _s(j['date']),
        period: _i(j['period']),
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        topic: _s(j['topic']),
        homework: _sn(j['homework']),
        conducted: _b(j['conducted']),
        grade: _dn(j['grade']),
        reasonId: _sn(j['reasonId']),
        reasonName: _sn(j['reasonName']),
        isLate: _b(j['isLate']),
      );
}

class StudentLesson {
  final int day;
  final int period;
  final String? startTime;
  final String? endTime;
  final String subjectId;
  final String subjectName;
  final String teacherId;
  final String teacherName;

  StudentLesson({
    required this.day,
    required this.period,
    this.startTime,
    this.endTime,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
  });

  factory StudentLesson.fromJson(Map<String, dynamic> j) => StudentLesson(
        day: _i(j['day']),
        period: _i(j['period']),
        startTime: _sn(j['startTime']),
        endTime: _sn(j['endTime']),
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        teacherId: _s(j['teacherId']),
        teacherName: _s(j['teacherName']),
      );
}

class StudentDashboard {
  final StudentProfile profile;
  final PortalMeta meta;
  final List<StudentLesson> todayLessons;
  final List<HomeworkItem> todayGrades;
  final int pendingAssignmentsCount;
  final double balance;
  final double monthlyFee;

  StudentDashboard({
    required this.profile,
    required this.meta,
    required this.todayLessons,
    required this.todayGrades,
    required this.pendingAssignmentsCount,
    required this.balance,
    required this.monthlyFee,
  });

  factory StudentDashboard.fromJson(Map<String, dynamic> j) => StudentDashboard(
        profile: StudentProfile.fromJson(_map(j['profile'])),
        meta: PortalMeta.fromJson(_map(j['meta'])),
        todayLessons: _list(j['todayLessons'], StudentLesson.fromJson),
        todayGrades: _list(j['todayGrades'], HomeworkItem.fromJson),
        pendingAssignmentsCount: _i(j['pendingAssignmentsCount']),
        balance: _d(j['balance']),
        monthlyFee: _d(j['monthlyFee']),
      );
}

class SubjectRef {
  final String id;
  final String name;

  SubjectRef({required this.id, required this.name});

  factory SubjectRef.fromJson(Map<String, dynamic> j) => SubjectRef(id: _s(j['id']), name: _s(j['name']));
}

class StudentAttendanceSummary {
  final Map<String, double> missedDays;
  final Map<String, double> illnessDays;
  final Map<String, double> missedLessons;
  final Map<String, double> illnessLessons;
  final Map<String, double> lateCount;

  StudentAttendanceSummary({
    required this.missedDays,
    required this.illnessDays,
    required this.missedLessons,
    required this.illnessLessons,
    required this.lateCount,
  });

  factory StudentAttendanceSummary.fromJson(Map<String, dynamic> j) => StudentAttendanceSummary(
        missedDays: _numMap(j['missedDays']),
        illnessDays: _numMap(j['illnessDays']),
        missedLessons: _numMap(j['missedLessons']),
        illnessLessons: _numMap(j['illnessLessons']),
        lateCount: _numMap(j['lateCount']),
      );
}

class StudentGradesReport {
  final String studentId;
  final String fullName;
  final String className;
  final String homeroomTeacher;
  final List<SubjectRef> subjects;
  final Map<String, Map<String, double>> grades;
  final StudentAttendanceSummary attendance;

  StudentGradesReport({
    required this.studentId,
    required this.fullName,
    required this.className,
    required this.homeroomTeacher,
    required this.subjects,
    required this.grades,
    required this.attendance,
  });

  factory StudentGradesReport.fromJson(Map<String, dynamic> j) => StudentGradesReport(
        studentId: _s(j['studentId']),
        fullName: _s(j['fullName']),
        className: _s(j['className']),
        homeroomTeacher: _s(j['homeroomTeacher']),
        subjects: _list(j['subjects'], SubjectRef.fromJson),
        grades: _nestedNumMap(j['grades']),
        attendance: StudentAttendanceSummary.fromJson(_map(j['attendance'])),
      );
}

class AbsenceRow {
  final String date;
  final int period;
  final String subjectId;
  final String subjectName;
  final String reasonId;
  final String reasonName;
  final bool isLate;
  final bool isIll;

  AbsenceRow({
    required this.date,
    required this.period,
    required this.subjectId,
    required this.subjectName,
    required this.reasonId,
    required this.reasonName,
    required this.isLate,
    required this.isIll,
  });

  factory AbsenceRow.fromJson(Map<String, dynamic> j) => AbsenceRow(
        date: _s(j['date']),
        period: _i(j['period']),
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        reasonId: _s(j['reasonId']),
        reasonName: _s(j['reasonName']),
        isLate: _b(j['isLate']),
        isIll: _b(j['isIll']),
      );
}

class StudentAttendanceFull {
  final StudentAttendanceSummary summary;
  final List<AbsenceRow> rows;

  StudentAttendanceFull({required this.summary, required this.rows});

  factory StudentAttendanceFull.fromJson(Map<String, dynamic> j) => StudentAttendanceFull(
        summary: StudentAttendanceSummary.fromJson(_map(j['summary'])),
        rows: _list(j['rows'], AbsenceRow.fromJson),
      );
}

class DisciplinePoint {
  final String id;
  final String reasonName;
  final double points;
  final String note;
  final String createdAt;
  final String createdBy;
  final String source;

  DisciplinePoint({
    required this.id,
    required this.reasonName,
    required this.points,
    required this.note,
    required this.createdAt,
    required this.createdBy,
    required this.source,
  });

  factory DisciplinePoint.fromJson(Map<String, dynamic> j) => DisciplinePoint(
        id: _s(j['id']),
        reasonName: _s(j['reasonName']),
        points: _d(j['points']),
        note: _s(j['note']),
        createdAt: _s(j['createdAt']),
        createdBy: _s(j['createdBy']),
        source: _s(j['source']),
      );
}

class StudentDiscipline {
  final double remaining;
  final double plus;
  final double minus;
  final List<DisciplinePoint> items;

  StudentDiscipline({required this.remaining, required this.plus, required this.minus, required this.items});

  factory StudentDiscipline.fromJson(Map<String, dynamic> j) => StudentDiscipline(
        remaining: _d(j['remaining']),
        plus: _d(j['plus']),
        minus: _d(j['minus']),
        items: _list(j['items'], DisciplinePoint.fromJson),
      );
}

class RatingRow {
  final int rank;
  final String studentId;
  final String fullName;
  final String className;
  final double average;
  final double? attendance;
  /// Yig'ilgan ball (jurnal baholari + bajarilgan mezonlar) — reyting shu bo'yicha.
  final double? ball;

  RatingRow({
    required this.rank,
    required this.studentId,
    required this.fullName,
    required this.className,
    required this.average,
    this.attendance,
    this.ball,
  });

  factory RatingRow.fromJson(Map<String, dynamic> j) => RatingRow(
        rank: _i(j['rank']),
        studentId: _s(j['studentId']),
        fullName: _s(j['fullName']),
        className: _s(j['className']),
        average: _d(j['average']),
        attendance: _dn(j['attendance']),
        ball: _dn(j['ball']),
      );
}

class StudentRating {
  final String meStudentId;
  final List<RatingRow> classRows;
  final List<RatingRow> schoolRows;
  final int? meSchoolRank;
  final int schoolSize;

  StudentRating({
    required this.meStudentId,
    required this.classRows,
    required this.schoolRows,
    this.meSchoolRank,
    required this.schoolSize,
  });

  factory StudentRating.fromJson(Map<String, dynamic> j) => StudentRating(
        meStudentId: _s(j['meStudentId']),
        classRows: _list(j['classRows'], RatingRow.fromJson),
        schoolRows: _list(j['schoolRows'], RatingRow.fromJson),
        meSchoolRank: _in(j['meSchoolRank']),
        schoolSize: _i(j['schoolSize']),
      );
}

class SubjectProgress {
  final String subjectId;
  final String subjectName;
  final int planned;
  final int conducted;
  final int remaining;
  final double percent;
  final int? expectedByToday;
  final String? nextLessonDate;
  final String? lastLessonDate;

  SubjectProgress({
    required this.subjectId,
    required this.subjectName,
    required this.planned,
    required this.conducted,
    required this.remaining,
    required this.percent,
    this.expectedByToday,
    this.nextLessonDate,
    this.lastLessonDate,
  });

  factory SubjectProgress.fromJson(Map<String, dynamic> j) => SubjectProgress(
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        planned: _i(j['planned']),
        conducted: _i(j['conducted']),
        remaining: _i(j['remaining']),
        percent: _d(j['percent']),
        expectedByToday: _in(j['expectedByToday']),
        nextLessonDate: _sn(j['nextLessonDate']),
        lastLessonDate: _sn(j['lastLessonDate']),
      );
}

class StudentSubjectsProgress {
  final int quarter;
  final int totalPlanned;
  final int totalConducted;
  final double totalPercent;
  final List<SubjectProgress> subjects;

  StudentSubjectsProgress({
    required this.quarter,
    required this.totalPlanned,
    required this.totalConducted,
    required this.totalPercent,
    required this.subjects,
  });

  factory StudentSubjectsProgress.fromJson(Map<String, dynamic> j) => StudentSubjectsProgress(
        quarter: _i(j['quarter']),
        totalPlanned: _i(j['totalPlanned']),
        totalConducted: _i(j['totalConducted']),
        totalPercent: _d(j['totalPercent']),
        subjects: _list(j['subjects'], SubjectProgress.fromJson),
      );
}

class SubjectLesson {
  final String date;
  final int period;
  final String? startTime;
  final String? endTime;
  final String topic;
  final String? homework;
  final bool conducted;
  final bool isPast;

  SubjectLesson({
    required this.date,
    required this.period,
    this.startTime,
    this.endTime,
    required this.topic,
    this.homework,
    required this.conducted,
    required this.isPast,
  });

  factory SubjectLesson.fromJson(Map<String, dynamic> j) => SubjectLesson(
        date: _s(j['date']),
        period: _i(j['period']),
        startTime: _sn(j['startTime']),
        endTime: _sn(j['endTime']),
        topic: _s(j['topic']),
        homework: _sn(j['homework']),
        conducted: _b(j['conducted']),
        isPast: _b(j['isPast']),
      );
}

class SubjectProgressDetail {
  final String subjectId;
  final String subjectName;
  final int quarter;
  final int planned;
  final int conducted;
  final int remaining;
  final double percent;
  final List<SubjectLesson> lessons;

  SubjectProgressDetail({
    required this.subjectId,
    required this.subjectName,
    required this.quarter,
    required this.planned,
    required this.conducted,
    required this.remaining,
    required this.percent,
    required this.lessons,
  });

  factory SubjectProgressDetail.fromJson(Map<String, dynamic> j) => SubjectProgressDetail(
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        quarter: _i(j['quarter']),
        planned: _i(j['planned']),
        conducted: _i(j['conducted']),
        remaining: _i(j['remaining']),
        percent: _d(j['percent']),
        lessons: _list(j['lessons'], SubjectLesson.fromJson),
      );
}

class AssignmentMaterial {
  final String? id;
  final String name;
  final String url;
  final int size;
  final String contentType;
  final String? audioUrl;

  AssignmentMaterial({
    this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.contentType,
    this.audioUrl,
  });

  factory AssignmentMaterial.fromJson(Map<String, dynamic> j) => AssignmentMaterial(
        id: _sn(j['id']),
        name: _s(j['name']),
        url: _s(j['url']),
        size: _i(j['size']),
        contentType: _s(j['contentType']),
        audioUrl: _sn(j['audioUrl']),
      );
}

/// format: 'written' | 'file' | 'test' | 'video' | 'speaking'
class StudentAssignment {
  final String id;
  final String subjectName;
  final String title;
  final String description;
  final String format;
  final String? startDate;
  final String? dueDate;
  final bool lateAccept;
  final double latePenaltyPct;
  final double maxScore;
  final int questionCount;
  final List<AssignmentMaterial> materials;
  final bool completed;
  final String? submittedAt;
  final double? score;
  /// Speaking topshirig'i uchun o'qiladigan matn.
  final String? referenceText;

  StudentAssignment({
    required this.id,
    required this.subjectName,
    required this.title,
    required this.description,
    required this.format,
    this.startDate,
    this.dueDate,
    required this.lateAccept,
    required this.latePenaltyPct,
    required this.maxScore,
    required this.questionCount,
    required this.materials,
    required this.completed,
    this.submittedAt,
    this.score,
    this.referenceText,
  });

  factory StudentAssignment.fromJson(Map<String, dynamic> j) => StudentAssignment(
        id: _s(j['id']),
        subjectName: _s(j['subjectName']),
        title: _s(j['title']),
        description: _s(j['description']),
        format: _s(j['format']),
        startDate: _sn(j['startDate']),
        dueDate: _sn(j['dueDate']),
        lateAccept: _b(j['lateAccept']),
        latePenaltyPct: _d(j['latePenaltyPct']),
        maxScore: _d(j['maxScore']),
        questionCount: _i(j['questionCount']),
        materials: _list(j['materials'], AssignmentMaterial.fromJson),
        completed: _b(j['completed']),
        submittedAt: _sn(j['submittedAt']),
        score: _dn(j['score']),
        referenceText: _sn(j['referenceText']),
      );
}

// ---------- Speaking (Azure talaffuz bahosi) ----------
class SpeakingWord {
  final String word;
  final double accuracy;
  final String errorType;

  SpeakingWord({required this.word, required this.accuracy, required this.errorType});

  factory SpeakingWord.fromJson(Map<String, dynamic> j) => SpeakingWord(
        word: _s(j['word']),
        accuracy: _d(j['accuracy']),
        errorType: _s(j['errorType']),
      );
}

class SpeakingResult {
  final String recognizedText;
  final double pronScore;
  final double accuracy;
  final double fluency;
  final double completeness;
  final double prosody;
  final List<SpeakingWord> words;
  final String? error;

  SpeakingResult({
    required this.recognizedText,
    required this.pronScore,
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    required this.prosody,
    required this.words,
    this.error,
  });

  factory SpeakingResult.fromJson(Map<String, dynamic> j) => SpeakingResult(
        recognizedText: _s(j['recognizedText']),
        pronScore: _d(j['pronScore']),
        accuracy: _d(j['accuracy']),
        fluency: _d(j['fluency']),
        completeness: _d(j['completeness']),
        prosody: _d(j['prosody']),
        words: _list(j['words'], SpeakingWord.fromJson),
        error: _sn(j['error']),
      );
}

class TestQuestion {
  final String id;
  final String text;
  final List<String> options;

  TestQuestion({required this.id, required this.text, required this.options});

  factory TestQuestion.fromJson(Map<String, dynamic> j) => TestQuestion(
        id: _s(j['id']),
        text: _s(j['text']),
        options: _strList(j['options']),
      );
}

/// TS: `extends Omit<StudentAssignment, 'questionCount'>` — Dart'da composition orqali.
class StudentAssignmentDetail {
  final String id;
  final String subjectName;
  final String title;
  final String description;
  final String format;
  final String? startDate;
  final String? dueDate;
  final bool lateAccept;
  final double latePenaltyPct;
  final double maxScore;
  final List<AssignmentMaterial> materials;
  final bool completed;
  final String? submittedAt;
  final double? score;
  final String? referenceText;
  final List<TestQuestion> questions;
  final String? answerText;
  final String? fileUrl;

  StudentAssignmentDetail({
    required this.id,
    required this.subjectName,
    required this.title,
    required this.description,
    required this.format,
    this.startDate,
    this.dueDate,
    required this.lateAccept,
    required this.latePenaltyPct,
    required this.maxScore,
    required this.materials,
    required this.completed,
    this.submittedAt,
    this.score,
    this.referenceText,
    required this.questions,
    this.answerText,
    this.fileUrl,
  });

  factory StudentAssignmentDetail.fromJson(Map<String, dynamic> j) => StudentAssignmentDetail(
        id: _s(j['id']),
        subjectName: _s(j['subjectName']),
        title: _s(j['title']),
        description: _s(j['description']),
        format: _s(j['format']),
        startDate: _sn(j['startDate']),
        dueDate: _sn(j['dueDate']),
        lateAccept: _b(j['lateAccept']),
        latePenaltyPct: _d(j['latePenaltyPct']),
        maxScore: _d(j['maxScore']),
        materials: _list(j['materials'], AssignmentMaterial.fromJson),
        completed: _b(j['completed']),
        submittedAt: _sn(j['submittedAt']),
        score: _dn(j['score']),
        referenceText: _sn(j['referenceText']),
        questions: _list(j['questions'], TestQuestion.fromJson),
        answerText: _sn(j['answerText']),
        fileUrl: _sn(j['fileUrl']),
      );
}

class AssignmentScoreItem {
  final String assignmentId;
  final String subjectName;
  final String title;
  final String format;
  final double maxScore;
  final double? score;
  final bool completed;
  final String? dueDate;
  final String? submittedAt;

  AssignmentScoreItem({
    required this.assignmentId,
    required this.subjectName,
    required this.title,
    required this.format,
    required this.maxScore,
    this.score,
    required this.completed,
    this.dueDate,
    this.submittedAt,
  });

  factory AssignmentScoreItem.fromJson(Map<String, dynamic> j) => AssignmentScoreItem(
        assignmentId: _s(j['assignmentId']),
        subjectName: _s(j['subjectName']),
        title: _s(j['title']),
        format: _s(j['format']),
        maxScore: _d(j['maxScore']),
        score: _dn(j['score']),
        completed: _b(j['completed']),
        dueDate: _sn(j['dueDate']),
        submittedAt: _sn(j['submittedAt']),
      );
}

class StudentAssignmentScores {
  final int count;
  final int gradedCount;
  final double totalScore;
  final double totalMax;
  final List<AssignmentScoreItem> items;

  StudentAssignmentScores({
    required this.count,
    required this.gradedCount,
    required this.totalScore,
    required this.totalMax,
    required this.items,
  });

  factory StudentAssignmentScores.fromJson(Map<String, dynamic> j) => StudentAssignmentScores(
        count: _i(j['count']),
        gradedCount: _i(j['gradedCount']),
        totalScore: _d(j['totalScore']),
        totalMax: _d(j['totalMax']),
        items: _list(j['items'], AssignmentScoreItem.fromJson),
      );
}

class TestAnswer {
  final String questionId;
  final int selectedIndex;

  TestAnswer({required this.questionId, required this.selectedIndex});

  factory TestAnswer.fromJson(Map<String, dynamic> j) => TestAnswer(
        questionId: _s(j['questionId']),
        selectedIndex: _i(j['selectedIndex']),
      );

  Map<String, dynamic> toJson() => {'questionId': questionId, 'selectedIndex': selectedIndex};
}

class SubmitResult {
  final bool completed;
  final double? score;
  final int? correctCount;
  final int? total;

  SubmitResult({required this.completed, this.score, this.correctCount, this.total});

  factory SubmitResult.fromJson(Map<String, dynamic> j) => SubmitResult(
        completed: _b(j['completed']),
        score: _dn(j['score']),
        correctCount: _in(j['correctCount']),
        total: _in(j['total']),
      );
}

class UploadedFile {
  final String name;
  final String url;
  final int size;
  final String contentType;

  UploadedFile({required this.name, required this.url, required this.size, required this.contentType});

  factory UploadedFile.fromJson(Map<String, dynamic> j) => UploadedFile(
        name: _s(j['name']),
        url: _s(j['url']),
        size: _i(j['size']),
        contentType: _s(j['contentType']),
      );
}

class MonthCourse {
  final String courseName;
  final double fee;

  MonthCourse({required this.courseName, required this.fee});

  factory MonthCourse.fromJson(Map<String, dynamic> j) => MonthCourse(
        courseName: _s(j['courseName']),
        fee: _d(j['fee']),
      );
}

class MonthLedger {
  final String month;
  final double charged;
  final double discount;
  final double paid;
  final double remaining;
  final String status;
  final List<MonthCourse> courses;

  MonthLedger({
    required this.month,
    required this.charged,
    required this.discount,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.courses,
  });

  factory MonthLedger.fromJson(Map<String, dynamic> j) => MonthLedger(
        month: _s(j['month']),
        charged: _d(j['charged']),
        discount: _d(j['discount']),
        paid: _d(j['paid']),
        remaining: _d(j['remaining']),
        status: _s(j['status']),
        courses: _list(j['courses'], MonthCourse.fromJson),
      );
}

class StudentPayment {
  final String date;
  final double amount;
  final String? note;
  final String? month;
  final String? comment;

  StudentPayment({required this.date, required this.amount, this.note, this.month, this.comment});

  factory StudentPayment.fromJson(Map<String, dynamic> j) => StudentPayment(
        date: _s(j['date']),
        amount: _d(j['amount']),
        note: _sn(j['note']),
        month: _sn(j['month']),
        comment: _sn(j['comment']),
      );
}

class StudentFinanceStudent {
  final String id;
  final String fullName;
  final String className;

  StudentFinanceStudent({required this.id, required this.fullName, required this.className});

  factory StudentFinanceStudent.fromJson(Map<String, dynamic> j) => StudentFinanceStudent(
        id: _s(j['id']),
        fullName: _s(j['fullName']),
        className: _s(j['className']),
      );
}

class StudentFinance {
  final StudentFinanceStudent student;
  final double balance;
  final double monthlyFee;
  final double totalCharged;
  final double totalDiscount;
  final double totalPaid;
  final List<MonthLedger> months;
  final List<StudentPayment> payments;

  StudentFinance({
    required this.student,
    required this.balance,
    required this.monthlyFee,
    required this.totalCharged,
    required this.totalDiscount,
    required this.totalPaid,
    required this.months,
    required this.payments,
  });

  factory StudentFinance.fromJson(Map<String, dynamic> j) => StudentFinance(
        student: StudentFinanceStudent.fromJson(_map(j['student'])),
        balance: _d(j['balance']),
        monthlyFee: _d(j['monthlyFee']),
        totalCharged: _d(j['totalCharged']),
        totalDiscount: _d(j['totalDiscount']),
        totalPaid: _d(j['totalPaid']),
        months: _list(j['months'], MonthLedger.fromJson),
        payments: _list(j['payments'], StudentPayment.fromJson),
      );
}

class StudentChatMessage {
  final String id;
  final String className;
  final String senderUserId;
  final String senderName;
  final String senderRole;
  final String text;
  final String createdAt;

  StudentChatMessage({
    required this.id,
    required this.className,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory StudentChatMessage.fromJson(Map<String, dynamic> j) => StudentChatMessage(
        id: _s(j['id']),
        className: _s(j['className']),
        senderUserId: _s(j['senderUserId']),
        senderName: _s(j['senderName']),
        senderRole: _s(j['senderRole']),
        text: _s(j['text']),
        createdAt: _s(j['createdAt']),
      );
}

class UserSettings {
  final String language;
  final String theme;
  final bool notificationsEnabled;

  UserSettings({required this.language, required this.theme, required this.notificationsEnabled});

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
        language: _s(j['language']),
        theme: _s(j['theme']),
        notificationsEnabled: _b(j['notificationsEnabled']),
      );
}

class TelegramStatus {
  final bool configured;
  final String botUsername;
  final String botName;
  final String deepLink;
  final bool registered;

  TelegramStatus({
    required this.configured,
    required this.botUsername,
    required this.botName,
    required this.deepLink,
    required this.registered,
  });

  factory TelegramStatus.fromJson(Map<String, dynamic> j) => TelegramStatus(
        configured: _b(j['configured']),
        botUsername: _s(j['botUsername']),
        botName: _s(j['botName']),
        deepLink: _s(j['deepLink']),
        registered: _b(j['registered']),
      );
}

class StudentLocation {
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? updatedAt;

  StudentLocation({this.latitude, this.longitude, this.address, this.updatedAt});

  factory StudentLocation.fromJson(Map<String, dynamic> j) => StudentLocation(
        latitude: _dn(j['latitude']),
        longitude: _dn(j['longitude']),
        address: _sn(j['address']),
        updatedAt: _sn(j['updatedAt']),
      );
}

class StudentSchoolInfo {
  final String name;
  final String telegramChannel;

  StudentSchoolInfo({required this.name, required this.telegramChannel});

  factory StudentSchoolInfo.fromJson(Map<String, dynamic> j) => StudentSchoolInfo(
        name: _s(j['name']),
        telegramChannel: _s(j['telegramChannel']),
      );
}

// ---------- O'quv dasturi (curriculum roadmap) ----------
class CurriculumItem {
  final String id;
  final String text;
  final String note;
  final int order;
  final bool covered;
  final String coveredDate;

  CurriculumItem({
    required this.id,
    required this.text,
    required this.note,
    required this.order,
    required this.covered,
    required this.coveredDate,
  });

  factory CurriculumItem.fromJson(Map<String, dynamic> j) => CurriculumItem(
        id: _s(j['id']),
        text: _s(j['text']),
        note: _s(j['note']),
        order: _i(j['order']),
        covered: _b(j['covered']),
        coveredDate: _s(j['coveredDate']),
      );
}

class CurriculumTopic {
  final String id;
  final String title;
  final String note;
  final int order;
  final List<CurriculumItem> items;

  CurriculumTopic({
    required this.id,
    required this.title,
    required this.note,
    required this.order,
    required this.items,
  });

  factory CurriculumTopic.fromJson(Map<String, dynamic> j) => CurriculumTopic(
        id: _s(j['id']),
        title: _s(j['title']),
        note: _s(j['note']),
        order: _i(j['order']),
        items: _list(j['items'], CurriculumItem.fromJson),
      );
}

class CurriculumLevel {
  final String id;
  final String name;
  final String note;
  final int order;
  final List<CurriculumTopic> topics;

  CurriculumLevel({
    required this.id,
    required this.name,
    required this.note,
    required this.order,
    required this.topics,
  });

  factory CurriculumLevel.fromJson(Map<String, dynamic> j) => CurriculumLevel(
        id: _s(j['id']),
        name: _s(j['name']),
        note: _s(j['note']),
        order: _i(j['order']),
        topics: _list(j['topics'], CurriculumTopic.fromJson),
      );
}

class StudentCurriculum {
  final String groupId;
  final String courseId;
  final String courseName;
  final int totalItems;
  final int coveredCount;
  final int revisionLessons;
  final int totalLessons;
  final int remainingItems;
  final int estLessonsLeft;
  final int lessonsPerWeek;
  final String estFinishDate;
  final List<CurriculumLevel> levels;

  StudentCurriculum({
    required this.groupId,
    required this.courseId,
    required this.courseName,
    required this.totalItems,
    required this.coveredCount,
    required this.revisionLessons,
    required this.totalLessons,
    required this.remainingItems,
    required this.estLessonsLeft,
    required this.lessonsPerWeek,
    required this.estFinishDate,
    required this.levels,
  });

  factory StudentCurriculum.fromJson(Map<String, dynamic> j) => StudentCurriculum(
        groupId: _s(j['groupId']),
        courseId: _s(j['courseId']),
        courseName: _s(j['courseName']),
        totalItems: _i(j['totalItems']),
        coveredCount: _i(j['coveredCount']),
        revisionLessons: _i(j['revisionLessons']),
        totalLessons: _i(j['totalLessons']),
        remainingItems: _i(j['remainingItems']),
        estLessonsLeft: _i(j['estLessonsLeft']),
        lessonsPerWeek: _i(j['lessonsPerWeek']),
        estFinishDate: _s(j['estFinishDate']),
        // Server `modules` deb qaytaradi (GroupCurriculumDto.Modules); `levels` — eski nom.
        levels: _list(j['levels'] ?? j['modules'], CurriculumLevel.fromJson),
      );
}

// ---------- Baholash statistikasi (oylik + har darslik) ----------
class StudentGradingCriterion {
  final String id;
  final String name;
  final int done;
  final int total;

  StudentGradingCriterion({required this.id, required this.name, required this.done, required this.total});

  factory StudentGradingCriterion.fromJson(Map<String, dynamic> j) => StudentGradingCriterion(
        id: _s(j['id']),
        name: _s(j['name']),
        done: _i(j['done']),
        total: _i(j['total']),
      );
}

class StudentGradingDate {
  final String date;
  final List<String> doneCriterionIds;

  StudentGradingDate({required this.date, required this.doneCriterionIds});

  factory StudentGradingDate.fromJson(Map<String, dynamic> j) => StudentGradingDate(
        date: _s(j['date']),
        doneCriterionIds: _strList(j['doneCriterionIds']),
      );
}

class StudentGradingGroup {
  final String groupId;
  final String groupName;
  final List<String> months;
  final String month;
  final List<String> dates;
  final List<StudentGradingCriterion> criteria;
  final List<StudentGradingDate> lessons;
  /// Shu oyda yig'ilgan ball (bajarilgan mezonlar soni).
  final double? monthBall;
  /// Shu guruhda barcha vaqt bo'yicha yig'ilgan jami ball.
  final double? totalBall;

  StudentGradingGroup({
    required this.groupId,
    required this.groupName,
    required this.months,
    required this.month,
    required this.dates,
    required this.criteria,
    required this.lessons,
    this.monthBall,
    this.totalBall,
  });

  factory StudentGradingGroup.fromJson(Map<String, dynamic> j) => StudentGradingGroup(
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        months: _strList(j['months']),
        month: _s(j['month']),
        dates: _strList(j['dates']),
        criteria: _list(j['criteria'], StudentGradingCriterion.fromJson),
        lessons: _list(j['lessons'], StudentGradingDate.fromJson),
        monthBall: _dn(j['monthBall']),
        totalBall: _dn(j['totalBall']),
      );
}

// ---------- Dars kontenti (Duolingo node bosilganda) ----------
class LessonVocab {
  final String term;
  final String meaning;

  LessonVocab({required this.term, required this.meaning});

  factory LessonVocab.fromJson(Map<String, dynamic> j) => LessonVocab(
        term: _s(j['term']),
        meaning: _s(j['meaning']),
      );
}

class LessonQuestion {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;

  LessonQuestion({required this.id, required this.text, required this.options, required this.correctIndex});

  factory LessonQuestion.fromJson(Map<String, dynamic> j) => LessonQuestion(
        id: _s(j['id']),
        text: _s(j['text']),
        options: _strList(j['options']),
        correctIndex: _i(j['correctIndex']),
      );
}

/// type: 'text' | 'video' | 'audio' | 'vocab' | 'test' | 'pdf'
class LessonContent {
  final String id;
  final String topicId;
  final String text;
  final String note;
  final int order;
  final String type;
  final String videoUrl;
  final String audioUrl;
  final String textContent;
  final String pdfUrl;
  final String pdfName;
  final String meta;
  final List<LessonVocab> vocab;
  final List<LessonQuestion> questions;

  /// Interaktiv mashq (topshiriq konstruktorida yaratilgan) — tur va JSON mazmun.
  final String exerciseKind;
  final String exerciseJson;

  LessonContent({
    required this.id,
    required this.topicId,
    required this.text,
    required this.note,
    required this.order,
    required this.type,
    required this.videoUrl,
    required this.audioUrl,
    required this.textContent,
    required this.pdfUrl,
    required this.pdfName,
    required this.meta,
    required this.vocab,
    required this.questions,
    this.exerciseKind = '',
    this.exerciseJson = '',
  });

  factory LessonContent.fromJson(Map<String, dynamic> j) => LessonContent(
        id: _s(j['id']),
        topicId: _s(j['topicId']),
        text: _s(j['text']),
        note: _s(j['note']),
        order: _i(j['order']),
        type: _s(j['type']),
        videoUrl: _s(j['videoUrl']),
        audioUrl: _s(j['audioUrl']),
        textContent: _s(j['textContent']),
        pdfUrl: _s(j['pdfUrl']),
        pdfName: _s(j['pdfName']),
        meta: _s(j['meta']),
        vocab: _list(j['vocab'], LessonVocab.fromJson),
        questions: _list(j['questions'], LessonQuestion.fromJson),
        exerciseKind: _s(j['exerciseKind']),
        exerciseJson: _s(j['exerciseJson']),
      );
}

// ---------- Daftar (notebook) ----------
class AttendanceReasonCount {
  final String reasonId;
  final String name;
  final String short;
  final bool isLate;
  final int count;

  AttendanceReasonCount({
    required this.reasonId,
    required this.name,
    required this.short,
    required this.isLate,
    required this.count,
  });

  factory AttendanceReasonCount.fromJson(Map<String, dynamic> j) => AttendanceReasonCount(
        reasonId: _s(j['reasonId']),
        name: _s(j['name']),
        short: _s(j['short']),
        isLate: _b(j['isLate']),
        count: _i(j['count']),
      );
}

class MonthlyAttendance {
  final Map<String, double> missedDays;
  final Map<String, double> illnessDays;
  final Map<String, double> missedLessons;
  final Map<String, double> illnessLessons;
  final Map<String, double> lateCount;

  MonthlyAttendance({
    required this.missedDays,
    required this.illnessDays,
    required this.missedLessons,
    required this.illnessLessons,
    required this.lateCount,
  });

  factory MonthlyAttendance.fromJson(Map<String, dynamic> j) => MonthlyAttendance(
        missedDays: _numMap(j['missedDays']),
        illnessDays: _numMap(j['illnessDays']),
        missedLessons: _numMap(j['missedLessons']),
        illnessLessons: _numMap(j['illnessLessons']),
        lateCount: _numMap(j['lateCount']),
      );
}

class MonthlyEvaluation {
  final String month;
  final Map<String, double> grades;
  final double avg;

  MonthlyEvaluation({required this.month, required this.grades, required this.avg});

  factory MonthlyEvaluation.fromJson(Map<String, dynamic> j) => MonthlyEvaluation(
        month: _s(j['month']),
        grades: _numMap(j['grades']),
        avg: _d(j['avg']),
      );
}

class SubjectEvaluation {
  final String subjectId;
  final String subjectName;
  final double avg;
  final List<MonthlyEvaluation> evaluations;

  SubjectEvaluation({
    required this.subjectId,
    required this.subjectName,
    required this.avg,
    required this.evaluations,
  });

  factory SubjectEvaluation.fromJson(Map<String, dynamic> j) => SubjectEvaluation(
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        avg: _d(j['avg']),
        evaluations: _list(j['evaluations'], MonthlyEvaluation.fromJson),
      );
}

class MonthMarks {
  final String month;
  final int homeworkDone;
  final int homeworkMissed;
  final int behaviorGood;
  final int behaviorBad;

  MonthMarks({
    required this.month,
    required this.homeworkDone,
    required this.homeworkMissed,
    required this.behaviorGood,
    required this.behaviorBad,
  });

  factory MonthMarks.fromJson(Map<String, dynamic> j) => MonthMarks(
        month: _s(j['month']),
        homeworkDone: _i(j['homeworkDone']),
        homeworkMissed: _i(j['homeworkMissed']),
        behaviorGood: _i(j['behaviorGood']),
        behaviorBad: _i(j['behaviorBad']),
      );
}

class NotebookAssignmentScore {
  final String assignmentId;
  final String subjectName;
  final String title;
  final String format;
  final double maxScore;
  final double? score;
  final bool completed;

  NotebookAssignmentScore({
    required this.assignmentId,
    required this.subjectName,
    required this.title,
    required this.format,
    required this.maxScore,
    this.score,
    required this.completed,
  });

  factory NotebookAssignmentScore.fromJson(Map<String, dynamic> j) => NotebookAssignmentScore(
        assignmentId: _s(j['assignmentId']),
        subjectName: _s(j['subjectName']),
        title: _s(j['title']),
        format: _s(j['format']),
        maxScore: _d(j['maxScore']),
        score: _dn(j['score']),
        completed: _b(j['completed']),
      );
}

class NotebookAssignments {
  final int count;
  final int gradedCount;
  final double totalScore;
  final double totalMax;
  final List<NotebookAssignmentScore> items;

  NotebookAssignments({
    required this.count,
    required this.gradedCount,
    required this.totalScore,
    required this.totalMax,
    required this.items,
  });

  factory NotebookAssignments.fromJson(Map<String, dynamic> j) => NotebookAssignments(
        count: _i(j['count']),
        gradedCount: _i(j['gradedCount']),
        totalScore: _d(j['totalScore']),
        totalMax: _d(j['totalMax']),
        items: _list(j['items'], NotebookAssignmentScore.fromJson),
      );
}

class NotebookDisciplinePoint {
  final String id;
  final String reasonName;
  final double points;
  final String note;
  final String createdAt;
  final String source;

  NotebookDisciplinePoint({
    required this.id,
    required this.reasonName,
    required this.points,
    required this.note,
    required this.createdAt,
    required this.source,
  });

  factory NotebookDisciplinePoint.fromJson(Map<String, dynamic> j) => NotebookDisciplinePoint(
        id: _s(j['id']),
        reasonName: _s(j['reasonName']),
        points: _d(j['points']),
        note: _s(j['note']),
        createdAt: _s(j['createdAt']),
        source: _s(j['source']),
      );
}

class EvaluationType {
  final String id;
  final String name;

  EvaluationType({required this.id, required this.name});

  factory EvaluationType.fromJson(Map<String, dynamic> j) => EvaluationType(id: _s(j['id']), name: _s(j['name']));
}

class StudentNotebook {
  final String id;
  final String fullName;
  final String className;
  final double balance;
  final double avgGrade;
  final List<SubjectRef> subjects;
  /// fan nomi -> oy ("yyyy-MM") -> o'rtacha baho.
  final Map<String, Map<String, double>> grades;
  final MonthlyAttendance attendance;
  final int conducted;
  final int attended;
  final double attendancePct;
  final List<AttendanceReasonCount> reasons;
  final double disciplineScore;
  final double disciplinePlus;
  final double disciplineMinus;
  final List<NotebookDisciplinePoint> disciplinePoints;
  final NotebookAssignments assignments;
  final List<EvaluationType> evaluationTypes;
  final List<MonthlyEvaluation> evaluations;
  final List<SubjectEvaluation> evaluationsBySubject;
  final int homeworkDone;
  final int homeworkMissed;
  final int behaviorGood;
  final int behaviorBad;
  final List<MonthMarks> marksTrend;

  StudentNotebook({
    required this.id,
    required this.fullName,
    required this.className,
    required this.balance,
    required this.avgGrade,
    required this.subjects,
    required this.grades,
    required this.attendance,
    required this.conducted,
    required this.attended,
    required this.attendancePct,
    required this.reasons,
    required this.disciplineScore,
    required this.disciplinePlus,
    required this.disciplineMinus,
    required this.disciplinePoints,
    required this.assignments,
    required this.evaluationTypes,
    required this.evaluations,
    required this.evaluationsBySubject,
    required this.homeworkDone,
    required this.homeworkMissed,
    required this.behaviorGood,
    required this.behaviorBad,
    required this.marksTrend,
  });

  factory StudentNotebook.fromJson(Map<String, dynamic> j) => StudentNotebook(
        id: _s(j['id']),
        fullName: _s(j['fullName']),
        className: _s(j['className']),
        balance: _d(j['balance']),
        avgGrade: _d(j['avgGrade']),
        subjects: _list(j['subjects'], SubjectRef.fromJson),
        grades: _nestedNumMap(j['grades']),
        attendance: MonthlyAttendance.fromJson(_map(j['attendance'])),
        conducted: _i(j['conducted']),
        attended: _i(j['attended']),
        attendancePct: _d(j['attendancePct']),
        reasons: _list(j['reasons'], AttendanceReasonCount.fromJson),
        disciplineScore: _d(j['disciplineScore']),
        disciplinePlus: _d(j['disciplinePlus']),
        disciplineMinus: _d(j['disciplineMinus']),
        disciplinePoints: _list(j['disciplinePoints'], NotebookDisciplinePoint.fromJson),
        assignments: NotebookAssignments.fromJson(_map(j['assignments'])),
        evaluationTypes: _list(j['evaluationTypes'], EvaluationType.fromJson),
        evaluations: _list(j['evaluations'], MonthlyEvaluation.fromJson),
        evaluationsBySubject: _list(j['evaluationsBySubject'], SubjectEvaluation.fromJson),
        homeworkDone: _i(j['homeworkDone']),
        homeworkMissed: _i(j['homeworkMissed']),
        behaviorGood: _i(j['behaviorGood']),
        behaviorBad: _i(j['behaviorBad']),
        marksTrend: _list(j['marksTrend'], MonthMarks.fromJson),
      );
}

// ---------- Bildirishnomalar ----------
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String createdAt;
  final bool read;
  final bool confirmed;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.read,
    required this.confirmed,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _s(j['id']),
        title: _s(j['title']),
        body: _s(j['body']),
        type: _s(j['type']),
        createdAt: _s(j['createdAt']),
        read: _b(j['read']),
        confirmed: _b(j['confirmed']),
      );
}

class NotificationsResponse {
  final int unread;
  final List<AppNotification> items;

  NotificationsResponse({required this.unread, required this.items});

  factory NotificationsResponse.fromJson(Map<String, dynamic> j) => NotificationsResponse(
        unread: _i(j['unread']),
        items: _list(j['items'], AppNotification.fromJson),
      );
}

// ---------- Sertifikatlar ----------
class StudentCertificateDto {
  final String id;
  final String courseName;
  final String issuedAt;
  final String? expiresAt;
  final String status;
  final String fileName;
  final String downloadUrl;
  final int downloadCount;
  final Map<String, String>? metadata;

  StudentCertificateDto({
    required this.id,
    required this.courseName,
    required this.issuedAt,
    this.expiresAt,
    required this.status,
    required this.fileName,
    required this.downloadUrl,
    required this.downloadCount,
    this.metadata,
  });

  factory StudentCertificateDto.fromJson(Map<String, dynamic> j) => StudentCertificateDto(
        id: _s(j['id']),
        courseName: _s(j['courseName']),
        issuedAt: _s(j['issuedAt']),
        expiresAt: _sn(j['expiresAt']),
        status: _s(j['status']),
        fileName: _s(j['fileName']),
        downloadUrl: _s(j['downloadUrl']),
        downloadCount: _i(j['downloadCount']),
        metadata: _strMap(j['metadata']),
      );
}

/// Test natijasi — O'quv bo'limi "Testlar natijalari"dan (o'qituvchi kiritadi). Web: `StudentTestResult`.
class StudentTestResult {
  final String testId;
  final String groupId;
  final String groupName;
  final String name;
  final String date;
  final double maxScore;
  final double? score; // null = ball kiritilmagan
  final int rank; // 0 = o'rni yo'q (ball yo'q)
  final int total; // shu testda baholanganlar soni

  StudentTestResult({
    required this.testId,
    required this.groupId,
    required this.groupName,
    required this.name,
    required this.date,
    required this.maxScore,
    required this.score,
    required this.rank,
    required this.total,
  });

  factory StudentTestResult.fromJson(Map<String, dynamic> j) => StudentTestResult(
        testId: _s(j['testId']),
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        name: _s(j['name']),
        date: _s(j['date']),
        maxScore: _d(j['maxScore']),
        score: _dn(j['score']),
        rank: _i(j['rank']),
        total: _i(j['total']),
      );
}

// ---------- AI tekshiruv (Speaking / Writing) — web: types/index.ts `AiCheck*` ----------

/// Mezonlar bo'yicha ballar (0-100).
class AiCheckScores {
  final double grammar;
  final double vocabulary;
  final double coherence;
  final double task;
  final double mechanics;
  final double pronunciation;
  final double fluency;

  AiCheckScores({
    required this.grammar,
    required this.vocabulary,
    required this.coherence,
    required this.task,
    required this.mechanics,
    required this.pronunciation,
    required this.fluency,
  });

  factory AiCheckScores.fromJson(Map<String, dynamic> j) => AiCheckScores(
        grammar: _d(j['grammar']),
        vocabulary: _d(j['vocabulary']),
        coherence: _d(j['coherence']),
        task: _d(j['task']),
        mechanics: _d(j['mechanics']),
        pronunciation: _d(j['pronunciation']),
        fluency: _d(j['fluency']),
      );
}

/// Bitta tuzatish: asl → taklif + izoh.
class AiCorrection {
  final String original;
  final String suggestion;
  final String explanation;

  AiCorrection({required this.original, required this.suggestion, required this.explanation});

  factory AiCorrection.fromJson(Map<String, dynamic> j) => AiCorrection(
        original: _s(j['original']),
        suggestion: _s(j['suggestion']),
        explanation: _s(j['explanation']),
      );
}

/// So'z boyligi tavsiyasi.
class AiVocab {
  final String word;
  final String suggestion;
  final String note;

  AiVocab({required this.word, required this.suggestion, required this.note});

  factory AiVocab.fromJson(Map<String, dynamic> j) => AiVocab(
        word: _s(j['word']),
        suggestion: _s(j['suggestion']),
        note: _s(j['note']),
      );
}

/// IELTS Writing band bahosi (0-9).
class AiCheckIelts {
  final double task;
  final double coherence;
  final double lexical;
  final double grammar;
  final double overall;
  final String taskType;

  AiCheckIelts({
    required this.task,
    required this.coherence,
    required this.lexical,
    required this.grammar,
    required this.overall,
    required this.taskType,
  });

  factory AiCheckIelts.fromJson(Map<String, dynamic> j) => AiCheckIelts(
        task: _d(j['task']),
        coherence: _d(j['coherence']),
        lexical: _d(j['lexical']),
        grammar: _d(j['grammar']),
        overall: _d(j['overall']),
        taskType: _s(j['taskType']),
      );
}

/// Gemini matn tahlili.
class AiCheckAnalysis {
  final double overall;
  final String level;
  final AiCheckScores scores;
  final String summary;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<AiCorrection> corrections;
  final List<AiVocab> vocabulary;
  final String improved;
  final List<String> recommendations;
  final AiCheckIelts? ielts;

  AiCheckAnalysis({
    required this.overall,
    required this.level,
    required this.scores,
    required this.summary,
    required this.strengths,
    required this.weaknesses,
    required this.corrections,
    required this.vocabulary,
    required this.improved,
    required this.recommendations,
    this.ielts,
  });

  factory AiCheckAnalysis.fromJson(Map<String, dynamic> j) => AiCheckAnalysis(
        overall: _d(j['overall']),
        level: _s(j['level']),
        scores: AiCheckScores.fromJson(_map(j['scores'])),
        summary: _s(j['summary']),
        strengths: _strList(j['strengths']),
        weaknesses: _strList(j['weaknesses']),
        corrections: _list(j['corrections'], AiCorrection.fromJson),
        vocabulary: _list(j['vocabulary'], AiVocab.fromJson),
        improved: _s(j['improved']),
        recommendations: _strList(j['recommendations']),
        ielts: j['ielts'] == null ? null : AiCheckIelts.fromJson(_map(j['ielts'])),
      );
}

/// Azure talaffuz natijasi (AI tekshiruv yozuvi ichida).
class AiCheckSpeech {
  final String recognizedText;
  final double pronScore;
  final double accuracy;
  final double fluency;
  final double completeness;
  final double prosody;
  final List<SpeakingWord> words;

  AiCheckSpeech({
    required this.recognizedText,
    required this.pronScore,
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    required this.prosody,
    required this.words,
  });

  factory AiCheckSpeech.fromJson(Map<String, dynamic> j) => AiCheckSpeech(
        recognizedText: _s(j['recognizedText']),
        pronScore: _d(j['pronScore']),
        accuracy: _d(j['accuracy']),
        fluency: _d(j['fluency']),
        completeness: _d(j['completeness']),
        prosody: _d(j['prosody']),
        words: _list(j['words'], SpeakingWord.fromJson),
      );
}

/// To'liq AI tekshiruv yozuvi. type: 'speaking' | 'writing'.
class AiCheck {
  final String id;
  final String type;
  final String prompt;
  final String inputText;
  final String recognizedText;
  final String audioUrl;
  final double score;
  final String date;
  final String createdAt;
  final AiCheckAnalysis? analysis;
  final AiCheckSpeech? speech;
  final String taskType;

  AiCheck({
    required this.id,
    required this.type,
    required this.prompt,
    required this.inputText,
    required this.recognizedText,
    required this.audioUrl,
    required this.score,
    required this.date,
    required this.createdAt,
    this.analysis,
    this.speech,
    required this.taskType,
  });

  factory AiCheck.fromJson(Map<String, dynamic> j) => AiCheck(
        id: _s(j['id']),
        type: _s(j['type']),
        prompt: _s(j['prompt']),
        inputText: _s(j['inputText']),
        recognizedText: _s(j['recognizedText']),
        audioUrl: _s(j['audioUrl']),
        score: _d(j['score']),
        date: _s(j['date']),
        createdAt: _s(j['createdAt']),
        analysis: j['analysis'] == null ? null : AiCheckAnalysis.fromJson(_map(j['analysis'])),
        speech: j['speech'] == null ? null : AiCheckSpeech.fromJson(_map(j['speech'])),
        taskType: _s(j['taskType']),
      );
}

/// AI tekshiruv tarixidagi qator.
class AiCheckListItem {
  final String id;
  final String type;
  final String prompt;
  final double score;
  final String date;
  final String createdAt;
  final bool hasAudio;

  AiCheckListItem({
    required this.id,
    required this.type,
    required this.prompt,
    required this.score,
    required this.date,
    required this.createdAt,
    required this.hasAudio,
  });

  factory AiCheckListItem.fromJson(Map<String, dynamic> j) => AiCheckListItem(
        id: _s(j['id']),
        type: _s(j['type']),
        prompt: _s(j['prompt']),
        score: _d(j['score']),
        date: _s(j['date']),
        createdAt: _s(j['createdAt']),
        hasAudio: _b(j['hasAudio']),
      );
}

/// AI tekshiruv holati: kalitlar tayyorligi + limit/premium/blok.
class AiCheckStatus {
  final bool geminiReady;
  final bool azureReady;
  final bool premium;
  final bool blocked;
  final int limit;
  final int usedToday;
  final int remaining;

  AiCheckStatus({
    required this.geminiReady,
    required this.azureReady,
    required this.premium,
    required this.blocked,
    required this.limit,
    required this.usedToday,
    required this.remaining,
  });

  factory AiCheckStatus.fromJson(Map<String, dynamic> j) => AiCheckStatus(
        geminiReady: _b(j['geminiReady']),
        azureReady: _b(j['azureReady']),
        premium: _b(j['premium']),
        blocked: _b(j['blocked']),
        limit: _i(j['limit']),
        usedToday: _i(j['usedToday']),
        remaining: _i(j['remaining']),
      );
}

// ---------- Dars topshirig'i urinishi (natija saqlanishi) — web: `AttemptPayload` ----------

/// Bitta savol/element bo'yicha javob (serverda AnswersJson ichida saqlanadi).
class AttemptAnswer {
  final int index;
  final String prompt;
  final String answer;
  final String expected;
  final bool ok;
  final int sec;

  AttemptAnswer({
    required this.index,
    required this.prompt,
    required this.answer,
    required this.expected,
    required this.ok,
    required this.sec,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'prompt': prompt,
        'answer': answer,
        'expected': expected,
        'ok': ok,
        'sec': sec,
      };
}

/// Support (yordam darsi) bo'sh sloti. Web: `StudentSupportTeacher['openSlots'][number]`.
class StudentSupportSlot {
  final String id;
  final String date;
  final String startTime;
  final String endTime;

  StudentSupportSlot({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  factory StudentSupportSlot.fromJson(Map<String, dynamic> j) => StudentSupportSlot(
        id: _s(j['id']),
        date: _s(j['date']),
        startTime: _s(j['startTime']),
        endTime: _s(j['endTime']),
      );
}

/// Support o'qituvchi + bo'sh slotlari. Web: `StudentSupportTeacher`.
class StudentSupportTeacher {
  final String teacherId;
  final String fullName;
  final String? photoUrl;
  final String subject;
  final List<StudentSupportSlot> openSlots;

  StudentSupportTeacher({
    required this.teacherId,
    required this.fullName,
    this.photoUrl,
    required this.subject,
    required this.openSlots,
  });

  factory StudentSupportTeacher.fromJson(Map<String, dynamic> j) => StudentSupportTeacher(
        teacherId: _s(j['teacherId']),
        fullName: _s(j['fullName']),
        photoUrl: _sn(j['photoUrl']),
        subject: _s(j['subject']),
        openSlots: _list(j['openSlots'], StudentSupportSlot.fromJson),
      );
}

/// O'quvchining support broni. Web: `StudentSupportBooking`.
class StudentSupportBooking {
  final String id;
  final String teacherId;
  final String teacherName;
  final String date;
  final String startTime;
  final String endTime;
  final String status; // open | booked | done
  final String topic;
  final String notes;

  StudentSupportBooking({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.topic,
    required this.notes,
  });

  factory StudentSupportBooking.fromJson(Map<String, dynamic> j) => StudentSupportBooking(
        id: _s(j['id']),
        teacherId: _s(j['teacherId']),
        teacherName: _s(j['teacherName']),
        date: _s(j['date']),
        startTime: _s(j['startTime']),
        endTime: _s(j['endTime']),
        status: _s(j['status']),
        topic: _s(j['topic']),
        notes: _s(j['notes']),
      );
}

/// Support ekrani ma'lumoti: bo'sh slotli o'qituvchilar + mening bronlarim. Web: `StudentSupport`.
class StudentSupport {
  final List<StudentSupportTeacher> supports;
  final List<StudentSupportBooking> myBookings;

  StudentSupport({required this.supports, required this.myBookings});

  factory StudentSupport.fromJson(Map<String, dynamic> j) => StudentSupport(
        supports: _list(j['supports'], StudentSupportTeacher.fromJson),
        myBookings: _list(j['myBookings'], StudentSupportBooking.fromJson),
      );
}

// ---------- Shartnoma (elektron nusxa) — web: `ContractDoc` ----------

/// Markaz o'quvchi/ota-ona bilan tuzgan shartnomaning saqlangan nusxasi.
/// `signedUrl` — imzolangan skan (bo'lsa u ustun), `pdfUrl` — tizim hosil qilgan PDF.
class ContractDoc {
  final String id;
  final int number;
  final String title;
  final String target;
  final String recipientKey;
  final String recipientName;
  final String templateName;
  final String date;
  final String pdfUrl;
  final String docxUrl;
  final String signedUrl;
  final bool signed;
  final bool delivered;
  final String status;

  ContractDoc({
    required this.id,
    required this.number,
    required this.title,
    required this.target,
    required this.recipientKey,
    required this.recipientName,
    required this.templateName,
    required this.date,
    required this.pdfUrl,
    required this.docxUrl,
    required this.signedUrl,
    required this.signed,
    required this.delivered,
    required this.status,
  });

  /// Ochish uchun manzil — imzolangan nusxa bo'lsa o'sha, aks holda PDF.
  String get fileUrl => signed && signedUrl.isNotEmpty ? signedUrl : pdfUrl;
  bool get hasFile => fileUrl.isNotEmpty;

  factory ContractDoc.fromJson(Map<String, dynamic> j) => ContractDoc(
        id: _s(j['id']),
        number: _i(j['number']),
        title: _s(j['title']),
        target: _s(j['target']),
        recipientKey: _s(j['recipientKey']),
        recipientName: _s(j['recipientName']),
        templateName: _s(j['templateName']),
        date: _s(j['date']),
        pdfUrl: _s(j['pdfUrl']),
        docxUrl: _s(j['docxUrl']),
        signedUrl: _s(j['signedUrl']),
        signed: _b(j['signed']),
        delivered: _b(j['delivered']),
        status: _s(j['status']),
      );
}
