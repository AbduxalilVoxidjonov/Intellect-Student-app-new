// Avtomatik generatsiya qilingan (studentPortal.ts asosida) — o'quvchi portali modellari.
// Barcha DTO'lar bir xil nomlar bilan (PascalCase), maydonlar camelCase.
//
// Har bir DTO da:
//   * `fromJson` — serverdan/keshdan o'qish (tip-bardosh, hech qachon qulamaydi);
//   * `toJson`   — offline kesh (SharedPreferences/fayl) uchun. Kalitlar `fromJson`
//                  kalitlari bilan AYNAN bir xil, shuning uchun
//                  `X.fromJson(x.toJson()) == x` (round-trip) qiymatni saqlaydi;
//   * `==`/`hashCode` — qiymat bo'yicha tenglik. Ro'yxat/Map maydonlari CHUQUR
//                  solishtiriladi, shuning uchun DTO'larni `Set`/`Map` kalitida
//                  ishlatish va `didUpdateWidget` da o'zgarishni aniqlash mumkin.

/// Ro'yxat/Map (va ichma-ich joylashgan qiymatlar) uchun CHUQUR solishtirish.
/// `package:collection` `pubspec.yaml` da to'g'ridan-to'g'ri e'lon qilinmagan
/// (faqat tranzitiv) — `depend_on_referenced_packages` lint bermasin deb
/// qo'lda yozilgan. Skalyarlar uchun oddiy `==` ga tushadi, shuning uchun
/// universal ishlatish mumkin.
bool _deepEq(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List) {
    if (b is! List || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map) {
    if (b is! Map || a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}

/// `_deepEq` bilan IZCHIL hash: ro'yxat — TARTIBLI, Map — TARTIBSIZ
/// (`_deepEq` ham Map kalitlarini tartibdan qat'i nazar solishtiradi).
int _deepHash(Object? v) {
  if (v is List) return Object.hashAll(v.map(_deepHash));
  if (v is Map) {
    return Object.hashAllUnordered(
      v.entries.map((e) => Object.hash(_deepHash(e.key), _deepHash(e.value))),
    );
  }
  return v.hashCode;
}

/// Barcha maydonlar bo'yicha hash. `Object.hash` maksimum 20 ta argument
/// oladi (StudentNotebook da 24 ta maydon bor) — `Object.hashAll` cheklovsiz.
int _hashProps(List<Object?> props) => Object.hashAll(props.map(_deepHash));

/// Tip-bardoshli son o'qish: backend pul/baholarni MATN sifatida yuborishi
/// mumkin ({"balance": "-850000.00"}) — `as num` cast qilsak ekran qulaydi.
/// NaN/Infinity ham yaroqsiz hisoblanadi (keyingi `.round()` xato tashlamasin).
num? _num(dynamic v) {
  if (v is num) return v.isFinite ? v : null;
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    var s = v.trim();
    if (s.isEmpty) return null;
    // Kasr ajratuvchi vergul ("4,5") → nuqta; nuqta ham bo'lsa vergul
    // minglik ajratuvchi ("1,234.56") deb tashlanadi.
    s = s.contains('.') ? s.replaceAll(',', '') : s.replaceAll(',', '.');
    final n = num.tryParse(s);
    return (n != null && n.isFinite) ? n : null;
  }
  return null;
}

double _d(dynamic v) => _num(v)?.toDouble() ?? 0;
// `.round()` — `.toInt()` kasrni kesib tashlaydi (2.9 → 2), yaxlitlash to'g'riroq.
int _i(dynamic v) => _num(v)?.round() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

/// SQL tinyint (1/0) va form-encoded ("true"/"1") javoblar ham tan olinadi.
bool _b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1';
  }
  return false;
}

double? _dn(dynamic v) => _num(v)?.toDouble();
int? _in(dynamic v) => _num(v)?.round();
String? _sn(dynamic v) => v?.toString();

/// Obyekt o'rniga ro'yxat/boshqa tur kelsa cast xatosi bermasin.
Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return {};
}

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e?.toString() ?? '').toList() : [];

/// Ro'yxat o'rniga obyekt kelsa bo'sh ro'yxat; map bo'lmagan elementlar tashlanadi.
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) =>
    v is List ? v.whereType<Map>().map((e) => fromJson(_map(e))).toList() : [];

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

  /// `StudentProfile.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fullName': fullName,
        'className': className,
        'birthDate': birthDate,
        'gender': gender,
        'parentFullName': parentFullName,
        'parentPhone': parentPhone,
        'enrollmentDate': enrollmentDate,
        'photoUrl': photoUrl,
        'parentPhotoUrl': parentPhotoUrl,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentProfile &&
          id == other.id &&
          fullName == other.fullName &&
          className == other.className &&
          birthDate == other.birthDate &&
          gender == other.gender &&
          parentFullName == other.parentFullName &&
          parentPhone == other.parentPhone &&
          enrollmentDate == other.enrollmentDate &&
          photoUrl == other.photoUrl &&
          parentPhotoUrl == other.parentPhotoUrl;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        fullName,
        className,
        birthDate,
        gender,
        parentFullName,
        parentPhone,
        enrollmentDate,
        photoUrl,
        parentPhotoUrl,
      ]);
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

  /// `LessonTime.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'period': period,
        'startTime': startTime,
        'endTime': endTime,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonTime &&
          period == other.period &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => _hashProps(<Object?>[
        period,
        startTime,
        endTime,
      ]);
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

  /// `AbsenceReasonMeta.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'short': short,
        'isLate': isLate,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbsenceReasonMeta &&
          id == other.id &&
          name == other.name &&
          short == other.short &&
          isLate == other.isLate;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        name,
        short,
        isLate,
      ]);
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

  /// `PortalMeta.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'lessonTimes': lessonTimes.map((e) => e.toJson()).toList(),
        'absenceReasons': absenceReasons.map((e) => e.toJson()).toList(),
        'currentQuarter': currentQuarter,
        'currentWeek': currentWeek,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortalMeta &&
          _deepEq(lessonTimes, other.lessonTimes) &&
          _deepEq(absenceReasons, other.absenceReasons) &&
          currentQuarter == other.currentQuarter &&
          currentWeek == other.currentWeek;

  @override
  int get hashCode => _hashProps(<Object?>[
        lessonTimes,
        absenceReasons,
        currentQuarter,
        currentWeek,
      ]);
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

  /// `HomeworkItem.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'period': period,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'topic': topic,
        'homework': homework,
        'conducted': conducted,
        'grade': grade,
        'reasonId': reasonId,
        'reasonName': reasonName,
        'isLate': isLate,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeworkItem &&
          date == other.date &&
          period == other.period &&
          subjectId == other.subjectId &&
          subjectName == other.subjectName &&
          topic == other.topic &&
          homework == other.homework &&
          conducted == other.conducted &&
          grade == other.grade &&
          reasonId == other.reasonId &&
          reasonName == other.reasonName &&
          isLate == other.isLate;

  @override
  int get hashCode => _hashProps(<Object?>[
        date,
        period,
        subjectId,
        subjectName,
        topic,
        homework,
        conducted,
        grade,
        reasonId,
        reasonName,
        isLate,
      ]);
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

  /// `StudentLesson.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'day': day,
        'period': period,
        'startTime': startTime,
        'endTime': endTime,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'teacherId': teacherId,
        'teacherName': teacherName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentLesson &&
          day == other.day &&
          period == other.period &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          subjectId == other.subjectId &&
          subjectName == other.subjectName &&
          teacherId == other.teacherId &&
          teacherName == other.teacherName;

  @override
  int get hashCode => _hashProps(<Object?>[
        day,
        period,
        startTime,
        endTime,
        subjectId,
        subjectName,
        teacherId,
        teacherName,
      ]);
}

/// O'quvchining guruhi (`GET /student/groups`) — FAOL ham, tugagan/chiqilgan ham keladi.
/// Hech bir guruh jimgina yo'qolmaydi: qaysi holatda ekani `state` bilan bildiriladi.
class StudentGroupInfo {
  final String groupId;
  final String name;
  final String courseName;
  final String teacherName;

  /// Dars kunlari: 0=Dushanba … 6=Yakshanba.
  final List<int> days;
  final String startTime;
  final String endTime;
  final String room;

  /// Ko'rsatiladigan holat (SERVER hisoblaydi — qoida ikki tilda takrorlanmasin):
  /// `active` | `trial` | `frozen` | `finished`.
  final String state;

  /// A'zolikning xom holati (`trial|active|frozen|completed`) va guruhning arxivligi —
  /// tafsilot kerak bo'lganda (masalan "guruh yopilgan" deb aniqroq yozish uchun).
  final String status;
  final bool isActive;
  final bool groupArchived;
  final String joinedAt;
  final String leftAt;

  StudentGroupInfo({
    required this.groupId,
    required this.name,
    required this.courseName,
    required this.teacherName,
    required this.days,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.state,
    required this.status,
    required this.isActive,
    required this.groupArchived,
    required this.joinedAt,
    required this.leftAt,
  });

  /// Normallashtirilgan holat: xom `status` ("completed") `state` sifatida kelsa
  /// ham tugagan deb qaraladi. `state` bo'sh yoki notanish bo'lsa `null` —
  /// bunday holatda XOM maydonlardan xulosa chiqariladi (`_fallbackCurrent`).
  String? get _state => switch (state) {
        'active' || 'trial' || 'frozen' || 'finished' => state,
        'completed' => 'finished',
        _ => null,
      };

  /// `state` yo'q/notanish bo'lgandagi zaxira mantiq — eski serverda ham bor
  /// maydonlarga tayanadi. Guruh ASOSSIZ "yakunlangan"ga tushib yo'qolmasin.
  bool get _fallbackCurrent => isActive && !groupArchived && leftAt.isEmpty;

  /// Hozir shu guruhda o'qiyaptimi (muzlatilgan ham "hozirgi" hisoblanadi — a'zolik saqlanadi).
  bool get isCurrent => switch (_state) {
        final s? => s != 'finished',
        // `state` yubormagan/notanish server — xom maydonlar bo'yicha.
        null => _fallbackCurrent,
      };

  /// O'quvchiga ko'rsatiladigan holat matni.
  String get statusLabel => switch (_state) {
        'frozen' => 'Muzlatilgan',
        'trial' => 'Sinov',
        'finished' => _finishedLabel,
        'active' => 'Aktiv',
        // `state` umuman kelmagan (eski server) — xom maydonlar bo'yicha xulosa.
        null when state.isEmpty => _fallbackCurrent ? 'Aktiv' : _finishedLabel,
        // `state` bor, lekin notanish qiymat ("paused") — neytral yorliq
        // (noto'g'ri "Aktiv" ham, noto'g'ri "Yakunlangan" ham ko'rsatilmasin).
        _ => 'Noma\'lum',
      };

  String get _finishedLabel =>
      groupArchived ? 'Guruh yopilgan' : (leftAt.isNotEmpty ? 'Chiqilgan' : 'Yakunlangan');

  factory StudentGroupInfo.fromJson(Map<String, dynamic> j) => StudentGroupInfo(
        groupId: _s(j['groupId']),
        name: _s(j['name']),
        courseName: _s(j['courseName']),
        teacherName: _s(j['teacherName']),
        // `as List?` cast qilmaymiz: ro'yxat o'rniga boshqa tur kelsa qulamasin.
        days: j['days'] is List ? (j['days'] as List).map(_i).toList() : <int>[],
        startTime: _s(j['startTime']),
        endTime: _s(j['endTime']),
        room: _s(j['room']),
        state: _s(j['state']),
        status: _s(j['status']),
        isActive: _b(j['isActive']),
        groupArchived: _b(j['groupArchived']),
        joinedAt: _s(j['joinedAt']),
        leftAt: _s(j['leftAt']),
      );

  /// `StudentGroupInfo.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupId': groupId,
        'name': name,
        'courseName': courseName,
        'teacherName': teacherName,
        'days': days,
        'startTime': startTime,
        'endTime': endTime,
        'room': room,
        'state': state,
        'status': status,
        'isActive': isActive,
        'groupArchived': groupArchived,
        'joinedAt': joinedAt,
        'leftAt': leftAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGroupInfo &&
          groupId == other.groupId &&
          name == other.name &&
          courseName == other.courseName &&
          teacherName == other.teacherName &&
          _deepEq(days, other.days) &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          room == other.room &&
          state == other.state &&
          status == other.status &&
          isActive == other.isActive &&
          groupArchived == other.groupArchived &&
          joinedAt == other.joinedAt &&
          leftAt == other.leftAt;

  @override
  int get hashCode => _hashProps(<Object?>[
        groupId,
        name,
        courseName,
        teacherName,
        days,
        startTime,
        endTime,
        room,
        state,
        status,
        isActive,
        groupArchived,
        joinedAt,
        leftAt,
      ]);
}

class StudentDashboard {
  final StudentProfile profile;
  final PortalMeta meta;
  final List<StudentLesson> todayLessons;
  final List<HomeworkItem> todayGrades;
  final double balance;
  final double monthlyFee;

  StudentDashboard({
    required this.profile,
    required this.meta,
    required this.todayLessons,
    required this.todayGrades,
    required this.balance,
    required this.monthlyFee,
  });

  factory StudentDashboard.fromJson(Map<String, dynamic> j) => StudentDashboard(
        profile: StudentProfile.fromJson(_map(j['profile'])),
        meta: PortalMeta.fromJson(_map(j['meta'])),
        todayLessons: _list(j['todayLessons'], StudentLesson.fromJson),
        todayGrades: _list(j['todayGrades'], HomeworkItem.fromJson),
        balance: _d(j['balance']),
        monthlyFee: _d(j['monthlyFee']),
      );

  /// `StudentDashboard.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'profile': profile.toJson(),
        'meta': meta.toJson(),
        'todayLessons': todayLessons.map((e) => e.toJson()).toList(),
        'todayGrades': todayGrades.map((e) => e.toJson()).toList(),
        'balance': balance,
        'monthlyFee': monthlyFee,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentDashboard &&
          profile == other.profile &&
          meta == other.meta &&
          _deepEq(todayLessons, other.todayLessons) &&
          _deepEq(todayGrades, other.todayGrades) &&
          balance == other.balance &&
          monthlyFee == other.monthlyFee;

  @override
  int get hashCode => _hashProps(<Object?>[
        profile,
        meta,
        todayLessons,
        todayGrades,
        balance,
        monthlyFee,
      ]);
}

class SubjectRef {
  final String id;
  final String name;

  SubjectRef({required this.id, required this.name});

  factory SubjectRef.fromJson(Map<String, dynamic> j) => SubjectRef(id: _s(j['id']), name: _s(j['name']));

  /// `SubjectRef.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectRef &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        name,
      ]);
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

  /// `StudentAttendanceSummary.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'missedDays': missedDays,
        'illnessDays': illnessDays,
        'missedLessons': missedLessons,
        'illnessLessons': illnessLessons,
        'lateCount': lateCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAttendanceSummary &&
          _deepEq(missedDays, other.missedDays) &&
          _deepEq(illnessDays, other.illnessDays) &&
          _deepEq(missedLessons, other.missedLessons) &&
          _deepEq(illnessLessons, other.illnessLessons) &&
          _deepEq(lateCount, other.lateCount);

  @override
  int get hashCode => _hashProps(<Object?>[
        missedDays,
        illnessDays,
        missedLessons,
        illnessLessons,
        lateCount,
      ]);
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

  /// `StudentGradesReport.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'studentId': studentId,
        'fullName': fullName,
        'className': className,
        'homeroomTeacher': homeroomTeacher,
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'grades': grades,
        'attendance': attendance.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGradesReport &&
          studentId == other.studentId &&
          fullName == other.fullName &&
          className == other.className &&
          homeroomTeacher == other.homeroomTeacher &&
          _deepEq(subjects, other.subjects) &&
          _deepEq(grades, other.grades) &&
          attendance == other.attendance;

  @override
  int get hashCode => _hashProps(<Object?>[
        studentId,
        fullName,
        className,
        homeroomTeacher,
        subjects,
        grades,
        attendance,
      ]);
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

  /// `AbsenceRow.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'period': period,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'reasonId': reasonId,
        'reasonName': reasonName,
        'isLate': isLate,
        'isIll': isIll,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbsenceRow &&
          date == other.date &&
          period == other.period &&
          subjectId == other.subjectId &&
          subjectName == other.subjectName &&
          reasonId == other.reasonId &&
          reasonName == other.reasonName &&
          isLate == other.isLate &&
          isIll == other.isIll;

  @override
  int get hashCode => _hashProps(<Object?>[
        date,
        period,
        subjectId,
        subjectName,
        reasonId,
        reasonName,
        isLate,
        isIll,
      ]);
}

class StudentAttendanceFull {
  final StudentAttendanceSummary summary;
  final List<AbsenceRow> rows;

  StudentAttendanceFull({required this.summary, required this.rows});

  factory StudentAttendanceFull.fromJson(Map<String, dynamic> j) => StudentAttendanceFull(
        summary: StudentAttendanceSummary.fromJson(_map(j['summary'])),
        rows: _list(j['rows'], AbsenceRow.fromJson),
      );

  /// `StudentAttendanceFull.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'summary': summary.toJson(),
        'rows': rows.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAttendanceFull &&
          summary == other.summary &&
          _deepEq(rows, other.rows);

  @override
  int get hashCode => _hashProps(<Object?>[
        summary,
        rows,
      ]);
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

  /// `RatingRow.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rank': rank,
        'studentId': studentId,
        'fullName': fullName,
        'className': className,
        'average': average,
        'attendance': attendance,
        'ball': ball,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatingRow &&
          rank == other.rank &&
          studentId == other.studentId &&
          fullName == other.fullName &&
          className == other.className &&
          average == other.average &&
          attendance == other.attendance &&
          ball == other.ball;

  @override
  int get hashCode => _hashProps(<Object?>[
        rank,
        studentId,
        fullName,
        className,
        average,
        attendance,
        ball,
      ]);
}

/// O'quvchining BITTA guruhi bo'yicha reyting (server `PortalRatingGroupDto`).
///
/// NEGA ALOHIDA: loyihada bir o'quvchi bir necha kursda (guruhda) o'qishi odatiy
/// hol, shuning uchun "guruh reytingi" bitta ro'yxat emas — har guruh o'z
/// ro'yxati va o'z o'rni bilan keladi. Ichkaridagi `rank` guruh ICHIDA qayta
/// raqamlangan (1,2,3...) — podium shunga tayanadi.
class RatingGroup {
  /// Guruh id'si. Faol a'zoligi yo'q (eski) o'quvchida server bo'sh satr
  /// qaytaradi va `groupName` eski `ClassName` yorlig'i bo'ladi.
  final String groupId;
  final String groupName;
  final List<RatingRow> rows;

  /// O'quvchining shu guruhdagi o'rni; 0 — ro'yxatda yo'q.
  final int meRank;

  /// Guruhdagi jami o'quvchi (odatda `rows.length`, lekin serverdan keladi).
  final int size;

  RatingGroup({
    required this.groupId,
    required this.groupName,
    required this.rows,
    required this.meRank,
    required this.size,
  });

  factory RatingGroup.fromJson(Map<String, dynamic> j) => RatingGroup(
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        rows: _list(j['rows'], RatingRow.fromJson),
        meRank: _i(j['meRank']),
        size: _i(j['size']),
      );

  /// `RatingGroup.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupId': groupId,
        'groupName': groupName,
        'rows': rows.map((e) => e.toJson()).toList(),
        'meRank': meRank,
        'size': size,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatingGroup &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          _deepEq(rows, other.rows) &&
          meRank == other.meRank &&
          size == other.size;

  @override
  int get hashCode => _hashProps(<Object?>[
        groupId,
        groupName,
        rows,
        meRank,
        size,
      ]);
}

class StudentRating {
  final String meStudentId;

  /// ESKI maydon — server uni birinchi guruh qatorlari bilan to'ldiradi
  /// (orqaga moslik). Yangi kod `groups` dan foydalanadi.
  final List<RatingRow> classRows;
  final List<RatingRow> schoolRows;
  final int? meSchoolRank;
  final int schoolSize;

  /// HAR BIR faol guruh alohida. HECH QACHON null emas (bo'sh bo'lishi mumkin).
  final List<RatingGroup> groups;

  StudentRating({
    required this.meStudentId,
    required this.classRows,
    required this.schoolRows,
    this.meSchoolRank,
    required this.schoolSize,
    this.groups = const <RatingGroup>[],
  });

  factory StudentRating.fromJson(Map<String, dynamic> j) {
    final classRows = _list(j['classRows'], RatingRow.fromJson);
    var groups = _list(j['groups'], RatingGroup.fromJson);
    // ESKI SERVER (`groups` yubormaydi) bilan ham ishlash uchun: mavjud
    // `classRows` dan bitta guruh yasaymiz — aks holda "Guruh" rejimi bo'sh
    // qolib, ilova eski backendda ishlamay qolardi.
    if (groups.isEmpty && classRows.isNotEmpty) {
      final meId = _s(j['meStudentId']);
      final meIdx = classRows.indexWhere((r) => r.studentId == meId);
      groups = <RatingGroup>[
        RatingGroup(
          groupId: '',
          // Nom serverdan kelmaydi — o'z qatorimizdagi yorliqni olamiz.
          groupName: meIdx >= 0 ? classRows[meIdx].className : '',
          rows: classRows,
          meRank: meIdx >= 0 ? classRows[meIdx].rank : 0,
          size: classRows.length,
        ),
      ];
    }
    return StudentRating(
      meStudentId: _s(j['meStudentId']),
      classRows: classRows,
      schoolRows: _list(j['schoolRows'], RatingRow.fromJson),
      meSchoolRank: _in(j['meSchoolRank']),
      schoolSize: _i(j['schoolSize']),
      groups: groups,
    );
  }

  /// `StudentRating.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'meStudentId': meStudentId,
        'classRows': classRows.map((e) => e.toJson()).toList(),
        'schoolRows': schoolRows.map((e) => e.toJson()).toList(),
        'meSchoolRank': meSchoolRank,
        'schoolSize': schoolSize,
        'groups': groups.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentRating &&
          meStudentId == other.meStudentId &&
          _deepEq(classRows, other.classRows) &&
          _deepEq(schoolRows, other.schoolRows) &&
          meSchoolRank == other.meSchoolRank &&
          schoolSize == other.schoolSize &&
          _deepEq(groups, other.groups);

  @override
  int get hashCode => _hashProps(<Object?>[
        meStudentId,
        classRows,
        schoolRows,
        meSchoolRank,
        schoolSize,
        groups,
      ]);
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

  /// `SpeakingWord.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'word': word,
        'accuracy': accuracy,
        'errorType': errorType,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeakingWord &&
          word == other.word &&
          accuracy == other.accuracy &&
          errorType == other.errorType;

  @override
  int get hashCode => _hashProps(<Object?>[
        word,
        accuracy,
        errorType,
      ]);
}

class MonthCourse {
  final String courseName;
  final double fee;

  MonthCourse({required this.courseName, required this.fee});

  factory MonthCourse.fromJson(Map<String, dynamic> j) => MonthCourse(
        courseName: _s(j['courseName']),
        fee: _d(j['fee']),
      );

  /// `MonthCourse.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'courseName': courseName,
        'fee': fee,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthCourse &&
          courseName == other.courseName &&
          fee == other.fee;

  @override
  int get hashCode => _hashProps(<Object?>[
        courseName,
        fee,
      ]);
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

  /// `MonthLedger.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'month': month,
        'charged': charged,
        'discount': discount,
        'paid': paid,
        'remaining': remaining,
        'status': status,
        'courses': courses.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthLedger &&
          month == other.month &&
          charged == other.charged &&
          discount == other.discount &&
          paid == other.paid &&
          remaining == other.remaining &&
          status == other.status &&
          _deepEq(courses, other.courses);

  @override
  int get hashCode => _hashProps(<Object?>[
        month,
        charged,
        discount,
        paid,
        remaining,
        status,
        courses,
      ]);
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

  /// `StudentPayment.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'amount': amount,
        'note': note,
        'month': month,
        'comment': comment,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentPayment &&
          date == other.date &&
          amount == other.amount &&
          note == other.note &&
          month == other.month &&
          comment == other.comment;

  @override
  int get hashCode => _hashProps(<Object?>[
        date,
        amount,
        note,
        month,
        comment,
      ]);
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

  /// `StudentFinanceStudent.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fullName': fullName,
        'className': className,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentFinanceStudent &&
          id == other.id &&
          fullName == other.fullName &&
          className == other.className;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        fullName,
        className,
      ]);
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

  /// `StudentFinance.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'student': student.toJson(),
        'balance': balance,
        'monthlyFee': monthlyFee,
        'totalCharged': totalCharged,
        'totalDiscount': totalDiscount,
        'totalPaid': totalPaid,
        'months': months.map((e) => e.toJson()).toList(),
        'payments': payments.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentFinance &&
          student == other.student &&
          balance == other.balance &&
          monthlyFee == other.monthlyFee &&
          totalCharged == other.totalCharged &&
          totalDiscount == other.totalDiscount &&
          totalPaid == other.totalPaid &&
          _deepEq(months, other.months) &&
          _deepEq(payments, other.payments);

  @override
  int get hashCode => _hashProps(<Object?>[
        student,
        balance,
        monthlyFee,
        totalCharged,
        totalDiscount,
        totalPaid,
        months,
        payments,
      ]);
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

  /// `StudentChatMessage.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'className': className,
        'senderUserId': senderUserId,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'createdAt': createdAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentChatMessage &&
          id == other.id &&
          className == other.className &&
          senderUserId == other.senderUserId &&
          senderName == other.senderName &&
          senderRole == other.senderRole &&
          text == other.text &&
          createdAt == other.createdAt;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        className,
        senderUserId,
        senderName,
        senderRole,
        text,
        createdAt,
      ]);
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

  /// `UserSettings.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'language': language,
        'theme': theme,
        'notificationsEnabled': notificationsEnabled,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          language == other.language &&
          theme == other.theme &&
          notificationsEnabled == other.notificationsEnabled;

  @override
  int get hashCode => _hashProps(<Object?>[
        language,
        theme,
        notificationsEnabled,
      ]);
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

  /// `TelegramStatus.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'configured': configured,
        'botUsername': botUsername,
        'botName': botName,
        'deepLink': deepLink,
        'registered': registered,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelegramStatus &&
          configured == other.configured &&
          botUsername == other.botUsername &&
          botName == other.botName &&
          deepLink == other.deepLink &&
          registered == other.registered;

  @override
  int get hashCode => _hashProps(<Object?>[
        configured,
        botUsername,
        botName,
        deepLink,
        registered,
      ]);
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

  /// `StudentLocation.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'updatedAt': updatedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentLocation &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          address == other.address &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => _hashProps(<Object?>[
        latitude,
        longitude,
        address,
        updatedAt,
      ]);
}

class StudentSchoolInfo {
  final String name;
  final String telegramChannel;

  StudentSchoolInfo({required this.name, required this.telegramChannel});

  factory StudentSchoolInfo.fromJson(Map<String, dynamic> j) => StudentSchoolInfo(
        name: _s(j['name']),
        telegramChannel: _s(j['telegramChannel']),
      );

  /// `StudentSchoolInfo.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'telegramChannel': telegramChannel,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentSchoolInfo &&
          name == other.name &&
          telegramChannel == other.telegramChannel;

  @override
  int get hashCode => _hashProps(<Object?>[
        name,
        telegramChannel,
      ]);
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

  /// `CurriculumItem.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'note': note,
        'order': order,
        'covered': covered,
        'coveredDate': coveredDate,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumItem &&
          id == other.id &&
          text == other.text &&
          note == other.note &&
          order == other.order &&
          covered == other.covered &&
          coveredDate == other.coveredDate;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        text,
        note,
        order,
        covered,
        coveredDate,
      ]);
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

  /// `CurriculumTopic.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'note': note,
        'order': order,
        'items': items.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumTopic &&
          id == other.id &&
          title == other.title &&
          note == other.note &&
          order == other.order &&
          _deepEq(items, other.items);

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        title,
        note,
        order,
        items,
      ]);
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

  /// `CurriculumLevel.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'note': note,
        'order': order,
        'topics': topics.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumLevel &&
          id == other.id &&
          name == other.name &&
          note == other.note &&
          order == other.order &&
          _deepEq(topics, other.topics);

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        name,
        note,
        order,
        topics,
      ]);
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
        // `??` yetarli emas: bo'sh RO'YXAT null emas, shuning uchun ikkalasi ham
        // kelganda (levels: [], modules: [...]) ekran bo'sh qolardi.
        levels: () {
          final lv = _list(j['levels'], CurriculumLevel.fromJson);
          return lv.isNotEmpty ? lv : _list(j['modules'], CurriculumLevel.fromJson);
        }(),
      );

  /// `StudentCurriculum.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupId': groupId,
        'courseId': courseId,
        'courseName': courseName,
        'totalItems': totalItems,
        'coveredCount': coveredCount,
        'revisionLessons': revisionLessons,
        'totalLessons': totalLessons,
        'remainingItems': remainingItems,
        'estLessonsLeft': estLessonsLeft,
        'lessonsPerWeek': lessonsPerWeek,
        'estFinishDate': estFinishDate,
        'levels': levels.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentCurriculum &&
          groupId == other.groupId &&
          courseId == other.courseId &&
          courseName == other.courseName &&
          totalItems == other.totalItems &&
          coveredCount == other.coveredCount &&
          revisionLessons == other.revisionLessons &&
          totalLessons == other.totalLessons &&
          remainingItems == other.remainingItems &&
          estLessonsLeft == other.estLessonsLeft &&
          lessonsPerWeek == other.lessonsPerWeek &&
          estFinishDate == other.estFinishDate &&
          _deepEq(levels, other.levels);

  @override
  int get hashCode => _hashProps(<Object?>[
        groupId,
        courseId,
        courseName,
        totalItems,
        coveredCount,
        revisionLessons,
        totalLessons,
        remainingItems,
        estLessonsLeft,
        lessonsPerWeek,
        estFinishDate,
        levels,
      ]);
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

  /// `StudentGradingCriterion.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'done': done,
        'total': total,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGradingCriterion &&
          id == other.id &&
          name == other.name &&
          done == other.done &&
          total == other.total;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        name,
        done,
        total,
      ]);
}

class StudentGradingDate {
  final String date;
  final List<String> doneCriterionIds;

  StudentGradingDate({required this.date, required this.doneCriterionIds});

  factory StudentGradingDate.fromJson(Map<String, dynamic> j) => StudentGradingDate(
        date: _s(j['date']),
        doneCriterionIds: _strList(j['doneCriterionIds']),
      );

  /// `StudentGradingDate.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'doneCriterionIds': doneCriterionIds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGradingDate &&
          date == other.date &&
          _deepEq(doneCriterionIds, other.doneCriterionIds);

  @override
  int get hashCode => _hashProps(<Object?>[
        date,
        doneCriterionIds,
      ]);
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

  /// `StudentGradingGroup.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupId': groupId,
        'groupName': groupName,
        'months': months,
        'month': month,
        'dates': dates,
        'criteria': criteria.map((e) => e.toJson()).toList(),
        'lessons': lessons.map((e) => e.toJson()).toList(),
        'monthBall': monthBall,
        'totalBall': totalBall,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGradingGroup &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          _deepEq(months, other.months) &&
          month == other.month &&
          _deepEq(dates, other.dates) &&
          _deepEq(criteria, other.criteria) &&
          _deepEq(lessons, other.lessons) &&
          monthBall == other.monthBall &&
          totalBall == other.totalBall;

  @override
  int get hashCode => _hashProps(<Object?>[
        groupId,
        groupName,
        months,
        month,
        dates,
        criteria,
        lessons,
        monthBall,
        totalBall,
      ]);
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

  /// `LessonVocab.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'term': term,
        'meaning': meaning,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonVocab &&
          term == other.term &&
          meaning == other.meaning;

  @override
  int get hashCode => _hashProps(<Object?>[
        term,
        meaning,
      ]);
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

  /// `LessonQuestion.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonQuestion &&
          id == other.id &&
          text == other.text &&
          _deepEq(options, other.options) &&
          correctIndex == other.correctIndex;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        text,
        options,
        correctIndex,
      ]);
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

  /// `LessonContent.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'topicId': topicId,
        'text': text,
        'note': note,
        'order': order,
        'type': type,
        'videoUrl': videoUrl,
        'audioUrl': audioUrl,
        'textContent': textContent,
        'pdfUrl': pdfUrl,
        'pdfName': pdfName,
        'meta': meta,
        'vocab': vocab.map((e) => e.toJson()).toList(),
        'questions': questions.map((e) => e.toJson()).toList(),
        'exerciseKind': exerciseKind,
        'exerciseJson': exerciseJson,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonContent &&
          id == other.id &&
          topicId == other.topicId &&
          text == other.text &&
          note == other.note &&
          order == other.order &&
          type == other.type &&
          videoUrl == other.videoUrl &&
          audioUrl == other.audioUrl &&
          textContent == other.textContent &&
          pdfUrl == other.pdfUrl &&
          pdfName == other.pdfName &&
          meta == other.meta &&
          _deepEq(vocab, other.vocab) &&
          _deepEq(questions, other.questions) &&
          exerciseKind == other.exerciseKind &&
          exerciseJson == other.exerciseJson;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        topicId,
        text,
        note,
        order,
        type,
        videoUrl,
        audioUrl,
        textContent,
        pdfUrl,
        pdfName,
        meta,
        vocab,
        questions,
        exerciseKind,
        exerciseJson,
      ]);
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

  /// `AttendanceReasonCount.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'reasonId': reasonId,
        'name': name,
        'short': short,
        'isLate': isLate,
        'count': count,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceReasonCount &&
          reasonId == other.reasonId &&
          name == other.name &&
          short == other.short &&
          isLate == other.isLate &&
          count == other.count;

  @override
  int get hashCode => _hashProps(<Object?>[
        reasonId,
        name,
        short,
        isLate,
        count,
      ]);
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

  /// `MonthlyAttendance.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'missedDays': missedDays,
        'illnessDays': illnessDays,
        'missedLessons': missedLessons,
        'illnessLessons': illnessLessons,
        'lateCount': lateCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyAttendance &&
          _deepEq(missedDays, other.missedDays) &&
          _deepEq(illnessDays, other.illnessDays) &&
          _deepEq(missedLessons, other.missedLessons) &&
          _deepEq(illnessLessons, other.illnessLessons) &&
          _deepEq(lateCount, other.lateCount);

  @override
  int get hashCode => _hashProps(<Object?>[
        missedDays,
        illnessDays,
        missedLessons,
        illnessLessons,
        lateCount,
      ]);
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

  /// `MonthMarks.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'month': month,
        'homeworkDone': homeworkDone,
        'homeworkMissed': homeworkMissed,
        'behaviorGood': behaviorGood,
        'behaviorBad': behaviorBad,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthMarks &&
          month == other.month &&
          homeworkDone == other.homeworkDone &&
          homeworkMissed == other.homeworkMissed &&
          behaviorGood == other.behaviorGood &&
          behaviorBad == other.behaviorBad;

  @override
  int get hashCode => _hashProps(<Object?>[
        month,
        homeworkDone,
        homeworkMissed,
        behaviorGood,
        behaviorBad,
      ]);
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
        homeworkDone: _i(j['homeworkDone']),
        homeworkMissed: _i(j['homeworkMissed']),
        behaviorGood: _i(j['behaviorGood']),
        behaviorBad: _i(j['behaviorBad']),
        marksTrend: _list(j['marksTrend'], MonthMarks.fromJson),
      );

  /// `StudentNotebook.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fullName': fullName,
        'className': className,
        'balance': balance,
        'avgGrade': avgGrade,
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'grades': grades,
        'attendance': attendance.toJson(),
        'conducted': conducted,
        'attended': attended,
        'attendancePct': attendancePct,
        'reasons': reasons.map((e) => e.toJson()).toList(),
        'homeworkDone': homeworkDone,
        'homeworkMissed': homeworkMissed,
        'behaviorGood': behaviorGood,
        'behaviorBad': behaviorBad,
        'marksTrend': marksTrend.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentNotebook &&
          id == other.id &&
          fullName == other.fullName &&
          className == other.className &&
          balance == other.balance &&
          avgGrade == other.avgGrade &&
          _deepEq(subjects, other.subjects) &&
          _deepEq(grades, other.grades) &&
          attendance == other.attendance &&
          conducted == other.conducted &&
          attended == other.attended &&
          attendancePct == other.attendancePct &&
          _deepEq(reasons, other.reasons) &&
          homeworkDone == other.homeworkDone &&
          homeworkMissed == other.homeworkMissed &&
          behaviorGood == other.behaviorGood &&
          behaviorBad == other.behaviorBad &&
          _deepEq(marksTrend, other.marksTrend);

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        fullName,
        className,
        balance,
        avgGrade,
        subjects,
        grades,
        attendance,
        conducted,
        attended,
        attendancePct,
        reasons,
        homeworkDone,
        homeworkMissed,
        behaviorGood,
        behaviorBad,
        marksTrend,
      ]);
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

  /// `AppNotification.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': createdAt,
        'read': read,
        'confirmed': confirmed,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          id == other.id &&
          title == other.title &&
          body == other.body &&
          type == other.type &&
          createdAt == other.createdAt &&
          read == other.read &&
          confirmed == other.confirmed;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        title,
        body,
        type,
        createdAt,
        read,
        confirmed,
      ]);
}

class NotificationsResponse {
  final int unread;
  final List<AppNotification> items;

  NotificationsResponse({required this.unread, required this.items});

  factory NotificationsResponse.fromJson(Map<String, dynamic> j) => NotificationsResponse(
        unread: _i(j['unread']),
        items: _list(j['items'], AppNotification.fromJson),
      );

  /// `NotificationsResponse.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'unread': unread,
        'items': items.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationsResponse &&
          unread == other.unread &&
          _deepEq(items, other.items);

  @override
  int get hashCode => _hashProps(<Object?>[
        unread,
        items,
      ]);
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

  /// `StudentCertificateDto.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'courseName': courseName,
        'issuedAt': issuedAt,
        'expiresAt': expiresAt,
        'status': status,
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'downloadCount': downloadCount,
        'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentCertificateDto &&
          id == other.id &&
          courseName == other.courseName &&
          issuedAt == other.issuedAt &&
          expiresAt == other.expiresAt &&
          status == other.status &&
          fileName == other.fileName &&
          downloadUrl == other.downloadUrl &&
          downloadCount == other.downloadCount &&
          _deepEq(metadata, other.metadata);

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        courseName,
        issuedAt,
        expiresAt,
        status,
        fileName,
        downloadUrl,
        downloadCount,
        metadata,
      ]);
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

  /// `StudentTestResult.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'testId': testId,
        'groupId': groupId,
        'groupName': groupName,
        'name': name,
        'date': date,
        'maxScore': maxScore,
        'score': score,
        'rank': rank,
        'total': total,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentTestResult &&
          testId == other.testId &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          name == other.name &&
          date == other.date &&
          maxScore == other.maxScore &&
          score == other.score &&
          rank == other.rank &&
          total == other.total;

  @override
  int get hashCode => _hashProps(<Object?>[
        testId,
        groupId,
        groupName,
        name,
        date,
        maxScore,
        score,
        rank,
        total,
      ]);
}

// ---------- ONLAYN TEST (bot bilan bir xil: PDF savollar + javob kiritish) ----------

/// O'quvchiga ochilgan onlayn test. `state`: `upcoming` | `open` | `closed` | `submitted`.
class OnlineTest {
  final String id;
  final String groupId;
  final String groupName;
  final String name;
  final String date;
  final int questionCount;
  final int optionCount;

  /// Javob qabul qilish oynasi ("yyyy-MM-ddTHH:mm").
  final String startAt;
  final String endAt;

  /// Savollar fayli ("/uploads/...") — TOKEN talab qiladi, `openServerFile` bilan ochiladi.
  final String pdfUrl;
  final String pdfName;
  final String state;

  /// Topshirilgan bo'lsa — to'g'ri javoblar soni va yuborilgan javoblar ("ABCD…").
  final double? score;
  final String answers;
  final String submittedAt;

  OnlineTest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.name,
    required this.date,
    required this.questionCount,
    required this.optionCount,
    required this.startAt,
    required this.endAt,
    required this.pdfUrl,
    required this.pdfName,
    required this.state,
    this.score,
    required this.answers,
    required this.submittedAt,
  });

  bool get isOpen => state == 'open';
  bool get isSubmitted => state == 'submitted';

  factory OnlineTest.fromJson(Map<String, dynamic> j) => OnlineTest(
        id: _s(j['id']),
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        name: _s(j['name']),
        date: _s(j['date']),
        questionCount: _i(j['questionCount']),
        optionCount: _i(j['optionCount']),
        startAt: _s(j['startAt']),
        endAt: _s(j['endAt']),
        pdfUrl: _s(j['pdfUrl']),
        pdfName: _s(j['pdfName']),
        state: _s(j['state']),
        score: _dn(j['score']),
        answers: _s(j['answers']),
        submittedAt: _s(j['submittedAt']),
      );

  /// `OnlineTest.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'groupId': groupId,
        'groupName': groupName,
        'name': name,
        'date': date,
        'questionCount': questionCount,
        'optionCount': optionCount,
        'startAt': startAt,
        'endAt': endAt,
        'pdfUrl': pdfUrl,
        'pdfName': pdfName,
        'state': state,
        'score': score,
        'answers': answers,
        'submittedAt': submittedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineTest &&
          id == other.id &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          name == other.name &&
          date == other.date &&
          questionCount == other.questionCount &&
          optionCount == other.optionCount &&
          startAt == other.startAt &&
          endAt == other.endAt &&
          pdfUrl == other.pdfUrl &&
          pdfName == other.pdfName &&
          state == other.state &&
          score == other.score &&
          answers == other.answers &&
          submittedAt == other.submittedAt;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        groupId,
        groupName,
        name,
        date,
        questionCount,
        optionCount,
        startAt,
        endAt,
        pdfUrl,
        pdfName,
        state,
        score,
        answers,
        submittedAt,
      ]);
}

/// Onlayn test tafsiloti — qator ma'lumoti + o'rin va (vaqt tugagach) javob kaliti.
class OnlineTestDetail {
  final OnlineTest test;

  /// Javob kaliti — test vaqti TUGAGUNCHA bo'sh keladi.
  final String answerKey;
  final int rank;
  final int participants;

  OnlineTestDetail({
    required this.test,
    required this.answerKey,
    required this.rank,
    required this.participants,
  });

  factory OnlineTestDetail.fromJson(Map<String, dynamic> j) => OnlineTestDetail(
        test: OnlineTest.fromJson(j),
        answerKey: _s(j['answerKey']),
        rank: _i(j['rank']),
        participants: _i(j['participants']),
      );

  /// Server YASSI tuzilma qaytaradi (`OnlineTest.fromJson(j)` ayni map'dan
  /// o'qiydi) — shuning uchun ichki test maydonlari yoyib yoziladi.
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...test.toJson(),
        'answerKey': answerKey,
        'rank': rank,
        'participants': participants,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineTestDetail &&
          test == other.test &&
          answerKey == other.answerKey &&
          rank == other.rank &&
          participants == other.participants;

  @override
  int get hashCode => _hashProps(<Object?>[
        test,
        answerKey,
        rank,
        participants,
      ]);
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

  /// `AiCheckScores.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'grammar': grammar,
        'vocabulary': vocabulary,
        'coherence': coherence,
        'task': task,
        'mechanics': mechanics,
        'pronunciation': pronunciation,
        'fluency': fluency,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCheckScores &&
          grammar == other.grammar &&
          vocabulary == other.vocabulary &&
          coherence == other.coherence &&
          task == other.task &&
          mechanics == other.mechanics &&
          pronunciation == other.pronunciation &&
          fluency == other.fluency;

  @override
  int get hashCode => _hashProps(<Object?>[
        grammar,
        vocabulary,
        coherence,
        task,
        mechanics,
        pronunciation,
        fluency,
      ]);
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

  /// `AiCorrection.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'original': original,
        'suggestion': suggestion,
        'explanation': explanation,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCorrection &&
          original == other.original &&
          suggestion == other.suggestion &&
          explanation == other.explanation;

  @override
  int get hashCode => _hashProps(<Object?>[
        original,
        suggestion,
        explanation,
      ]);
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

  /// `AiVocab.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'word': word,
        'suggestion': suggestion,
        'note': note,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiVocab &&
          word == other.word &&
          suggestion == other.suggestion &&
          note == other.note;

  @override
  int get hashCode => _hashProps(<Object?>[
        word,
        suggestion,
        note,
      ]);
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

  /// `AiCheckIelts.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'task': task,
        'coherence': coherence,
        'lexical': lexical,
        'grammar': grammar,
        'overall': overall,
        'taskType': taskType,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCheckIelts &&
          task == other.task &&
          coherence == other.coherence &&
          lexical == other.lexical &&
          grammar == other.grammar &&
          overall == other.overall &&
          taskType == other.taskType;

  @override
  int get hashCode => _hashProps(<Object?>[
        task,
        coherence,
        lexical,
        grammar,
        overall,
        taskType,
      ]);
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

  /// `AiCheckAnalysis.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'overall': overall,
        'level': level,
        'scores': scores.toJson(),
        'summary': summary,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'corrections': corrections.map((e) => e.toJson()).toList(),
        'vocabulary': vocabulary.map((e) => e.toJson()).toList(),
        'improved': improved,
        'recommendations': recommendations,
        'ielts': ielts?.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCheckAnalysis &&
          overall == other.overall &&
          level == other.level &&
          scores == other.scores &&
          summary == other.summary &&
          _deepEq(strengths, other.strengths) &&
          _deepEq(weaknesses, other.weaknesses) &&
          _deepEq(corrections, other.corrections) &&
          _deepEq(vocabulary, other.vocabulary) &&
          improved == other.improved &&
          _deepEq(recommendations, other.recommendations) &&
          ielts == other.ielts;

  @override
  int get hashCode => _hashProps(<Object?>[
        overall,
        level,
        scores,
        summary,
        strengths,
        weaknesses,
        corrections,
        vocabulary,
        improved,
        recommendations,
        ielts,
      ]);
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

  /// `AiCheckSpeech.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'recognizedText': recognizedText,
        'pronScore': pronScore,
        'accuracy': accuracy,
        'fluency': fluency,
        'completeness': completeness,
        'prosody': prosody,
        'words': words.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCheckSpeech &&
          recognizedText == other.recognizedText &&
          pronScore == other.pronScore &&
          accuracy == other.accuracy &&
          fluency == other.fluency &&
          completeness == other.completeness &&
          prosody == other.prosody &&
          _deepEq(words, other.words);

  @override
  int get hashCode => _hashProps(<Object?>[
        recognizedText,
        pronScore,
        accuracy,
        fluency,
        completeness,
        prosody,
        words,
      ]);
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

  /// `AiCheck.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'prompt': prompt,
        'inputText': inputText,
        'recognizedText': recognizedText,
        'audioUrl': audioUrl,
        'score': score,
        'date': date,
        'createdAt': createdAt,
        'analysis': analysis?.toJson(),
        'speech': speech?.toJson(),
        'taskType': taskType,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCheck &&
          id == other.id &&
          type == other.type &&
          prompt == other.prompt &&
          inputText == other.inputText &&
          recognizedText == other.recognizedText &&
          audioUrl == other.audioUrl &&
          score == other.score &&
          date == other.date &&
          createdAt == other.createdAt &&
          analysis == other.analysis &&
          speech == other.speech &&
          taskType == other.taskType;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        type,
        prompt,
        inputText,
        recognizedText,
        audioUrl,
        score,
        date,
        createdAt,
        analysis,
        speech,
        taskType,
      ]);
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

  /// `AiCheckListItem.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'prompt': prompt,
        'score': score,
        'date': date,
        'createdAt': createdAt,
        'hasAudio': hasAudio,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCheckListItem &&
          id == other.id &&
          type == other.type &&
          prompt == other.prompt &&
          score == other.score &&
          date == other.date &&
          createdAt == other.createdAt &&
          hasAudio == other.hasAudio;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        type,
        prompt,
        score,
        date,
        createdAt,
        hasAudio,
      ]);
}

/// AI tekshiruv holati: bo'lim ochiqmi + kalitlar tayyorligi + limit/premium/blok.
class AiCheckStatus {
  final bool geminiReady;
  final bool azureReady;
  final bool premium;
  final bool blocked;
  final int limit;
  final int usedToday;
  final int remaining;

  /// Markaz bu bo'limni ilovada OCHGANMI (admin: Ilova → AI check → "Ilovada ochish").
  /// Kalitlar tayyorligidan MUSTAQIL: kalit bo'lsa ham, yopiq bo'lsa bo'lim ishlamaydi.
  final bool enabled;

  AiCheckStatus({
    required this.geminiReady,
    required this.azureReady,
    required this.premium,
    required this.blocked,
    required this.limit,
    required this.usedToday,
    required this.remaining,
    required this.enabled,
  });

  factory AiCheckStatus.fromJson(Map<String, dynamic> j) => AiCheckStatus(
        geminiReady: _b(j['geminiReady']),
        azureReady: _b(j['azureReady']),
        premium: _b(j['premium']),
        blocked: _b(j['blocked']),
        limit: _i(j['limit']),
        usedToday: _i(j['usedToday']),
        remaining: _i(j['remaining']),
        // ORQAGA MOSLIK: maydon UMUMAN kelmasa (server hali yangilanmagan) — OCHIQ deb
        // hisoblaymiz, aks holda yangi ilova eski serverga ulanganda bo'lim asossiz
        // "yopiq" bo'lib qolardi. Server yangi bo'lsa `false` ni aniq yuboradi.
        enabled: j['enabled'] == null ? true : _b(j['enabled']),
      );

  /// `AiCheckStatus.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'geminiReady': geminiReady,
        'azureReady': azureReady,
        'premium': premium,
        'blocked': blocked,
        'limit': limit,
        'usedToday': usedToday,
        'remaining': remaining,
        'enabled': enabled,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCheckStatus &&
          geminiReady == other.geminiReady &&
          azureReady == other.azureReady &&
          premium == other.premium &&
          blocked == other.blocked &&
          limit == other.limit &&
          usedToday == other.usedToday &&
          remaining == other.remaining &&
          enabled == other.enabled;

  @override
  int get hashCode => _hashProps(<Object?>[
        geminiReady,
        azureReady,
        premium,
        blocked,
        limit,
        usedToday,
        remaining,
        enabled,
      ]);
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

  /// `toJson` bilan simmetrik — keshdan/serverdan qayta o'qish uchun.
  factory AttemptAnswer.fromJson(Map<String, dynamic> j) => AttemptAnswer(
        index: _i(j['index']),
        prompt: _s(j['prompt']),
        answer: _s(j['answer']),
        expected: _s(j['expected']),
        ok: _b(j['ok']),
        sec: _i(j['sec']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptAnswer &&
          index == other.index &&
          prompt == other.prompt &&
          answer == other.answer &&
          expected == other.expected &&
          ok == other.ok &&
          sec == other.sec;

  @override
  int get hashCode => _hashProps(<Object?>[
        index,
        prompt,
        answer,
        expected,
        ok,
        sec,
      ]);
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

  /// `StudentSupportSlot.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentSupportSlot &&
          id == other.id &&
          date == other.date &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        date,
        startTime,
        endTime,
      ]);
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

  /// `StudentSupportTeacher.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'teacherId': teacherId,
        'fullName': fullName,
        'photoUrl': photoUrl,
        'subject': subject,
        'openSlots': openSlots.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentSupportTeacher &&
          teacherId == other.teacherId &&
          fullName == other.fullName &&
          photoUrl == other.photoUrl &&
          subject == other.subject &&
          _deepEq(openSlots, other.openSlots);

  @override
  int get hashCode => _hashProps(<Object?>[
        teacherId,
        fullName,
        photoUrl,
        subject,
        openSlots,
      ]);
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

  /// `StudentSupportBooking.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'status': status,
        'topic': topic,
        'notes': notes,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentSupportBooking &&
          id == other.id &&
          teacherId == other.teacherId &&
          teacherName == other.teacherName &&
          date == other.date &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          status == other.status &&
          topic == other.topic &&
          notes == other.notes;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        teacherId,
        teacherName,
        date,
        startTime,
        endTime,
        status,
        topic,
        notes,
      ]);
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

  /// `StudentSupport.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'supports': supports.map((e) => e.toJson()).toList(),
        'myBookings': myBookings.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentSupport &&
          _deepEq(supports, other.supports) &&
          _deepEq(myBookings, other.myBookings);

  @override
  int get hashCode => _hashProps(<Object?>[
        supports,
        myBookings,
      ]);
}

// ---------- Shartnoma (elektron nusxa) — web: `ContractDoc` ----------

/// Markaz o'quvchi/ota-ona bilan tuzgan shartnomaning saqlangan nusxasi.
/// `pdfUrl` — superadmin yuklagan PDF (server faqat shundaylarini qaytaradi),
/// `docxUrl` — tizim hosil qilgan Word nusxa (admin panelida ishlatiladi).
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
  final bool delivered;
  final String status;
  final bool visible;

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
    required this.delivered,
    required this.status,
    required this.visible,
  });

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
        delivered: _b(j['delivered']),
        status: _s(j['status']),
        visible: _b(j['visible']),
      );

  /// `ContractDoc.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'number': number,
        'title': title,
        'target': target,
        'recipientKey': recipientKey,
        'recipientName': recipientName,
        'templateName': templateName,
        'date': date,
        'pdfUrl': pdfUrl,
        'docxUrl': docxUrl,
        'delivered': delivered,
        'status': status,
        'visible': visible,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContractDoc &&
          id == other.id &&
          number == other.number &&
          title == other.title &&
          target == other.target &&
          recipientKey == other.recipientKey &&
          recipientName == other.recipientName &&
          templateName == other.templateName &&
          date == other.date &&
          pdfUrl == other.pdfUrl &&
          docxUrl == other.docxUrl &&
          delivered == other.delivered &&
          status == other.status &&
          visible == other.visible;

  @override
  int get hashCode => _hashProps(<Object?>[
        id,
        number,
        title,
        target,
        recipientKey,
        recipientName,
        templateName,
        date,
        pdfUrl,
        docxUrl,
        delivered,
        status,
        visible,
      ]);
}

// ---------- DAVR JURNALI ("Umumiy statistika" ekrani) ----------
//
// `GET /student/journal?from=&to=&groupId=` — HAFTA yoki OY oralig'idagi butun
// manzara BITTA javobda: jamlanma (davomat/baho/uy vazifasi/xulq), fanlar kesimi
// va HAR DARS uchun alohida qator. Ilgari bu ma'lumot uchta ekranga (Baholar,
// Davomat, Baholash) bo'lingan va uchta so'rov ketardi.
//
// DIQQAT (uslub): bu fayldagi boshqa DTO'lar kabi konstruktorlar `const` EMAS —
// `flutter_lints` dagi `prefer_const_constructors` chaqiruv joylarida (ekran/test)
// ortiqcha ogohlantirish berardi, model esa baribir o'zgarmas (barcha maydon `final`).

/// Javobdagi guruh elementi — davr ichida o'quvchi qatnashgan guruhlar (filtr ro'yxati).
///
/// MAVJUD `StudentGroupInfo` ATAYIN QAYTA ISHLATILMADI: u boshqa endpointning
/// (`/student/groups`) boshqa shakli — nom `name` kalitida, ustiga `days`,
/// `state`, `joinedAt` kabi o'nlab maydon bor. Uni shu javobga qo'llasak
/// `groupName` umuman o'qilmay, guruh nomi bo'sh bo'lib chiqardi.
class StudentPeriodGroup {
  final String groupId;
  final String groupName;
  final String courseName;
  final String teacherName;

  StudentPeriodGroup({
    required this.groupId,
    required this.groupName,
    required this.courseName,
    required this.teacherName,
  });

  factory StudentPeriodGroup.fromJson(Map<String, dynamic> j) => StudentPeriodGroup(
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        courseName: _s(j['courseName']),
        teacherName: _s(j['teacherName']),
      );

  /// `StudentPeriodGroup.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupId': groupId,
        'groupName': groupName,
        'courseName': courseName,
        'teacherName': teacherName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentPeriodGroup &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          courseName == other.courseName &&
          teacherName == other.teacherName;

  @override
  int get hashCode => _hashProps(<Object?>[
        groupId,
        groupName,
        courseName,
        teacherName,
      ]);
}

/// Davr jamlanmasi — ekran tepasidagi kartochkalar.
///
/// `attendancePct` — SERVER hisoblagan foiz (butun son). Ilova uni qayta
/// hisoblamaydi: "o'tilgan dars" tushunchasi (a'zolik boshlanishi, muzlatilgan
/// kunlar) faqat serverda to'liq ma'lum.
class StudentPeriodSummary {
  /// O'tilgan darslar soni.
  final int held;
  final int attended;
  final int absent;
  final int late;
  /// Davomat foizi (0-100), server hisoblagan.
  final int attendancePct;
  /// Qo'yilgan baholar soni (o'rtacha shundan chiqadi).
  final int gradesCount;
  /// O'rtacha baho. Baho umuman bo'lmasa 0 keladi — ekran `gradesCount == 0`
  /// bo'yicha "—" ko'rsatsin (0 ni "ikki" deb ko'rsatish noto'g'ri bo'lardi).
  final double avgGrade;
  final int homeworkDone;
  final int homeworkMissed;
  final int behaviorGood;
  final int behaviorBad;

  StudentPeriodSummary({
    required this.held,
    required this.attended,
    required this.absent,
    required this.late,
    required this.attendancePct,
    required this.gradesCount,
    required this.avgGrade,
    required this.homeworkDone,
    required this.homeworkMissed,
    required this.behaviorGood,
    required this.behaviorBad,
  });

  factory StudentPeriodSummary.fromJson(Map<String, dynamic> j) => StudentPeriodSummary(
        held: _i(j['held']),
        attended: _i(j['attended']),
        absent: _i(j['absent']),
        late: _i(j['late']),
        attendancePct: _i(j['attendancePct']),
        gradesCount: _i(j['gradesCount']),
        avgGrade: _d(j['avgGrade']),
        homeworkDone: _i(j['homeworkDone']),
        homeworkMissed: _i(j['homeworkMissed']),
        behaviorGood: _i(j['behaviorGood']),
        behaviorBad: _i(j['behaviorBad']),
      );

  /// `StudentPeriodSummary.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'held': held,
        'attended': attended,
        'absent': absent,
        'late': late,
        'attendancePct': attendancePct,
        'gradesCount': gradesCount,
        'avgGrade': avgGrade,
        'homeworkDone': homeworkDone,
        'homeworkMissed': homeworkMissed,
        'behaviorGood': behaviorGood,
        'behaviorBad': behaviorBad,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentPeriodSummary &&
          held == other.held &&
          attended == other.attended &&
          absent == other.absent &&
          late == other.late &&
          attendancePct == other.attendancePct &&
          gradesCount == other.gradesCount &&
          avgGrade == other.avgGrade &&
          homeworkDone == other.homeworkDone &&
          homeworkMissed == other.homeworkMissed &&
          behaviorGood == other.behaviorGood &&
          behaviorBad == other.behaviorBad;

  @override
  int get hashCode => _hashProps(<Object?>[
        held,
        attended,
        absent,
        late,
        attendancePct,
        gradesCount,
        avgGrade,
        homeworkDone,
        homeworkMissed,
        behaviorGood,
        behaviorBad,
      ]);
}

/// Fan (kurs) kesimi — davr ichida qaysi fandan qancha dars va qanday baho.
class StudentSubjectStat {
  final String subjectId;
  final String subjectName;
  final int held;
  final int attended;
  final int gradesCount;
  /// Shu fan bo'yicha o'rtacha baho (`gradesCount == 0` bo'lsa 0 — "—" deb ko'rsatiladi).
  final double avgGrade;

  StudentSubjectStat({
    required this.subjectId,
    required this.subjectName,
    required this.held,
    required this.attended,
    required this.gradesCount,
    required this.avgGrade,
  });

  factory StudentSubjectStat.fromJson(Map<String, dynamic> j) => StudentSubjectStat(
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        held: _i(j['held']),
        attended: _i(j['attended']),
        gradesCount: _i(j['gradesCount']),
        avgGrade: _d(j['avgGrade']),
      );

  /// `StudentSubjectStat.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'subjectId': subjectId,
        'subjectName': subjectName,
        'held': held,
        'attended': attended,
        'gradesCount': gradesCount,
        'avgGrade': avgGrade,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentSubjectStat &&
          subjectId == other.subjectId &&
          subjectName == other.subjectName &&
          held == other.held &&
          attended == other.attended &&
          gradesCount == other.gradesCount &&
          avgGrade == other.avgGrade;

  @override
  int get hashCode => _hashProps(<Object?>[
        subjectId,
        subjectName,
        held,
        attended,
        gradesCount,
        avgGrade,
      ]);
}

/// BITTA DARS qatori — o'quvchi shu darsda nima olganini ko'radi.
///
/// `grade` va `mastery` ATAYIN nullable: o'qituvchi har darsga baho qo'ymaydi.
/// `0` bilan almashtirilsa dars "nol baho olingan" bo'lib ko'rinardi.
/// `homeworkMark`: 0 = belgilanmagan, 1 = qildi, 2 = qilmadi, 3 = chala.
/// `behavior`: 0 = belgilanmagan, 1 = yaxshi, 2 = yomon.
/// `mastery` (o'zlashtirish): 0 = reaktiv emas … 3 = proaktiv.
class StudentLessonRow {
  final String date;
  /// Dars raqami — bir kunda bir necha dars bo'lsa farqlash uchun.
  final int period;
  final String groupId;
  final String groupName;
  final String subjectId;
  final String subjectName;
  final String topic;
  final String homeworkText;
  final bool conducted;
  final bool present;
  final int? grade;
  /// Sababli yo'qlik nomi (bo'lmasa null) — davomat izohi.
  final String? reasonName;
  final String? reasonShort;
  final bool isLate;
  final int homeworkMark;
  final int behavior;
  final int? mastery;

  StudentLessonRow({
    required this.date,
    required this.period,
    required this.groupId,
    required this.groupName,
    required this.subjectId,
    required this.subjectName,
    required this.topic,
    required this.homeworkText,
    required this.conducted,
    required this.present,
    required this.isLate,
    required this.homeworkMark,
    required this.behavior,
    this.grade,
    this.reasonName,
    this.reasonShort,
    this.mastery,
  });

  factory StudentLessonRow.fromJson(Map<String, dynamic> j) => StudentLessonRow(
        date: _s(j['date']),
        period: _i(j['period']),
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        topic: _s(j['topic']),
        homeworkText: _s(j['homeworkText']),
        conducted: _b(j['conducted']),
        present: _b(j['present']),
        isLate: _b(j['isLate']),
        homeworkMark: _i(j['homeworkMark']),
        behavior: _i(j['behavior']),
        grade: _in(j['grade']),
        reasonName: _sn(j['reasonName']),
        reasonShort: _sn(j['reasonShort']),
        mastery: _in(j['mastery']),
      );

  /// `StudentLessonRow.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'period': period,
        'groupId': groupId,
        'groupName': groupName,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'topic': topic,
        'homeworkText': homeworkText,
        'conducted': conducted,
        'present': present,
        'grade': grade,
        'reasonName': reasonName,
        'reasonShort': reasonShort,
        'isLate': isLate,
        'homeworkMark': homeworkMark,
        'behavior': behavior,
        'mastery': mastery,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentLessonRow &&
          date == other.date &&
          period == other.period &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          subjectId == other.subjectId &&
          subjectName == other.subjectName &&
          topic == other.topic &&
          homeworkText == other.homeworkText &&
          conducted == other.conducted &&
          present == other.present &&
          grade == other.grade &&
          reasonName == other.reasonName &&
          reasonShort == other.reasonShort &&
          isLate == other.isLate &&
          homeworkMark == other.homeworkMark &&
          behavior == other.behavior &&
          mastery == other.mastery;

  @override
  int get hashCode => _hashProps(<Object?>[
        date,
        period,
        groupId,
        groupName,
        subjectId,
        subjectName,
        topic,
        homeworkText,
        conducted,
        present,
        grade,
        reasonName,
        reasonShort,
        isLate,
        homeworkMark,
        behavior,
        mastery,
      ]);
}

/// Davr jurnalining TO'LIQ javobi (`GET /student/journal`).
///
/// `groupId` — so'rovda qo'llangan filtr (bo'sh satr = barcha guruhlar).
/// U javobda qaytadi, chunki ekran "hozir qaysi guruh tanlangan"ni serverdan
/// tasdiqlab oladi (server filtri o'z ixtiyori bilan boshqa guruhga tushishi mumkin).
class StudentPeriodJournal {
  final String from;
  final String to;
  final String groupId;
  final List<StudentPeriodGroup> groups;
  final StudentPeriodSummary summary;
  final List<StudentSubjectStat> subjects;
  final List<StudentLessonRow> lessons;

  StudentPeriodJournal({
    required this.from,
    required this.to,
    required this.groupId,
    required this.groups,
    required this.summary,
    required this.subjects,
    required this.lessons,
  });

  factory StudentPeriodJournal.fromJson(Map<String, dynamic> j) => StudentPeriodJournal(
        from: _s(j['from']),
        to: _s(j['to']),
        groupId: _s(j['groupId']),
        groups: _list(j['groups'], StudentPeriodGroup.fromJson),
        // `summary` umuman kelmasa ham ekran ochilsin — `_map` bo'sh map beradi.
        summary: StudentPeriodSummary.fromJson(_map(j['summary'])),
        subjects: _list(j['subjects'], StudentSubjectStat.fromJson),
        lessons: _list(j['lessons'], StudentLessonRow.fromJson),
      );

  /// `StudentPeriodJournal.fromJson(x.toJson())` — qiymatni saqlaydigan aylanma (offline kesh uchun).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'from': from,
        'to': to,
        'groupId': groupId,
        'groups': groups.map((e) => e.toJson()).toList(),
        'summary': summary.toJson(),
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'lessons': lessons.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentPeriodJournal &&
          from == other.from &&
          to == other.to &&
          groupId == other.groupId &&
          _deepEq(groups, other.groups) &&
          summary == other.summary &&
          _deepEq(subjects, other.subjects) &&
          _deepEq(lessons, other.lessons);

  @override
  int get hashCode => _hashProps(<Object?>[
        from,
        to,
        groupId,
        groups,
        summary,
        subjects,
        lessons,
      ]);
}
